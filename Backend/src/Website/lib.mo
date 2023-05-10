
import Principal "mo:base-ext/Principal";
import Http "mo:base-ext/Utils/Http";
import Path "mo:filepaths/Path";
import Text "mo:base-ext/Text";
import { toArray = i2a } "mo:base/Iter";
import Inodes "../Inodes";
import FS "../Filesystem";

shared ({caller = _installer}) actor class Website(admins: [Principal]) = this {

  type Path = Path.Path;
  type Error = Inodes.Error;
  type Mount = Inodes.Mount;
  type Locator = Inodes.Locator;
  type Return<T> = Inodes.Return<T>;

  type Fileshare = actor { export: shared (Locator) -> async Return<Mount> };

  type Configuration = [Parameter];

  type Parameter = {
    #admins: [Principal];
    #fileshare: Principal;
  };

  stable var _init: Bool = false;
  stable var _self: Principal = Principal.placeholder();
  stable var _fileshare = Principal.Base.toText( _installer );
  stable var _admins: Principal.Set = Principal.Set.init();
  stable var _filesystem: FS.Filesystem = FS.stage();

  public shared ({caller}) func init(mount: FS.Mount): async () {
    assert caller == _installer and not _init;
    _set_admins( admins );
    _initfs( mount );
    _init := true;
  };

  public shared ({caller}) func configure(config: Configuration): async () {
    assert _is_admin(caller);
    for ( param in config.vals() ){
      switch param {
        case ( #admins arr ) _set_admins( arr );
        case ( #fileshare id ) _fileshare := Principal.Base.toText( id );
      }
    }
  };

  public shared ({caller}) func pull_assets(locator: Locator): async Return<()> {
    assert _is_admin(caller);
    let share: Fileshare = actor( _fileshare );
    switch( await share.export( locator ) ){
      case ( #ok mount ) #ok( FS.mount(_filesystem, mount) );
      case ( #err val ) #err val;
    }
  };

  public shared query ({caller}) func http_request(request: Http.Request): async Http.Response {
    var elems : [Text] = i2a(Text.Base.split(request.url, #text("/?")));
    var path : Text = elems[0];
    if ( Path.is_root(path) ) path := "/index.html"; 
    if ( Path.is_absolute(path) == false ){ return Http.NOT_FOUND() };
    switch( FS.walk(_filesystem, #path(path), _self) ){
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

  func _set_admins( arr : [Principal] ) : () {
    _admins := Principal.Set.fromArray( arr );
  };
  func _is_admin( p : Principal ) : Bool {
    Principal.Set.match(_admins, p) and _init;
  };
  func _initfs(mount: FS.Mount) : () {
    _self := Principal.Base.fromActor(this);
    FS.init(_filesystem, _self, Principal.Set.toArray(_admins), ?(0,7,7,5));
    FS.mount(_filesystem, mount);
  };

}