import T "Types";
import MM "EmbeddedMM";
import DQ "mo:base/Deque";
import Error "mo:base/Error";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import { get = optGet } "mo:base/Option";
import {trap;print} "mo:base/Debug";
import Filesystem "../Filesystem";
import Blob "mo:base/Blob";
import Int "mo:base/Int";
import Time "mo:base-ext/Time";
import Http "mo:base-ext/Utils/Http";
import Path "mo:filepaths/Path";
import HB "mo:scheduling/Tasks";
import Text "mo:base-ext/Text";
import Random "mo:base-ext/Random";
import Index "mo:base-ext/Nat";
import SBuffer "mo:stableBuffer/StableBuffer";
import Principal "mo:base-ext/Principal";
import Cycles "mo:base/ExperimentalCycles";
import Data "../Inode/mfsv0/data";
import Inode "../Inode";
import { Website } "../Website";

shared ({caller = _installer}) actor class Fileshare() = this {

  // Type Declarations
  type Data = Data.Data;
  type Device = T.StorageDevice;
  type Filedata = T.Filedata;
  type Manifest = T.Manifest;
  type WriteRequest = T.WriteRequest;
  type UploadRequest = T.UploadRequest;
  type ChainReport = T.ChainReport;
  type ChildService = T.ChildService;
  type Index = Nat;
  type Locator = Filesystem.Locator;
  type HeartbeatService = HB.HeartbeatService;
  type Filesystem = Filesystem.Filesystem;
  type CyclesReport = HB.CyclesReport;
  type Return<T> = Filesystem.Return<T>;
  type Status = Filesystem.Status;
  type Path = Path.Path;
  type Permission = T.Priv;
  type Mode = T.Mode;
  type Dentry = T.Dentry; 
  type DState = T.DState;
  type Mount = Filesystem.Mount;
  type Object = Filesystem.Object;
  type Directory = T.Directory;
  type File = T.File;
  type DACL = T.DACL;


  // Persistent Data
  stable var _active     : Nat             = 0;
  stable var _init       : Bool            = false;
  stable var _self       : Principal       = Principal.placeholder();
  stable var _hbsvc      : Principal       = Principal.placeholder();
  stable var _lastbeat   : Text            = "";
  stable var _admins     : Principal.Set   = Principal.Set.init();
  stable var _filesystem : Filesystem      = Filesystem.stage();
  stable var _lastwrite  : Text            = "";

  let _manager = MM.MediaManager( 10 );
  stable var _managed_backup : [Principal] = [];
  stable var _devices_backup : DQ.Deque<Device> = DQ.empty<Device>();

  // _filesystem := Filesystem.stage();
  // Filesystem.init(_filesystem, _self, Principal.Set.toArray(_admins), ?(0,7,7,5));

  /// State Management
  system func postupgrade() {
    _manager.unshare({
      managed = _managed_backup;
      devices = _devices_backup
    });
    _manager.set_save_method( save );
    _managed_backup := [];
    _devices_backup := DQ.empty<Device>();
  };
  system func preupgrade() {
    let sharedMM = _manager.share();
    _managed_backup := sharedMM.managed;
    _devices_backup := sharedMM.devices;
  };

  public shared query func lastbeat() : async Text { _lastbeat };
  public shared query func lastreserved() : async Text { _manager._lastreserved };
  public shared query func count_devices() : async Nat { _manager.count_devices() };

  public shared query ({caller}) func stat(locator: Locator): async Return<Status> {
    Filesystem.stat(_filesystem, caller, locator);
  };

  /*============================================================================||
  || Public Interface                                                           ||
  ||============================================================================*/
  public shared query ({caller}) func last_write() : async Text { _lastwrite };

  public shared query ({caller}) func admins(): async [Principal] { Principal.Set.toArray(_admins) };

  public shared query ({caller}) func registered(): async [Principal] { Filesystem.actors(_filesystem) };

  public shared query ({caller}) func walk(locator: Locator) : async Return<Object> {
    Filesystem.walk(_filesystem, locator, caller);
  };

  public shared query ({caller}) func list_directory(locator: Locator): async Return<Filesystem.Listing> {
    Filesystem.list_directory(_filesystem, caller, locator);
  };

  public shared query ({caller}) func groups(p: Principal): async [Text] {
    Filesystem.actor_groups(_filesystem, p);
  };

  public shared query ({caller}) func export(locator: Locator) : async Return<Mount> {
    Filesystem.export(_filesystem, locator, caller);
  };

  public shared ({caller}) func touch(parent: Locator, basename: Text): async Return<Nat> {
    Filesystem.touch(_filesystem, parent, basename, caller)
  };

  public shared ({caller}) func remove(locator: Locator): async Return<()> {
    Filesystem.remove(_filesystem, locator, caller);
  };

  public shared ({caller}) func remove_directory(locator: Locator): async Return<()> {
    Filesystem.remove_directory(_filesystem, locator, caller);
  };

  public shared ({caller}) func make_directory(parent: Locator, basename: Text) : async Return<()> {
    Filesystem.make_directory(_filesystem, parent, basename, caller);
  };

  public shared ({caller}) func make_directories(p: Path): async Return<()> {
    Filesystem.make_directories(_filesystem, p, caller);
  };
  
  public shared ({caller}) func change_owner(locator: Locator, o: Principal): async Return<()> {
    Filesystem.change_owner(_filesystem, locator, caller, o)
  };

  public shared ({caller}) func change_mode(locator: Locator, m: (Nat8, Nat8, Nat8)): async Return<()> {
    assert m.0 <= 7 and m.1 <= 7 and m.2 <= 7;
    Filesystem.change_mode(_filesystem, locator, caller, (0, m.0, m.1, m.2))
  };

  public shared ({caller}) func rename(locator: Locator, name: Text): async Return<()> {
    Filesystem.rename(_filesystem, locator, name, caller);
  };

  public shared ({caller}) func move(child: Locator, new_parent: Locator): async Return<()> {
    Filesystem.move(_filesystem, child, new_parent, caller)
  };

  public shared ({caller}) func change_group(locator: Locator, g: Text): async Return<()> {
    Filesystem.change_group(_filesystem, locator, caller, g)
  };

  public shared ({caller}) func request_instruction(index: Index): async Return<T.UploadStrategy> {
    _manager.request_instruction(caller, index);
  }; 

  public shared ({caller}) func init( hbsvc : Principal, admins : [Principal] ) : async Return<()> {
    assert caller == _installer and not _init;
    _manager.set_save_method( save );
    await* _schedule( hbsvc );
    _set_admins( admins );
    _initfs();
    #ok();
  };

  public shared query ({caller}) func dependants() : async [Principal] {
    assert _is_admin(caller);
    _manager.managed();
  };

  public shared ({caller}) func reclaim_block_devices(): async () {
    assert _is_admin(caller);
    for ( device in _manager.managed().vals() ) await* set_controller(device, [_self, caller]);
  };

  public shared ({caller}) func register_actor(actor_: Principal): async Return<(Nat32,Nat32)> {
    if ( _is_admin(caller) == false ) return #err(#Unauthorized);
    #ok( Filesystem.register_actor(_filesystem, actor_) );
  };

  public shared ({caller}) func add_group_member(handle: Text, actor_: Principal): async Return<()> {
    if ( _is_admin(caller) == false ) return #err(#Unauthorized);
    Filesystem.add_group_member(_filesystem, handle, actor_);
  };

  public shared ({caller}) func register_actors(actors: [Principal]): async Return<[(Principal,(Nat32,Nat32))]> {
    if ( _is_admin(caller) == false ) return #err(#Unauthorized);
    #ok( Array.map<Principal,(Principal,(Nat32,Nat32))>(
      actors, func(x) { (x, Filesystem.register_actor(_filesystem, x)) })
    )
  }; 

  // This method is used to create a new folder at the root directory
  public shared ({caller}) func make_rootdir(p: Path) : async Return<()> {
    let (elements, depth) = Path.elements(p);
    if ( depth != 1 ) trap("Make root directory only accepts a single path element");
    Filesystem.make_directory(_filesystem, #path("/"), elements[0], caller);
  };

  public type Deployment = { #website: [Principal] };

  public shared ({caller}) func deploy(locator: Locator, deployment: Deployment): async Return<Text> {
    switch deployment {
      case ( #website admins ){
        let #ok obj = Filesystem.find(_filesystem, locator, "index.html", caller) else {
          return #err(#Error("Can't locate an Index HTML in the target directory"))
        };
        switch( await* deploy_website(locator, admins, caller) ){
          case ( #err val ) #err val;
          case ( #ok prin ) #ok( Principal.Base.toText( prin ) )
        }
      }
    }
  };

  func deploy_website(locator: Locator, admins: [Principal], owner: Principal): async* Return<Principal> {
    switch( Filesystem.export(_filesystem, locator, owner) ){
      case ( #err val ) #err val;
      case ( #ok mount ){
        if ( load_cycles(2000000000000) == false ) return #err(#Error("Insufficient Cycles"));
        let website = await Website( admins );
        await website.init( mount );
        #ok( Principal.Base.fromActor( website ) );
      }
    }
  };

  
  // Primary service interface; used by a FE application to initiate an upload request
  public shared ({caller}) func upload(request: UploadRequest): async Return<(Text,Index)> {
    let mbuffer = Buffer.Buffer<(Index,Filedata)>(request.manifest.size());

    for ( fdata in request.manifest.vals() ){
      print(debug_show fdata.size);
      let p : Path = Path.join(request.path, fdata.name);
      // trap( "path: " # p # "\ndirectory: " # Path.dirname(p) # "\nbasename: " # Path.basename(p) );
      if ( Text.Base.contains(fdata.name, #text("/")) and not Filesystem.exists(_filesystem, #path(Path.dirname(p)))){
        print("making new directories " # Path.dirname(p));
        switch( Filesystem.make_directories(_filesystem, Path.dirname(p), caller) ){
          case ( #err(val) ) trap(debug_show val);
          case ( #ok() ){
            // let dir : Path = Path.basename(Path.dirname(p));
            let file_data = {
              size = fdata.size;
              ftype = fdata.ftype;
              name = Path.basename(p);
            };
            print("creating file entry");
            switch( Filesystem.touch(_filesystem, #path(Path.dirname(p)), file_data.name, caller) ){
              case ( #ok index ) mbuffer.add((index,file_data));
              case ( #err val ) assert false
            }
          }
        }
      } else {
        print("creating file entry");
        switch( Filesystem.walk(_filesystem, #path(p), caller) ){
          case ( #ok obj ){
            let #file file = obj else { trap("Cannot write file to directory") };
            let file_data = {
              size = fdata.size;
              ftype = fdata.ftype;
              name = Path.basename(p);
            };
            mbuffer.add((file.0, fdata));
          };
          case ( #err _ ){
            switch( Filesystem.touch(_filesystem, #path(Path.dirname(p)), Path.basename(p), caller) ){
              case ( #ok(index) ) mbuffer.add((index,fdata));
              case ( #err(val) ) trap(debug_show val);
            };
          }
        };
      };
    };

    let wr : WriteRequest = {
      delegate = optGet<Principal>(request.delegate, caller);
      owners = request.group;
      manifest = Buffer.toArray(mbuffer);
    };

    print("submitting write request");
    switch( _manager.write_request(wr, await Random.blob()) ){
      case ( #ok(rindex) ) #ok((Principal.Base.toText(_self), rindex));
      case ( #err(val) ) #err val;
    };
    
  };

  /*============================================================================||
  || Callback Methods                                                           ||
  ||============================================================================*/
  //
  // Used to receive and accept cycles
  public shared func acceptCycles() : async () {
    let available = Cycles.available();
    let accepted = Cycles.accept(available);
    assert (accepted == available);
  };

  public shared ({caller}) func set_admins(arr: [Principal]): async () {
    assert _is_admin(caller) or caller == _installer;
    _set_admins(arr);
  };

  // Used to report balance to cycles management service
  public shared ({caller}) func report_balance() : () {
    assert _is_heartbeat_service( caller );
    _lastbeat := Time.Datetime.now();
    for ( dep in Iter.fromArray(_manager.managed()) ){
      let chsvc : ChildService = actor(Principal.Base.toText(dep));
      chsvc.chain_report(#ping);
    };
    let hbsvc : HeartbeatService = actor(Principal.Base.toText(_hbsvc));
    hbsvc.report_balance({
      balance = Cycles.balance();
      transfer = acceptCycles;
    });
  };

  // Called by dependants reporting their cycles balance
  public shared ({caller}) func chain_report( cr : ChainReport ) : () {
    switch cr {
      case ( #ping ){};
      case ( #report(report) ){
        assert _manager.is_managed(caller);
        let min_cycles : Nat = 5000000000000;
        let max_cycles : Nat = 6000000000000;
        if ( report.balance < min_cycles ){
          let topup : Nat =  max_cycles - report.balance;
          if ( Cycles.balance() > (topup + min_cycles) ){
            Cycles.add(topup);
            await report.transfer();
          }
        }
      }
    }
  };

  func load_cycles(n: Nat): Bool {
    if ( Cycles.balance() > n + 5000000000000 ){ Cycles.add( n ); true }
    else false
  };

  // If there's an open request (not saved) clock the media manager
  public shared ({caller}) func pulse() : () {
    assert _is_heartbeat_service( caller );
    if ( not _manager.staged ) await* _manager.stage();
    await* _manager.clock();
  };

  public query func http_request( request : Http.Request ) : async Http.Response {
    var elems : [Text] = Iter.toArray(Text.Base.split(request.url, #text("/?")));
    var path : Text = elems[0];
    if ( Path.is_root(path) ) path := "/index.html";
    if ( Path.is_absolute(path) == false ){ return Http.NOT_FOUND() };
    switch( Filesystem.walk(_filesystem, #path(path), _self) ){
      case ( #err _ ) Http.BAD_REQUEST();
      case( #ok inode ){
        switch( inode ){
          case ( #directory _ ) Http.NOT_FOUND();
          case ( #file file ) Http.generic(file.4, "",
            ?#Callback({callback = file.5; token = file.6}));
        };
      };
    }
  };

  /*============================================================================||
  || Private functions over state and modes of operation                        ||
  ||============================================================================*/
  //
  func _set_admins( arr : [Principal] ) : () {
    _admins := Principal.Set.fromArray( arr );
  };
  func _is_admin( p : Principal ) : Bool {
    Principal.Set.match(_admins, p) and _init;
  };
  func _is_heartbeat_service( p : Principal ) : Bool {
    _hbsvc == p and _init;
  };
  func _initfs() : () {
    _self := Principal.Base.fromActor(this);
    print("Initializing fileshare canister");
    Filesystem.init(_filesystem, _self, Principal.Set.toArray(_admins), ?(0,7,7,5));
    _init := true;
  };
  func _schedule( p : Principal ) : async* () { // For Moc-7.4.0: make async*
    _hbsvc := p;
    let hbsvc : HB.HeartbeatService = actor(Principal.Base.toText(_hbsvc));
    await hbsvc.schedule([
      {interval = HB.Intervals._05beats; tasks = [pulse]},
      {interval = HB.Intervals._15beats; tasks = [report_balance]},
    ]);
  };
  // This method is called by a media manager after it has successfully processed a write request
  func save( files : [(Index,File)] ) : () {
    for ( file in files.vals() ){
      switch( Filesystem.save(_filesystem, file.0, file.1) ){
        case ( #err _ ) _lastwrite := "Save Error";
        case ( #ok _ ) _lastwrite := Time.Datetime.now();
      }
    }
  };

  func set_controller(target: Principal, controllers: [Principal]): async* () {
    let IC : T.IC = actor("aaaaa-aa");
    await IC.update_settings({
      canister_id = target;
      settings = { controllers = controllers };
    });
  }; 

};