import DQ "mo:base/Deque";
import Nat "mo:base-ext/Nat";
import { toNat } "mo:base/Nat32";
import {toText = id_to_text} "mo:base/Nat32";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import {Index; Handle; Bytecount} "Inode/mfsv0/common";
import Principal "mo:base-ext/Principal";
import { find = search; map; thaw; } "mo:base/Array";
import { trap; print } "mo:base/Debug";
import { isSome; get = getOpt; make = makeOpt } "mo:base/Option";
import Sbuffer "mo:stableBuffer/StableBuffer";
import Groups "Inode/mfsv0/access_control/v0/groups";
import Actors "Inode/mfsv0/access_control/v0/actors";
import Path "mo:filepaths/Path";
import Time "mo:base/Time";
import Inode "Inode";
import Inodes "Inodes";
import F "Inode/mfsv0/data/file";

module {

  public type Index = Inodes.Index;
  public type Handle = Handle.Handle;
  public type Bytecount = Bytecount.Bytecount;

  public type Path = Path.Path;
  public type Flag = Inodes.Flag;
  public type Modal = Inodes.Modal;

  public type UID = Actors.UID;
  public type Actor = Actors.Actor;
  public type Actors = Actors.Actors;

  public type GID = Groups.GID;
  public type Group = Groups.Group;
  public type Groups = Groups.Groups;

  public type Inode = Inodes.Inode;
  public type Inodes = Inodes.Inodes;
  public type Return<T> = Inodes.Return<T>;

  public type Mount = Inodes.Mount;
  public type SharedInode = Inodes.SharedInode;
  public type SharedObject = Inodes.SharedObject;

  public type Listing = [Object];
  public type Object = {#file: File; #directory: Directory};
  public type File = (Nat, Nat, Handle, Bytecount, Mimetype, Callback, Token);
  public type Directory = (Nat, Nat, Handle, Bytecount);
  public type Permission = Inode.Permission;
  public type Children = Inode.Children;
  public type Dentries = Inode.Dentries;
  public type Mimetype = Inode.Mimetype;
  public type Callback = Inode.Callback;
  public type Token = Inode.Token;

  public type Locator = {
    #index: Nat;
    #path: Path;
  };

  public type Status = {
    index: Nat;
    parent: Nat;
    owner: Principal;
    group: Handle;
    modal: Modal;
    size: Bytecount;
  };

  public type InputFile = {
    size : Bytecount;
    ftype : Mimetype;
    pointer : {
      callback : Callback;
      token    : Token;
    };
  };

  public type Filesystem = {
    var actors : Actors;
    var groups : Groups;
    var inodes : Inodes;
  };

  public let ROOT_GRP = "root";
  public let ROOT_UID: UID = Actors.SUID;
  public let ROOT_GID: GID = Groups.SGID;
  public let ANON_GRP = "anonymous";
  public let ANON_UID: UID = 1;
  public let ANON_GID: GID = 1;
  public let DEFAULT_MODE: Modal = (0,7,7,5);

  let {O_READ; O_WRITE; O_ERASE; O_SHOW; O_MAKE; O_SUDO} = Inodes;

  public func stage() : Filesystem {{
    var actors = Actors.init(?10);
    var groups = Groups.init();
    var inodes = Inodes.stage();
  }};

  public func init(fs: Filesystem, su: Principal, admins: [Principal], mode: ?Modal) : () {
    assert Actors.register(fs.actors, su) == ROOT_UID;
    assert Actors.register(fs.actors, Principal.placeholder()) == ANON_UID;
    assert Groups.register(fs.groups, #uid(ROOT_UID), ROOT_GRP) == ROOT_GID;
    assert Groups.register(fs.groups, #uid(ANON_UID), ANON_GRP) == ANON_GID;
    ignore Actors.add_groups(fs.actors, su, [ROOT_GID]);
    for ( admin in admins.vals() ){
      let (uid, gid) = register_actor(fs, admin);
      ignore Groups.addGroupMember(fs.groups, ROOT_UID, ROOT_GRP, uid);
      ignore Actors.add_groups(fs.actors, admin, [ROOT_GID]);
    };
    Inodes.init(fs.inodes, getOpt<Modal>(mode, DEFAULT_MODE));
  };

  public func stat(fs: Filesystem, actor_: Principal, locator: Locator): Return<Status> {
    switch( operation(fs, locator, actor_, [O_READ, O_SHOW, O_SUDO]) ){
      case ( #err val ) #err val;
      case ( #ok (inode,_,_,_) ){#ok({
        index = Inode.index( inode );
        parent = Inode.parent( inode );
        owner = Actors.lookup(fs.actors, Inode.owner(inode));
        group = Groups.lookup(fs.groups, Inode.group(inode));
        modal = Inode.mode( inode );
        size = Inode.size( inode );
      })}
    }
  };

  public func exists(fs: Filesystem, locator: Locator) : Bool {
    switch( Inodes.open(fs.inodes, locator, ROOT_UID, [ROOT_GID], [O_READ, O_SHOW]) )
    { case ( #ok _ ) true; case ( #err _ ) false }
  };

  public func find(fs: Filesystem, locator: Locator, keyword: Handle, actor_: Principal): Return<Object> {
    switch( operation(fs, locator, actor_, [O_READ]) ){
      case ( #err val ) #err val;
      case ( #ok (inode, name, eid, groups) ){
        if ( Inode.is_directory(inode) == false ) return #err(#NotDirectory name);
        let ?index = Inode.find(inode, keyword) else { return #err(#NotFound keyword) };
        #ok( inode_to_object(isolate<Inode>(fs.inodes.inodes[index]), keyword) )
      }
    }
  };

  public func walk(fs: Filesystem, locator: Locator, actor_: Principal): Return<Object> {
    switch( operation(fs, locator, actor_, [O_READ]) ){
      case ( #ok (inode,handle, _, _) ) #ok( inode_to_object(inode, handle) );
      case ( #err val ) #err val
    }
  };

  public func remove(fs: Filesystem, locator: Locator, actor_: Principal): Return<()> {
    switch( operation(fs, locator, actor_, [O_WRITE, O_ERASE]) ){
      case ( #err val ) #err val;
      case ( #ok (inode, handle, _, _) ){
        if ( Inode.is_file(inode) == false ) return #err(#NotFile "")
        else #ok( Inodes.erase(fs.inodes, handle, inode) )
      }
    }
  };

  public func remove_directory(fs: Filesystem, locator: Locator, actor_: Principal): Return<()> {
    switch( operation(fs, locator, actor_, [O_WRITE, O_ERASE]) ){
      case ( #err val ) #err val;
      case ( #ok (inode, handle, _, _) ){
        if ( Inode.is_directory(inode) == false ) return #err(#NotDirectory "")
        else if ( Inode.is_populated(inode) ) return #err(#NotEmpty)
        else #ok( Inodes.erase(fs.inodes, handle, inode) )
      }
    }
  };

  public func change_owner(fs: Filesystem, locator: Locator, actor_: Principal, new_owner: Principal): Return<()> {
    switch( operation(fs, locator, actor_, [O_WRITE]) ){
      case ( #err val ) #err val;
      case ( #ok (inode, _, eid, _) ){
        if ( Inode.owner(inode) != eid ) return #err(#Unauthorized);
        let (oid, _) = id_helper(fs, new_owner, [O_WRITE]);
        #ok( Inode.set_owner(inode, oid) );
      }
    }
  };

  public func change_mode(fs: Filesystem, locator: Locator, actor_: Principal, mode: Modal): Return<()> {
    switch( operation(fs, locator, actor_, [O_WRITE]) ){
      case ( #err val ) #err val;
      case ( #ok (inode, _, _, _) ){
        let m: Modal = Inode.mode( inode );
        #ok( Inode.set_mode(inode, (m.0, mode.1, mode.2, mode.3)) );
      }
    }
  };

  public func change_group(fs: Filesystem, locator: Locator, actor_: Principal, handle: Handle): Return<()> {
    switch( operation(fs, locator, actor_, [O_WRITE]) ){
      case ( #err val ) #err val;
      case ( #ok (inode, _, eid, groups) ){
        if ( Inode.owner(inode) != eid ) return #err(#Unauthorized);
        let ?gid = Groups.getGID(fs.groups, handle) else {return #err(#NotFound handle)};
        #ok( Inode.set_group(inode, gid) )
      }
    }
  };

  public func move(fs: Filesystem, target: Locator, destination: Locator, actor_: Principal): Return<()> {
    let #ok (child, cname, _, _) = operation(fs, target, actor_, [O_WRITE, O_ERASE]) else {return #err(#Unauthorized)};
    let #ok (parent, pname, _, _) = operation(fs, destination, actor_, [O_WRITE]) else {return #err(#Unauthorized) };
    if ( Inode.is_directory(parent) == false ) return #err(#NotDirectory("../"#pname));
    if ( isSome( Inode.find(parent, cname) ) ) return #err(#AlreadyExists("../" # pname # "/" # cname));
    Inodes.erase(fs.inodes, cname, child);
    Inode.set_parent(child, Inode.index(parent));
    Inodes.write(fs.inodes, cname, child);
  };

  public func rename(fs: Filesystem, target: Locator, handle: Handle, actor_: Principal): Return<()> {
    switch( operation(fs, target, actor_, [O_WRITE]) ){
      case ( #err val ) #err val;
      case ( #ok (child, cname, _, _) ){
        switch( operation(fs, #index(Inode.parent(child)), actor_, [O_WRITE]) ){
          case ( #err val ) #err val;
          case ( #ok (parent, _, _, _) ){
            if ( isSome(Inode.find(parent, handle)) ) return #err(#AlreadyExists(handle));
            Inode.delete(parent, cname);
            #ok( Inode.add_dentry(parent, handle, Inode.index(child)) )
          }
        }
      }
    }
  };

  public func list_directory(fs: Filesystem, actor_: Actor, locator: Locator): Return<Listing> {
    switch( operation(fs, locator, actor_, [O_READ]) ){
      case ( #err val ) #ok([]);
      case ( #ok (i, _, eid, groups) ){
        var inode = i;
        if ( Inode.permits(inode, eid, groups, #exec) == false ) return #ok([]);
        let listing = Buffer.Buffer<Object>(0);
        if ( Inode.is_file( inode ) ) return #err(#NotDirectory "");
        for ( (handle, index) in Inode.dentries( inode ) ){
          inode := isolate<Inode>(fs.inodes.inodes[index]);
          if ( Inode.permits(inode, eid, groups, #read) ) listing.add( inode_to_object(inode, handle) );
        };
        #ok( Buffer.toArray<Object>( listing ) )
      }
    }
  };

  public func touch(fs: Filesystem, parent: Locator, basename: Text, actor_: Actor) : Return<Nat> {
    switch( operation(fs, parent, actor_, [O_WRITE]) ){
      case( #err val ) #err val;
      case( #ok (inode, _, eid, groups) ){
        switch( Inode.find(inode, basename) ){
          case null Inodes.create_(fs.inodes, inode, basename, eid, groups[0], #file);
          case ( ?some ) #ok(some)
        }
      }
    }
  };

  public func write(fs: Filesystem, path: Path, actor_: Actor, file: InputFile): Return<()> {
    let flags: [Flag] = [O_WRITE];
    let (eid, grps) = id_helper(fs, actor_, flags);
    switch( Inodes.create(fs.inodes, path, eid, grps, flags) ){
      case ( #err val ) #err val;
      case ( #ok (inode,_) ){
        Inode.format(inode, #file);
        Inode.set_size(inode, file.size);
        Inode.set_mimetype(inode, file.ftype);
        Inode.set_callback(inode, file.pointer.callback);
        Inode.set_token(inode, file.pointer.token);
        Inodes.write(fs.inodes, Path.basename(path), inode);
      }
    }
  };

  public func save(fs: Filesystem, index: Nat, file: InputFile): Return<()> {
    let inode = isolate<Inode>(fs.inodes.inodes[index]);
    if ( Inode.is_file( inode ) == false ) return #err(#NotFile "");
    let ?handle = Inodes.get_handle(fs.inodes, Inode.parent(inode), Inode.index(inode))
    else trap("Filesystem.save(): Failed to locate child index in parent directory.")
    print("save_file: " # debug_show file.size);
    Inode.set_size(inode, file.size);
    Inode.set_mimetype(inode, file.ftype);
    Inode.set_callback(inode, file.pointer.callback);
    Inode.set_token(inode, file.pointer.token);
    Inodes.write(fs.inodes, handle, inode);
  };

  public func make_directories( fs : Filesystem, path : Path, actor_ : Principal) : Return<()> {
    let flags: [Flag] = [O_WRITE, O_MAKE];
    let (eid, grps) = id_helper(fs, actor_, flags);
    switch( Inodes.create(fs.inodes, path, eid, grps, flags) ){
      case ( #err val ) #err val;
      case ( #ok (inode,_) ){
        Inode.format(inode, #directory);
        Inodes.write(fs.inodes, Path.basename(path), inode)
      }
    }
  };

  public func make_directory(fs: Filesystem, parent: Locator, basename: Text, actor_: Principal) : Return<()> {
    switch( operation(fs, parent, actor_, [O_WRITE]) ){
      case( #err val ) #err val;
      case( #ok (inode, _, eid, groups) ){
        switch( Inode.find(inode, basename) ){
          case null #ok( ignore Inodes.create_(fs.inodes, inode, basename, eid, groups[0], #directory) );
          case ( ?some ) #err(#AlreadyExists basename);
        }
      }
    }
  };

  public func inspect_inode(fs: Filesystem, locator: Locator, actor_: Principal) : Return<{#directory;#file;#orphan}> {
    switch( operation(fs, locator, actor_, [O_SUDO]) ){
      case( #ok (inode, _, _, _) ) #ok(Inode.inspect( inode ));
      case( #err val ) #err val;
    }
  };

  public func inspect_children(fs: Filesystem, locator: Locator, actor_: Principal) : Return<[(Nat, Handle, Nat, {#directory;#file;#orphan})]> {
    switch( operation(fs, locator, actor_, [O_SUDO]) ){
      case( #err val ) #err val;
      case( #ok (i, _, _, _) ){
        var inode = i;
        let listing = Buffer.Buffer<(Nat, Handle, Nat, {#directory;#file;#orphan})>(0);
        if ( Inode.is_file( inode ) ) return #err(#NotDirectory "");
        for ( (handle, index) in Inode.dentries( inode ) ){
          inode := isolate<Inode>(fs.inodes.inodes[index]);
          let type_: Nat = if ( Inode.is_file(inode) ) 0 else 1;
          listing.add( (index, handle, type_, Inode.inspect(inode)) );
        };
        #ok( Buffer.toArray<(Nat, Handle, Nat, {#directory;#file;#orphan})>( listing ) )
      }
    }
  };

  public func format_directory(fs: Filesystem, locator: Locator, actor_: Principal) : Return<()> {
    switch( operation(fs, locator, actor_, [O_SUDO]) ){
      case( #err val ) #err val;
      case( #ok (inode, _, _, _) ){
        if ( Inode.is_directory( inode ) == false ) return #err(#Error("Not a directory"));
        #ok( Inode.format(inode, #directory) )
      }
    }
  };

  public func actors(fs: Filesystem): [Principal] { Actors.toArray(fs.actors) };

  public func uid_to_actor(fs: Filesystem, uid: UID): Principal { Actors.lookup(fs.actors, uid) };

  public func actor_to_uid(fs: Filesystem, actor_: Principal): ?UID {
    let ?(uid, _) = Actors.get_identifiers(fs.actors, actor_) else { return null }; ?uid
  };

  public func actor_groups(fs: Filesystem, actor_: Principal): [Handle] {
    let ?(_, grps) = Actors.get_identifiers(fs.actors, actor_) else { return [] };
    map<GID,Handle>(grps, func(x): Handle { Groups.lookup(fs.groups, x)} );
  };

  public func group_members(fs: Filesystem, handle: Handle): [Principal] {
    map<UID,Principal>(
      Groups.getGroupMembers(fs.groups, handle),
      func(x): Principal { Actors.lookup(fs.actors, x) } 
    );
  };

  public func add_group_member(fs: Filesystem, handle: Handle, actor_: Principal): Return<()> {
    let ?gid = Groups.getGID(fs.groups, handle) else { return #err(#NotFound(handle)) };
    switch( Actors.add_groups(fs.actors, actor_, [gid]) ){
      case ( #err ) #err (#Error("Failed to add actor group"));
      case ( #ok ) #ok();
    };
  };

  public func register_actor(fs: Filesystem, actor_: Principal): (UID, GID) {
    let uid = Actors.register(fs.actors, actor_);
    let gid = Groups.register(fs.groups, #uid(uid), "u"#id_to_text(uid));
    ignore Actors.add_groups(fs.actors, actor_, [gid]);
    (uid, gid)
  }; 


  public func export(fs: Filesystem, locator: Locator, actor_: Principal): Return<Mount> {
    switch( operation(fs, locator, actor_, [O_READ]) ){
      case ( #err val ) #err val;
      case ( #ok (inode, handle, eid, groups) ){
        if ( Inode.is_file(inode) ) return #err(#NotDirectory handle);
        if ( Inode.permits(inode, eid, groups, #exec) == false ) return #err(#Unauthorized);
        if ( Inode.permits(inode, eid, groups, #read) == false ) return #err(#Unauthorized);  
        func drilldown(fs: Filesystem, mnt: Buffer.Buffer<Inode>, parent: Inode, next: {var n: Nat}): Dentries {
          let processed = Buffer.Buffer<(Handle, Index)>(0);
          for ( (cname, cindex) in Inode.dentries(parent) ){
            let cinode = isolate<Inode>(fs.inodes.inodes[cindex]);
            let b1: Bool = Inode.permits(cinode, eid, groups, #read);
            let b2: Bool = if ( Inode.is_directory(cinode) ) Inode.permits(cinode, eid, groups, #exec) else true;
            if ( b1 and b2 ){
              mnt.add( Inode.clone( cinode ) );
              processed.add(cname, next.n);
              next.n += 1
            }
          };
          for ( (cname, cindex) in processed.vals() ){
            let cinode = mnt.get( cindex );
            if ( Inode.is_directory(cinode) ){
              let entries = drilldown(fs, mnt, cinode, next);
              Inode.format(cinode, #directory);
              for ( (k,v) in entries ) Inode.add_dentry(cinode, k, v);
            };
            Inode.set_index(cinode, cindex);
            Inode.set_parent(cinode, Inode.index(parent));
          };
          processed.vals()
        };
        let inodes = Buffer.Buffer<Inode>(0);
        let root = Inode.clone( inode );
        Inode.set_index(root, 0);
        Inode.set_parent(root, 0);
        inodes.add( root );
        let root_entries: Dentries = drilldown(fs, inodes, root, {var n=1});
        Inode.format(root, #directory);
        for ( (k,v) in root_entries ) Inode.add_dentry(root, k, v);
        #ok( Buffer.toArray<SharedInode>( Buffer.map<Inode,SharedInode>(inodes, Inode.share) ) )
      };
    }
  };

  // Not sure what to do with permissions in this case. The canister importing the mount will obviously have root
  // privilege and can modify everything during the import so I think it makes sense to leave the existing
  // actor and group identifiers to help canisters that may be using a common federation
  // public func export(fs: Filesystem, locator: Locator, actor_: Principal): Return<Mount> {
  //   switch( operation(fs, locator, actor_, [O_READ]) ){
  //     case ( #err val ) #err val;
  //     case ( #ok (i, handle, eid, groups) ){
  //       if ( Inode.is_file(i) ) return #err(#NotDirectory handle);
  //       if ( Inode.permits(i, eid, groups, #read) == false ) return #err(#Unauthorized);
  //       var inode = i;
  //       func drilldown(fs: Filesystem, children: Children, mnt: Buffer.Buffer<SharedInode>, parent: Nat): Nat {
  //         var next_index: Nat = parent + 1;
  //         for( child in children ){
  //           let inode = isolate<Inode>(fs.inodes.inodes[child]);
  //           if ( Inode.permits(inode, eid, groups, #read) ) mnt.add( Inode.share(inode, ?next_index, ?parent) );
  //           next_index := 
  //             if ( Inode.is_directory(inode) and Inode.permits(inode, eid, groups, #exec) )
  //               drilldown(fs, Inode.children(inode), mnt, next_index)
  //             else next_index + 1;
  //         };
  //         next_index
  //       };
  //       let mount = Buffer.Buffer<SharedInode>(0);
  //       mount.add( Inode.share(inode, ?0, ?0) );
  //       ignore drilldown(fs, Inode.children( inode ), mount, 0);
  //       #ok( Buffer.toArray<SharedInode>( mount ) )
  //     }
  //   }
  // };

  // public func export(fs: Filesystem, path: Path, actor_: Actor): Return<Mount> {
  //   let flags: [Flag] = [O_READ];
  //   let (eid, grps) = id_helper(fs, actor_, flags);
  //   var inode: Inode = 
  //     switch( Inodes.open(fs.inodes, #path(path), eid, grps, flags) ){
  //       case ( #err val ) return #err val;
  //       case ( #ok (inode,_) ) if ( Inode.is_file(inode) ) return #err(#NotDirectory path) else inode;
  //     };
  //   if ( Inode.permits(inode, eid, grps, #exec) == false ) return #err(#Unauthorized);
  //   func drilldown(fs: Filesystem, children: Children, mnt: Buffer.Buffer<SharedInode>, parent: Nat): Nat {
  //     var next_index: Nat = parent + 1;
  //     for( child in children ){
  //       let inode = isolate<Inode>(fs.inodes.inodes[child]);
  //       if ( Inode.permits(inode, eid, grps, #read) ) mnt.add( Inode.share(inode, ?next_index, ?parent) );
  //       next_index := 
  //         if ( Inode.is_directory(inode) and Inode.permits(inode, eid, grps, #exec) )
  //           drilldown(fs, Inode.children(inode), mnt, next_index)
  //         else next_index + 1;
  //     };
  //     next_index
  //   };
  //   let mount = Buffer.Buffer<SharedInode>(0);
  //   mount.add( Inode.share(inode, ?0, ?0) );
  //   ignore drilldown(fs, Inode.children( inode ), mount, 0);
  //   #ok( Buffer.toArray<SharedInode>( mount ) )
  // };

  public func mount(fs: Filesystem, mount: Mount): () {
    fs.inodes := Inodes.from_mount( mount )
  };

  public func is_file(fs: Filesystem, path: Path) : Bool {
    let flags: [Flag] = [O_READ, O_SHOW];
    switch( Inodes.open(fs.inodes, #path(path), ROOT_UID, [ROOT_GID], flags) ){
      case ( #ok (inode,_) ) Inode.is_file( inode );
      case ( #err val ) false;
    };
  };

  public func is_directory(fs: Filesystem, path: Path) : Bool {
    let flags: [Flag] = [O_READ, O_SHOW];
    switch( Inodes.open(fs.inodes, #path(path), ROOT_UID, [ROOT_GID], flags) ){
      case ( #ok (inode,_) ) Inode.is_directory( inode );
      case ( #err val ) false;
    };
  };

  func operation(fs: Filesystem, locator: Locator, actor_: Principal, flags: [Flag]): Return<(Inode,Handle,UID,[GID])> {
    let (eid, groups) = id_helper(fs, actor_, flags);
    switch( Inodes.open(fs.inodes, locator, eid, groups, flags) ){
      case ( #ok (inode, handle) ) #ok(inode, handle, eid, groups);
      case ( #err val ) #err val;
    }
  };

  func id_helper(fs: Filesystem, actor_: Principal, flags: [Flag]): (UID, [GID]) {
    switch( Actors.get_identifiers(fs.actors, actor_) ){
      case null (ANON_UID, [ANON_GID]);
      case ( ?entry ){
        if ( entry.1.size() > 0 ) entry 
        else trap("Actor: " # Principal.Base.toText(actor_) #"; no group assignment")
      }
    }
  };

  func inode_to_object(inode: Inode, handle: Handle): Object {
    if ( Inode.is_directory(inode) ) #directory(Inode.index(inode), Inode.parent(inode), handle, Inode.size(inode))
    else #file(
      Inode.index(inode),
      Inode.parent(inode),
      handle, Inode.size( inode ),
      Inode.mimetype( inode ),
      Inode.callback(inode),
      Inode.token(inode)
    )
  };

  func flagged(flags: [Flag], flag: Flag): Bool {
    isSome( search<Flag>(flags, func(x) = x == flag) )
  };

  func isolate<T>(input: ?T): T {
    let ?ret = input else { trap("") }; ret
  };

};