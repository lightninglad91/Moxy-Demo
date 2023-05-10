import Common "common";
import { trap } "mo:base/Debug";
import { map = mapIter } "mo:base/Iter";
import Access "access_control";
import Location "location";
import Data "data";

module {

  public type UID = Access.UID;
  public type GID = Access.GID;
  public type Access = Access.Access;
  public type Data = Data.Data;
  public type File = Data.File;
  public type Mode = Access.Mode;
  public type Modal = Access.Modal;
  public type Directory = Data.Directory;
  public type Object = Access.Object;
  public type Mimetype = Data.Mimetype;
  public type Callback = Data.Callback;
  public type Token = Data.Token;
  public type Index = Common.Index.Index;
  public type Handle = Common.Handle.Handle;
  public type Bytecount = Common.Bytecount.Bytecount;
  public type Children = { next: () -> ?Nat };
  public type Dentries = { next: () -> ?(Handle,Nat) };
  public type Location = Location.Location;
  public type Permission = Access.Permission;

  public type Inode = {
    var l: Location;
    var b: Bytecount;
    var a: Access;
    var d: Data;
  };

  public let { ROOT_UID; ROOT_GID } = Access;

  public func orphan(index: Index): Inode {{
    var b = 0;
    var l = Location.orphan(index);
    var a = Access.orphan();
    var d = Data.orphan();
  }};

  public func size(inode: Inode): Bytecount { inode.b };

  public func index(inode: Inode) : Nat { Location.index( inode.l ) };

  public func parent(inode: Inode) : Nat { Location.parent( inode.l ) };

  public func owner(inode: Inode) : UID { Access.get_owner( inode.a ) };

  public func group(inode: Inode) : GID { Access.get_group( inode.a ) };

  public func mode(inode: Inode) : Modal { Access.get_mode( inode.a ) };

  public func set_index(inode: Inode, index: Nat): () { Location.set_index(inode.l, index) };
  
  public func set_parent(inode: Inode, parent: Nat) : () { Location.set_parent(inode.l, parent) };

  public func set_mode(inode: Inode, modal: Access.Modal): () { Access.set_mode(inode.a, modal) };

  public func set_owner(inode: Inode, owner: UID): () { Access.set_owner(inode.a, owner) };

  public func set_group(inode: Inode, group: GID): () { Access.set_group(inode.a, group) };

  public func set_mimetype(inode: Inode, m: Mimetype): () { inode.d := Data.set_mimetype(inode.d, m) };

  public func set_callback(inode: Inode, cb: Callback): () { inode.d := Data.set_callback(inode.d, cb) };

  public func set_token(inode: Inode, tok: Token): () { inode.d := Data.set_token(inode.d, tok) };

  public func set_data(inode: Inode, data: Directory or File): () { inode.d := data };

  public func set_size(inode: Inode, b: Bytecount): () { inode.b := b };

  public func is_file(inode: Inode): Bool { Access.is_file( inode.a ) };

  public func is_directory(inode: Inode): Bool { Access.is_directory( inode.a ) };

  public func is_hidden(inode: Inode): Bool { Access.is_hidden( inode.a ) }; 

  public func is_orphaned(inode: Inode): Bool { let #orphan _ = inode.d else { return false }; true };

  public func is_formatted(inode: Inode): Bool { not is_orphaned(inode) };

  public func mimetype(inode: Inode): Mimetype { Data.mimetype( inode.d ) };

  public func callback(inode: Inode): Callback { Data.callback( inode.d ) };

  public func token(inode: Inode): Token { Data.token( inode.d ) };

  public func inspect(inode: Inode): {#file;#directory;#orphan} { Data.inspect( inode.d ) };

  public func fromDentries(de: Dentries): Directory {
    Data.fromDentries(mapIter<(Handle,Nat),(Handle,Index)>(de, func((x,y)) = (x,Common.Index.fromNat(y))));
  };

  public func dentries(inode: Inode): Dentries {
    mapIter<(Handle,Index),(Handle,Nat)>(Data.dentries(inode.d), func((x,y)) = (x,Common.Index.toNat(y)))
  };

  public func children(inode: Inode): Children {
    mapIter<Index,Nat>(Data.children(inode.d), Common.Index.toNat)
  }; 

  public func find(inode: Inode, handle: Handle): ?Nat { 
    let ?n32 = Data.find(inode.d, handle) else { return null };
    ?Common.Index.toNat(n32)
  };

  public func delete(inode: Inode, handle: Handle): () {
    Data.delete(inode.d, handle)
  };

  public func add_dentry(inode: Inode, handle: Handle, index: Nat): () {
    Data.insert(inode.d, handle, Common.Index.fromNat(index))
  };

  public func format(inode: Inode, obj: Object): () {
    // let #orphan _ = inode.d else { trap("Inode is already formatted. Delete and try again") };
    switch obj {
      case(#directory){
        Access.format_directory( inode.a );
        inode.d := Data.empty_directory()
      };
      case(#file){
        Access.format_file( inode.a );
        inode.d := Data.empty_file()
      }
    }
  };

  public func permits(inode: Inode, eid: UID, grps: [GID], perm: Access.Permission) : Bool {
    switch perm {
      case ( #read ) Access.has_read(inode.a, eid, grps);
      case ( #write ) Access.has_write(inode.a, eid, grps);
      case ( #exec ) Access.has_exec(inode.a, eid, grps);
    }
  };

};