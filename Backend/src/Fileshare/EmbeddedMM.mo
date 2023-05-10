import Principal "mo:base-ext/Principal";
import Option "mo:base/Option";
import SD "EmbeddedSD";
import HB "mo:scheduling/Tasks";
import T "Types";
import Cycles "mo:base/ExperimentalCycles";
import {trap;print} "mo:base/Debug";
import Nat "mo:base/Nat";
import BD "BlockDevice";
import Sbuffer "mo:stableBuffer/StableBuffer";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import {range} "mo:base/Iter";
import Time "mo:base-ext/Time";
import DQ "mo:base/Deque";
import S "mo:base/Stack";

module {

  type Index = Nat;
  type File = T.File;
  type Status = SD.Status;
  type SaveFn = T.SaveFn;
  type Return<X> = T.Return<X>;
  type Strategy = T.UploadStrategy;
  type Request = T.WriteRequest;
  type Daemon = SD.ServiceDaemon;
  type Device = T.StorageDevice;

  public type SharedManager = {
    devices  : DQ.Deque<Device>;
    managed  : [Principal];
  };

  public class MediaManager( max_sessions : Nat ) = {

    public var staged = false;
    
    let _supports = max_sessions;
    var _requests = Array.init<Status>(_supports, #Null);
    var _savecmd  = func ( input : [(Index,File)] ) : () {};
    var _managed  = Principal.Set.init();
    var _devices  = DQ.empty<Device>();
    var _daemons  = DQ.empty<Daemon>();
    public var _lastreserved = "";

    public func set_save_method( fn : SaveFn ) { _savecmd := fn };

    public func unshare( sm : SharedManager ) : () {
      _devices := sm.devices;
      _managed := Principal.Set.fromArray(sm.managed);
      if ( Principal.Set.size(_managed) >= 5 ) staged := true;
    };

    public func share() : SharedManager {{
      devices = _devices;
      managed = Principal.Set.toArray(_managed);
    }};

    public func stage() : async* () {
      var count : Nat = Principal.Set.size(_managed);
      if ( count < 5 ){
        _devices := DQ.pushBack<Device>(_devices, await* new_device());
        count += 1
      };
      if( count >= 5 ) staged := true;
    };

    public func managed() : [Principal] { Principal.Set.toArray(_managed) };

    public func is_managed( caller : Principal ) : Bool { Principal.Set.match(_managed, caller) };

    public func debug_messages(): [Text] {
      var cache = DQ.empty<Daemon>();
      let buffer = Buffer.Buffer<Text>(0);
      label process loop {
        let ?(dq, daemon) = DQ.popBack<Daemon>( _daemons ) else break process;
        _daemons := dq;
        cache := DQ.pushFront<Daemon>(cache, daemon);
        buffer.add(daemon._debug);
      };
      _daemons := cache;
      Buffer.toArray<Text>( buffer )
    };

    public func write_request( request : Request, secret : Blob ) : Return<Index> {
      for ( index in range(0, _supports-1) ){
        switch( _requests[index] ){
          case ( #Null ){
            _requests[index] := #Reserved;
            spawn_daemon(index, request, _savecmd, secret);
            return #ok( index )
          };
          case _ ()
        }
      };
      #err( #ServiceLimit )
    };

    public func request_instruction( caller : Principal, index : Index ) : Return<Strategy> {
      switch( _requests[index] ){
        case( #Finished(strategy,delegate) ){
          if ( caller != delegate ) #err( #Unauthorized )
          else {
            let ?strat = strategy() else { return #err(#TryAgain) };
            _requests[index] := #Null;
            #ok( strat );
          }
        };
        // case ( #Busy ) Debug.trap("busy");
        // case ( #Staged ) Debug.trap("staged");
        case ( #Ready ) #err( #Invalid("Ready"));
        case ( #Mapped ) #err( #Invalid("Mapped"));
        // case ( #Delete ) Debug.trap("deleted");
        case ( #Reserved ) #err( #Invalid("Reserved"));
        // case ( #Null ) Debug.trap("null");
        case(_) #err( #Busy )
      }
    };

    func count_daemons() : Nat {
      var count : Nat = 0;
      var cache = DQ.empty<Daemon>();
      label process loop {
        let ?(dq, daemon) = DQ.popBack<Daemon>( _daemons ) else break process;
        _daemons := dq;
        cache := DQ.pushFront<Daemon>(cache, daemon);
        count += 1;
      };
      _daemons := cache;
      count
    };

    public func count_devices() : Nat {
      var count : Nat = 0;
      var cache = DQ.empty<Device>();
      label process loop {
        let ?(dq, device) = DQ.popBack<Device>( _devices ) else break process;
        _devices := dq;
        cache := DQ.pushFront<Device>(cache, device);
        count += 1;
      };
      _devices := cache;
      count
    };

    public func clock() : async* () {
      let stack = S.Stack<Daemon>();
      label process loop {
        let ?(dq, daemon) = DQ.popBack<Daemon>( _daemons ) else break process;
        _daemons := dq;
        switch( daemon.state ){
          case ( #Ready ){
            await* daemon.map();
            _lastreserved := Time.Datetime.now();
            stack.push( daemon )
          };
          case( #Mapped ){
            await* daemon.format();
            stack.push(daemon)
          };
          case( #Delete ){};
          case _ stack.push(daemon);
        }
      };
      label reverse loop {
        let ?daemon = stack.pop() else break reverse;
        _daemons := DQ.pushBack<Daemon>(_daemons, daemon)
      }
    };

    func set_state( index : Index, state : Status ) : () {
      _requests[index] := state;
    };

    func release( device : Device ) : () {
      _devices := DQ.pushFront<Device>(_devices, device);
    };

    func reserve( size : T.BlockCount ) : async* Device {
      let stack = S.Stack<Device>();
      func reverse() : () {
        label r loop {
          let ?device = stack.pop() else break r;
          _devices := DQ.pushBack<Device>(_devices, device);
        }
      };
      label search loop {
        let ?(dq, device) = DQ.popBack<Device>( _devices ) else break search;
        _devices := dq;
        if ( device.available < size ) stack.push( device )
        else reverse(); return device;
      };
      reverse();
      await* new_device();
    };

    func new_device() : async* Device {
      assert Cycles.balance() >= 6000000000000;
      Cycles.add(5000000000000);
      let t_actor : BD.BlockDevice = await BD.BlockDevice([]);
      let t_principal : Principal = Principal.Base.fromActor(t_actor);
      let device : Device = {
        open = t_actor.open;
        close = t_actor.close;
        principal = t_principal;
        available = T.SectorCount.blocks(1);
      };
      _managed := Principal.Set.insert(_managed, t_principal);
      return device;
    };

    func spawn_daemon( index : Index, request : Request, save : SaveFn, secret : Blob ) : () {
      _daemons := DQ.pushFront(
        _daemons, SD.ServiceDaemon(
          index,
          request,
          save,
          set_state,
          reserve,
          release,
          secret,
        )
      );
    };

  };


};