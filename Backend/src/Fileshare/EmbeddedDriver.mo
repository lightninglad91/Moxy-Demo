import TM "mo:base/TrieMap";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Option "mo:base/Option";
import {trap;print} "mo:base/Debug";
import Path "mo:filepaths/Path";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Index "mo:base-ext/Nat";
import Http "mo:base-ext/Utils/Http";
import Time "mo:base/Time";
import TrieSet "mo:base/TrieSet";
import Hash "mo:crypto/SHA/SHA224";
import Hex "mo:encoding/Hex";
import T "Types";

module {

  type Index = Nat;

  public class DeviceDriver(

    delegate     : Principal,
    secret       : Blob,

  ) = {

    var _processing = TrieSet.empty<Principal>();
    var _secret : [Nat8] = Blob.toArray(secret);

    var finished : Bool = false;
    let devices = TM.TrieMap<Principal,[T.StorageDevice]>(Principal.equal, Principal.hash);
    let final_files = TM.TrieMap<Index,T.File>(Nat.equal, Int.hash);
    let inode_to_file = TM.TrieMap<Index,[T.TempFile]>(Nat.equal, Int.hash);
    let device_to_inodes = TM.TrieMap<Principal,[(T.BlockCount,Index)]>(Principal.equal, Principal.hash);
    let distributed_inodes = TM.TrieMap<Index,([T.StorageDevice],T.BlockCount)>(Nat.equal, Int.hash);
    let strategies = TM.TrieMap<Text,[T.Instruction]>(Text.equal, Text.hash);
    var state_change : [(T.Transition) -> ()] = [];

    public func init( change_state : (T.Transition) -> () ) : () {
      state_change := [change_state];
    };

    public func format() : async* () {
      if ( not all_formatted() ) {
        for ( entry in device_to_inodes.entries() ){
          if ( not processing(entry.0) ){
            mark_processing(entry.0);
            await* process_direct(entry);
          };
        };
        for ( entry in distributed_inodes.entries() ){
          if ( not processing(entry.1.0[0].principal) ){
            mark_processing(entry.1.0[0].principal);
            await* process_distributed(entry);
          };
        };
      };
      state_change[0](#Finished);
    };

    public func export_files() : [(Index,T.File)] { Iter.toArray( final_files.entries() ) };

    public func get_strategy() : T.Strategy { Iter.toArray( strategies.entries() ) };

    public func register_file( inode : Index, file : T.TempFile ) : () {
      inode_to_file.put(inode,[file]);
    };

    public func all_formatted() : Bool {
      let test = TrieSet.fromArray<Index>(
        Iter.toArray<Index>(final_files.keys()), Int.hash, Nat.equal
      );
      for ( entry in inode_to_file.keys() ){
        if ( not TrieSet.mem<Index>(test, entry, Int.hash(entry), Nat.equal) ){
          return false;
        };
      };
      return true;
    };

    public func map_file(
      device : T.StorageDevice, inode : Index, size : T.BlockCount ) : T.StorageDevice {
        let temp : [(T.BlockCount,Index)] = Option.get(device_to_inodes.get(device.principal), []);
        let inode_buffer = Buffer.fromArray<(T.BlockCount,Index)>(temp);
        inode_buffer.add((size,inode));
        device_to_inodes.put(device.principal,Buffer.toArray(inode_buffer));
        devices.put(device.principal, [device]);
        let used_device : T.StorageDevice = {
          open = device.open;
          close = device.close;
          principal = device.principal;
          available = (device.available - size);
        };
        return used_device;
      };

    public func map_distributed_file(
      inode : Index, da : [T.StorageDevice], last_blocks : T.BlockCount ) : () {
        distributed_inodes.put(inode,(da,last_blocks));
      };

    func next_secret() : Text {
      _secret := Hash.sum( _secret );
      Hex.encode( _secret );
    };

    func process_direct( entry : (Principal,[(T.BlockCount,Index)]) ) : async* () {
      let device : T.StorageDevice = Option.get(devices.get(entry.0), [])[0];
      let num_inodes : Nat = entry.1.size();
      let task_buffer = Buffer.Buffer<(Index,Principal,T.BlockCount,Text)>(num_inodes);
      let instruction_buffer = Buffer.Buffer<T.Instruction>(num_inodes);
      for ( inode in Iter.fromArray( entry.1 ) ){
        let size : T.BlockCount = Option.get(inode_to_file.get(inode.1), [])[0].size;
        
        task_buffer.add((inode.1,delegate,size,next_secret()));
        print(Nat.toText(inode.1));
      };
      switch( await device.open( Buffer.toArray(task_buffer) )){
        case( #err(val) ){ assert false };
        case( #ok(response) ){
          print("Device Responded");
          for ( (inode,bd_index,token) in Iter.fromArray( response.tokens ) ){
            let tfile : T.TempFile = Option.get(inode_to_file.get(inode), [])[0];
            let instruction : T.Instruction = (tfile.name, bd_index, 1);
            instruction_buffer.add(instruction);
            print("temp_file: " # debug_show tfile.bytecount);
            let file : T.File = {
              name = Path.basename(tfile.name);
              size = tfile.bytecount;
              ftype = tfile.ftype;
              timestamp = Time.now();
              owner = tfile.owner;
              group = tfile.owners;
              mode = (#RW,#NO);
              pointer = {
                callback = response.callback;
                token    = token;
              };
            };
            final_files.put(inode,file);
          };
          let principal : Text = Principal.toText(device.principal);
          let strategy : [T.Instruction] = Buffer.toArray(instruction_buffer);
          strategies.put(principal, strategy);
        };
      };
    };

    func process_distributed( entry : (Index,([T.StorageDevice],T.BlockCount)) ) : async* () {
      let inode : Index = entry.0;
      let tfile : T.TempFile = Option.get(inode_to_file.get(inode), [])[0];
      let full_sector : T.BlockCount = T.BlockCount.from_bytes(T.SECTOR_SIZE);
      let total_devices : Nat = entry.1.0.size();
      let strategy_buffer = Buffer.Buffer<T.Strategy>(total_devices);
      let token_buffer = Buffer.Buffer<(Http.StreamingCallback,Http.StreamingToken)>(total_devices);
      var first_token : Http.StreamingToken = {start=(0,0); stop=(0,0); key="none"; nested=[]};
      let callback = Array.init<?Http.StreamingCallback>(1,null);
      var count : Nat = 1;
      for ( device in entry.1.0.vals() ){
        var write_blocks : T.BlockCount = full_sector;
        if ( count == total_devices ){ write_blocks := entry.1.1 };
        switch ( await device.open([(inode,delegate,write_blocks,next_secret())]) ){
          case( #err(val) ){ assert false };
          case( #ok(response) ){
            if ( count > 1 ){ token_buffer.add((response.callback,response.tokens[0].2)) };
            if ( count == 1 ){
              first_token := response.tokens[0].2;
              callback[0] := ?response.callback;
            };
            let bd_index : Index = response.tokens[0].1;
            let principal : Text = Principal.toText(device.principal);
            strategy_buffer.add([(principal, [(tfile.name, bd_index, count)])] );
            count += 1;
          };
        };
      };
      switch( callback[0] ){
        case( null ){ assert false };
        case( ?cb ){
          let file : T.File = {
            name = Path.basename(tfile.name);
            size = tfile.size;
            ftype = tfile.ftype;
            timestamp = Time.now();
            owner = tfile.owner;
            group = tfile.owners;
            mode = (#RW,#NO);
            pointer = {
              callback = cb;
              token = {
                start = first_token.start;
                stop = first_token.stop;
                key = first_token.key;
                nested = Buffer.toArray(token_buffer);
              };
            };
          };
          final_files.put(inode,file);
          for ( entry in Iter.fromArray(Buffer.toArray(strategy_buffer)) ){
            strategies.put(entry[0].0, entry[0].1);
          };
        };
      };
    };

    func processing( p : Principal ) : Bool {
      TrieSet.mem<Principal>(_processing, p, Principal.hash(p), Principal.equal);
    };

    func mark_processing( p : Principal ) : () {
      _processing := TrieSet.put<Principal>(_processing, p, Principal.hash(p), Principal.equal);
    };

  };

};