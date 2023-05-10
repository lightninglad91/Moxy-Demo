import Principal "mo:base-ext/Principal";
import SB "mo:stableBuffer/StableBuffer";
import HB "mo:scheduling/Tasks";
import Hex "mo:encoding/Hex";
import HTTP "mo:base-ext/Utils/Http";
import CRC "mo:base-ext/Utils/CRC32";
import Time "mo:base-ext/Time";
import Cycles "mo:base/ExperimentalCycles";
import {print; trap} "mo:base/Debug";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Nat32 "mo:base/Nat32";
import Char "mo:base/Char";
import Prim "mo:⛔";
import T "Types";

shared ({ caller = _installer }) actor class BlockDevice( admins : [Principal] ) = this {

  type HBService = HB.HeartbeatService;
  type MetaBuffer = SB.StableBuffer<T.Metadata>;
  type Datastore = (T.Metadata, [var Blob]);
  type DataBuffer = SB.StableBuffer<Datastore>;


  type CyclesReport = {
    balance : Nat;
    transfer : shared () -> async ();
  };

  stable var _INIT_   : Bool       = false;
  stable var _SECTOR_ : DataBuffer = SB.init<Datastore>();
  stable var _NEXT_INDEX_ : Nat    = 0;
  stable var _admins : Principal.Set = Principal.Set.fromArray(admins);
  stable var _lastreport : Text = "";

  public shared query func last_report() : async Text { _lastreport };

  public shared ({caller}) func open( request : T.FormatRequest ) : async T.Return<T.FormatResponse> {
    assert caller == Principal.Base.fromText("his6s-bqaaa-aaaal-acdya-cai");
    for ( file in request.vals() ){ print( "Formatting for inode : " # Nat.toText(file.0)) };
    let token_buffer = Buffer.Buffer<(T.Index,T.Index,HTTP.StreamingToken)>(request.size());
    for ( file in stage(request) ){
      print("Staged: " # Nat.toText(file.0));
      let token : HTTP.StreamingToken = {start=file.1.2.0; stop=file.1.2.1; key=file.2; nested=[]};
      token_buffer.add((file.0, file.1.0, token))
    };
    return #ok({
      callback = read;
      tokens = Buffer.toArray(token_buffer);
    } : T.FormatResponse);
  };

  // public shared ({caller}) func write( sindex : T.Index, bindex : T.Index, data : Blob, crc : Text ) : () {
  //   let current : Datastore = SB.get<Datastore>(_SECTOR_, sindex);
  //   assert current.0.open and current.0.owner == caller and current.0.range.1.1 >= bindex;
  //   let crc2 = Hex.encode(CRC.crc32(data.vals()));
  //   if ( Text.contains(crc2, #text( Text.map(crc, Prim.charToLower))) ){current.1[bindex] := data}
  //   else (print("Rejected: "#crc2));
  //   // if ( Text.equal(crc, Hex.encode(CRC.crc32(data.vals()))) ){current.1[bindex] := data}
  //   // else (print("Rejected"));
  // };

  public shared ({caller}) func write( sindex : T.Index, bindex : T.Index, data : Blob ) : async () {
    let current : Datastore = SB.get<Datastore>(_SECTOR_, sindex);
    if ( not current.0.open ) trap("file is closed for writing");
    if ( current.0.owner != caller ) trap("not authorized: " # debug_show caller);
    if ( current.0.range.1.1 < bindex ) trap("rejected"); 
    current.1[bindex] := data;
  };

  public shared ({caller}) func close( index : T.Index ) : async () {
    let current : Datastore = SB.get<Datastore>(_SECTOR_, index);
    assert current.0.open and caller == current.0.owner;
    print("Attempting to close: " # Nat.toText(index));
    let newdata : T.Metadata = {
      owner = current.0.owner;
      range = current.0.range;
      key = current.0.key;
      open = false;
    };
    SB.put<Datastore>(_SECTOR_, index, (newdata, current.1));
  };

  public shared ({caller}) func clock() : () {/*Reserved for file audit*/};

  public shared query ({caller}) func verify( index : T.Index ) : async [T.Index] {
    let current : Datastore = SB.get<Datastore>(_SECTOR_, index);
    let buffer = Buffer.Buffer<T.Index>(0);
    assert caller == current.0.owner;
    for ( i in Iter.range(0,(current.1.size() - 1)) ){
      if ( Blob.toArray(current.1[i]).size() == 0 ){ buffer.add(i) };
    };
    Buffer.toArray(buffer);
  };

  public query func read( stoken : HTTP.StreamingToken ) : async HTTP.StreamingResponse {
    let sindex : T.Index = stoken.start.0;
    let bindex : T.Index = stoken.start.1;
    let asset = SB.get<Datastore>(_SECTOR_, sindex);
    assert Text.equal(stoken.key, asset.0.key);
    assert bindex <= stoken.stop.1;
    if ( bindex < stoken.stop.1 ){
      return {
        body = asset.1[bindex];
        token = ?{start=(sindex,(bindex+1)); stop=(sindex,stoken.stop.1); key = stoken.key; nested=stoken.nested};
      };
    } else {
      return {
        body = asset.1[bindex];
        token = null;
      };
    };
  };

  // ======================================================================== //
  // Cycles Management Interface                                              //
  // ======================================================================== //
  //
  public shared ({caller}) func reclaim() : async () {
    assert is_admin(caller);
    let _self : Principal = Principal.Base.fromActor(this);
    let IC : T.IC = actor("aaaaa-aa");
    await IC.update_settings({
      canister_id = _self;
      settings = { controllers = Principal.Set.toArray(_admins) };
    });
  };
  public shared func acceptCycles() : async () {
    let available = Cycles.available();
    let accepted = Cycles.accept(available);
    assert (accepted == available);
  };
  public shared ({caller}) func request_report() : () {
    assert caller == _installer;
    let bal = Cycles.balance();
    let hbsvc : HBService = actor(Principal.Base.toText(_installer));
    hbsvc.report_balance({balance = bal; transfer = acceptCycles});
  };

  public shared ({caller}) func chain_report( cr : T.ChainReport ) : () {
    switch cr {
      case ( #report(report) ){};
      case ( #ping ){
        assert caller == _installer;
        let chsvc : T.ChildService = actor(Principal.Base.toText(_installer));
        _lastreport := Time.Datetime.now();
        chsvc.chain_report(
          #report({
            balance = Cycles.balance();
            transfer = acceptCycles;
          })
        )
      }
    }
  };

  //REMOVE LATER
  public shared ({caller}) func send_cycles( p : Text ) : async () {
    assert is_admin(caller);
    type Target = actor { acceptCycles : shared () -> async () };
    let target : Target = actor(p);
    let available : Nat = Cycles.balance();
    let amount : Nat = (available - 50000000000);
    Cycles.add(amount);
    await target.acceptCycles();
  };

  // ======================================================================== //
  // Private Methods                                                          //
  // ======================================================================== //
  //
  func is_admin( p : Principal ) : Bool {
    Principal.Set.match(_admins, p);
  };
  func stage( request : T.FormatRequest ) : Iter.Iter<(T.Index,T.Mapping,Text)> {
    let file_buffer = Buffer.Buffer<(T.Index,T.Mapping,Text)>(request.size());
    for ( entry in request.vals() ){
      let page_count : T.PageCount = T.PageCount.from_blocks(entry.2);
      let secret     : Text        = entry.3;
      let authority  : Principal   = entry.1;
      let inode      : T.Index     = entry.0;
      let index      : T.Index     = next_index();
      let range      : T.Range     = ((index,0),(index,(page_count - 1)));
      let mapping    : T.Mapping   = (index, authority, range);
      file_buffer.add((inode,mapping,secret));
      let metadata : T.Metadata = {
        owner = authority;
        key = secret;
        range = range;
        open  = true;
      };
      SB.add<Datastore>(_SECTOR_, (metadata, Array.init<Blob>(page_count, Blob.fromArray([]))));
      print("Adding metadata for: " #Nat.toText(inode));
    };
    print("Metadata count: " # Nat.toText(SB.size(_SECTOR_)));
    file_buffer.vals();
  };

  func next_index() : T.Index {
    let ret : Nat = _NEXT_INDEX_;
    _NEXT_INDEX_ += 1;
    ret;
  };

};