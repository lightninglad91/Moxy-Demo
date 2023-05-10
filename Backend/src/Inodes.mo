import Inode "Inode";
import Http "mo:base-ext/Utils/Http";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import DQ "mo:base/Deque";
import {trap; print} "mo:base/Debug";
import Path "mo:filepaths/Path";
import { range } "mo:base/Iter";
import { find; freeze; thaw; map; init = init_array } "mo:base/Array";
import { isSome; isNull } "mo:base/Option";


module {

  public type Index = Nat;
  type ACL = Inode.Access;
  type UID = Inode.UID;
  type GID = Inode.GID;
  type Path = Path.Path;
  type Data = Inode.Data;
  type Mode = Inode.Mode;
  type Handle = Inode.Handle;
  type Object = Inode.Object;
  type Bytecount = Inode.Bytecount;
  type Elements = Path.Elements;

  type Callback = Http.StreamingCallback;
  type Token = Http.StreamingToken;

  public type Mount = [SharedInode];
  public type SharedInode = (Nat,Nat,Nat,Nat,Nat,Nat,SharedObject);
  public type SharedObject = {#directory: [(Handle,Nat)]; #file: (Text,(Callback,Token))};

  public type Locator = {
    #path: Path;
    #index: Nat;
  };

  public type Inode = Inode.Inode;
  public type Modal = Inode.Modal;
  public type Flag = Nat;

  public type Return<T> = {#ok:T; #err:Error};

  public type Error = {
    #Error: Text;
    #NotEmpty;
    #FatalFault;
    #FailedInit : Text;
    #NotPermitted;
    #NotFound : Path;
    #Corrupted;
    #EmptyPath : Path;
    #AlreadyExists : Path;
    #NotFile : Path;
    #NotDirectory : Path;
    #Unauthorized;
    #IncompatibleInode;
    #Invalid : Path;
    #ServiceLimit;
    #TryAgain;
    #Busy;
  };

  public type Inodes = {
    var size: Nat;
    var count: Nat;
    var inodes: [var ?Inode];
    var orphaned: DQ.Deque<Index>;
  };

  public let ROOT_INODE: Index = 0;
  public let DEFAULT_SIZE: Nat = 10000;
  public let { ROOT_UID; ROOT_GID } = Inode;
  public let (O_READ, O_WRITE, O_ERASE, O_MAKE, O_SHOW, O_SUDO) = (0:Flag, 1:Flag, 2:Flag, 3:Flag, 4:Flag, 5: Flag);

  public func stage(): Inodes {{
    var count: Nat = 0;
    var size: Nat = DEFAULT_SIZE;
    var inodes = init_array(DEFAULT_SIZE, null);
    var orphaned = DQ.empty<Index>();
  }};

  public func init(inodes: Inodes, m: Modal): () {
    switch ( inodes.inodes[ROOT_INODE] ){
      case ( ?some ) trap("Inode array has already been initialized");
      case null {
        assert inodes.count + inodes.size + inodes.inodes.size() == 2 * DEFAULT_SIZE;
        assert isNull( DQ.peekFront<Index>(inodes.orphaned) );
        let inode: Inode = spawn(ROOT_INODE, ROOT_INODE, ROOT_UID, ROOT_GID, m);
        Inode.format(inode, #directory);
        inodes.inodes[ROOT_INODE] := ?inode;
        inodes.count += 1
      }
    }
  };

  public func from_mount(mount: Mount): Inodes {
    return {
      var size = mount.size();
      var count = mount.size();
      var orphaned = DQ.empty<Index>();
      var inodes = thaw<?Inode>(
        map<SharedInode,?Inode>(
          mount, func(x): ?Inode { ?Inode.unshare(x) }
        )
      )
    };
  }; 

  /*
    TODO: I think we should add the parent inode as an additional input to this method. Reason being
    that by this point the filesystem lib or file management service will have already had to isolate
    the parent inode to make sure the actor has permission to make a change. No need to repeat work.
  */
  public func write(inodes: Inodes, handle: Handle, inode: Inode): Return<()> {
    if ( Inode.is_orphaned( inode ) ) return #err( #IncompatibleInode );
    var parent: Inode = isolate(inodes, Inode.parent(inode));
    Inode.add_dentry(parent, handle, Inode.index(inode));
    roll_size_update(inodes, Inode.index(parent));
    #ok( inodes.inodes[Inode.index(inode)] := ?inode );
  };

  /*
    TEMPORARY METHOD: See notes above create()
  */
  public func create_(inodes: Inodes, parent: Inode, basename: Text, eid: UID, gid: GID, obj: Object): Return<Nat> {
    if ( Inode.is_directory(parent) == false ) return #err(#NotDirectory "");
    let modal: Modal = switch obj {case (#directory) (0,7,5,5); case (#file) (0,6,4,4)};
    let new: Inode = allocate(inodes, Inode.index(parent), basename, eid, gid, modal); Inode.format(new, obj);
    let #ok = write(inodes, basename, new) else { return #err(#IncompatibleInode) };
    #ok( Inode.index(new) )
  };


  /*
    TODO: After working with this a bit I think a cleaner approach would be to remove create() all together and just
    make allocate() a public method. We're putting too much burden on the Inodes lib when the filesystem or file management
    service has all the capability it needs to manage the formatting of new inodes. (LL)
  */
  public func create(inodes: Inodes, path: Path, eid: UID, groups: [GID], flags: [Flag]): Return<(Inode, Handle)> {

    switch( open(inodes, #path(Path.dirname(path)), eid, groups, flags) ){

      case ( #ok (inode, _) ){
        if ( Inode.is_directory(inode) == false ) return #err( #NotDirectory( Path.dirname(path) ));
        if ( isSome(Inode.find(inode, Path.basename(path))) ){
          if ( flagged(flags, O_ERASE) == false ) return #err( #AlreadyExists(path));
          return open(inodes, #path(path), eid, groups, flags)
        };
        let child: Inode = allocate(inodes, Inode.index(inode), Path.basename(path), eid, groups[0], (0,7,5,0));
        #ok(child, Path.basename(path));
      };

      case ( #err e ){
        let #NotFound p = e else { return #err e };
        let elements = Path.elements(path).0;
        if ( not flagged(flags, O_MAKE) ) return #err e;
        let next: Nat = Path.depth(p) - 1;
        let last: Nat = elements.size() - 2;
        var parent =
          switch( open(inodes, #path(Path.dirname(p)), eid, groups, flags) ){
            case ( #err val ) return #err val; case ( #ok (inode, _) ) inode;
          }; 
        for ( i in range(next, last) ){
          let child_inode = allocate(inodes, Inode.index(parent), elements[i], eid, groups[0], Inode.mode(parent));
          Inode.format(child_inode, #directory);
          ignore write(inodes, elements[i], child_inode);
          parent := child_inode;
        };
        let child: Inode = allocate(inodes, Inode.index(parent), base_elem(elements), eid, groups[0], Inode.mode(parent));
        #ok(child, base_elem(elements))
      }

    }

  };

  public func open(inodes: Inodes, locator: Locator, eid: UID, groups: [GID], flags: [Flag]): Return<(Inode, Handle)> {
    switch locator {
      case ( #path path ){
        let elements: Path.Elements = Path.elements(path).0;
        var depth: Nat = 0;
        var inode: Inode = isolate(inodes, ROOT_INODE);
        for ( elem in elements.vals() ){
          if ( Inode.is_directory(inode) == false ) return #err( #NotDirectory( Path.fromElements(elements, depth) ) );
          if ( Inode.is_hidden(inode) and not flagged(flags, O_SHOW) ) return #err( #Invalid( Path.fromElements(elements, depth) ) );
          if ( Inode.permits(inode, eid, groups, #exec) == false ) return #err(#Error("No exec perms. EID: " # debug_show eid # "; GRPS: " # debug_show groups));
          let ?index = Inode.find(inode, elem) else { return #err(#NotFound( Path.fromElements(elements, depth) ) ) };
          inode := isolate(inodes, index);
          depth += 1;
        };
        if ( has_permission(inodes, inode, eid, groups, flags) ) #ok(inode, Path.basename(path))
        else #err(#Error("Not authorized. EID: " # debug_show eid # "; GRPS: " # debug_show groups));
      };
      case ( #index index ){
        let inode: Inode = isolate(inodes, index);
        if ( Inode.is_orphaned(inode) ) return #err(#Invalid "");
        let pindex: Index = Inode.parent(inode);
        if ( 
          ancestry_permits(inodes, pindex, eid, groups) and 
          has_permission(inodes, inode, eid, groups, flags)
        ){
          let ?handle = get_handle(inodes, pindex, index) else { trap("") };
          #ok(inode, handle)
        } else #err(#Error("Not authorized. EID: " # debug_show eid # "; GRPS: " # debug_show groups));
      }
    };
  };

  public func erase(inodes: Inodes, handle: Handle, inode: Inode): () {
    let index: Index = Inode.index(inode);
    let pindex: Index = Inode.parent(inode);
    Inode.delete(isolate(inodes, pindex), handle);
    roll_size_update(inodes, pindex);
    inodes.inodes[index] := ?Inode.orphan(0);
    inodes.orphaned := DQ.pushBack<Index>(inodes.orphaned, index);
  };

  public func get_handle(inodes: Inodes, parent: Index, child: Index): ?Handle {
    if (child == 0) return ?"/";
    let p_inode = isolate(inodes, parent);
    for ( (name, idx) in Inode.dentries(p_inode) ) if ( idx == child ) return ?name;
    null
  };

  public func ancestry_permits(inodes: Inodes, parent: Index, eid: UID, grps: [GID]): Bool {
    let inode = isolate(inodes, parent);
    if ( Inode.permits(inode, eid, grps, #exec) == false ) return false;
    if ( parent == ROOT_INODE) return true;
    ancestry_permits(inodes, Inode.parent(inode), eid, grps);
  }; 

  func isolate(inodes: Inodes, index: Index): Inode {
    let ?inode = inodes.inodes[index] else { trap("") }; inode
  };

  func flagged(flags: [Flag], flag: Flag) : Bool {
    isSome( find<Flag>(flags, func(x) = x == flag) )
  };

  func base_elem(e: Elements): Path { e[e.size()-1] };

  func dir_elems(e: Elements): Elements {
    if ( e.size() <= 1 ) return [];
    let stop: Nat = e.size() - 2;
    let ret: [var Path] = init_array(stop+1,"");
    for ( i in range(0,stop) ) ret[i] := e[i];
    freeze( ret );
  };

  func spawn(i: Index, p: Index, o: UID, g: GID, m: Modal): Inode {
    let inode = Inode.orphan(i);
    Inode.set_parent(inode, p);
    Inode.set_owner(inode, o);
    Inode.set_group(inode, g);
    Inode.set_mode(inode, m);
    print(debug_show Inode.owner(inode));
    inode;
  };

  func has_permission(inodes: Inodes, inode: Inode, eid: UID, groups: [GID], flags: [Flag]): Bool {
    let privileged: Bool = flagged(flags, O_SUDO);
    let not_hidden: Bool = Inode.is_hidden(inode) == false;
    let revealed: Bool = flagged(flags, O_SHOW);
    let permitted: Bool = do {
      if ( flagged(flags, O_WRITE) )
        if ( Inode.permits(inode, eid, groups, #write) )
          if ( flagged(flags, O_ERASE) == false ) true
          else Inode.permits(isolate(inodes, Inode.parent(inode)), eid, groups, #write)
        else false
      else Inode.permits(inode, eid, groups, #read)
    };
    privileged or ( permitted and (not_hidden or revealed) )
  };

  func roll_size_update(inodes: Inodes, index: Index): () {
    var parent: Inode = isolate(inodes, index);
    label loopdy loop {
      var count: Bytecount = 0;
      for ( c in Inode.children( parent ) ) count += Inode.size( isolate(inodes, c) );
      Inode.set_size(parent, count);
      if ( Inode.index(parent) == ROOT_INODE ) break loopdy
      else parent := isolate(inodes, Inode.parent(parent))
    };
  };

  func allocate(inodes: Inodes, parent: Index, handle: Handle, owner: UID, group: GID, mode: Modal): Inode {
    var increment: Bool = true;
    let index: Index = 
      if ( isSome( DQ.peekFront<Index>( inodes.orphaned )) == false ) inodes.count
      else {
        let ?(index, dq) = DQ.popFront<Index>( inodes.orphaned ) else {trap("")};
        inodes.orphaned := dq;
        increment := false;
        index;
      }; 
    if ( index == inodes.size ) {
      let size = 2 * inodes.size;
      let inodes2 = init_array<?Inode>(size, null);
      var i = 0;
      label loopdy loop {
        if ( i >= inodes.count ) break loopdy;
        inodes2[i] := inodes.inodes[i];
        inodes.inodes[i] := null;
        i += 1;
      };
      inodes.inodes := inodes2;
      inodes.size := size;
    };
    let inode: Inode = spawn(index, parent, owner, group, mode);
    inodes.inodes[index] := ?inode;
    if increment inodes.count += 1;
    inode
  };

};