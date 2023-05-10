import MFSv0 "mfsv0";
import { fromNat = n32FromNat; toNat = n32ToNat } "mo:base/Nat32";
import { isSome; get = getOpt } "mo:base/Option";
import { toArray = iterToArray } "mo:base/Iter";
import { trap } "mo:base/Debug";
import { BigEndian } "mo:encoding/Binary";

module {

  public type Inode = { #mfsv0: MFSv0.Inode };

  public type UID = MFSv0.UID;
  public type GID = MFSv0.GID;
  public type Access = MFSv0.Access;
  public type Data = MFSv0.Data;
  public type File = MFSv0.File;
  public type Mode = MFSv0.Mode;
  public type Modal = MFSv0.Modal;
  public type Directory = MFSv0.Directory;
  public type Object = MFSv0.Object;
  public type Mimetype = MFSv0.Mimetype;
  public type Callback = MFSv0.Callback;
  public type Token = MFSv0.Token;
  public type Index = MFSv0.Index;
  public type Handle = MFSv0.Handle;
  public type Bytecount = MFSv0.Bytecount;
  public type Children = MFSv0.Children;
  public type Dentries = MFSv0.Dentries;
  public type Location = MFSv0.Location;
  public type Permission = MFSv0.Permission;

  public type SharedInode = (Nat,Nat,Nat,Nat,Nat,Nat,SharedObject);

  public type SharedObject = {#directory: [(Handle,Nat)]; #file: (Text,(Callback,Token))};

  public let { ROOT_UID; ROOT_GID } = MFSv0;

  public func orphan(index: Nat): Inode { #mfsv0( MFSv0.orphan(n32FromNat(index)) ) };

  public func size(inode: Inode): Bytecount {
    switch inode { case (#mfsv0 i) MFSv0.size( i ) }
  };

  public func index(inode: Inode): Nat {
    switch inode { case (#mfsv0 i) MFSv0.index( i ) }
  };

  public func parent(inode: Inode): Nat {
    switch inode { case (#mfsv0 i) MFSv0.parent( i ) }
  };

  public func owner(inode: Inode) : UID {
    switch inode { case (#mfsv0 i) MFSv0.owner( i ) }
  };

  public func group(inode: Inode) : GID {
    switch inode { case (#mfsv0 i) MFSv0.group( i ) }
  };

  public func mode(inode: Inode) : Modal {
    switch inode { case (#mfsv0 i) MFSv0.mode( i ) }
  };

  public func set_index(inode: Inode, index: Nat): () {
    switch inode { case (#mfsv0 i) MFSv0.set_index(i, index) }
  };

  public func set_parent(inode: Inode, parent: Nat): () {
    switch inode { case (#mfsv0 i) MFSv0.set_parent(i, parent) }
  };

  public func set_mode(inode: Inode, mode: Modal): () {
    switch inode { case (#mfsv0 i) MFSv0.set_mode(i, mode) }
  };

  public func set_owner(inode: Inode, uid: UID): () {
    switch inode { case (#mfsv0 i) MFSv0.set_owner(i, uid) }
  };

  public func set_group(inode: Inode, gid: GID): () {
    switch inode { case (#mfsv0 i) MFSv0.set_group(i, gid) }
  };

  public func set_mimetype(inode: Inode, m: Mimetype): () {
    switch inode { case (#mfsv0 i) MFSv0.set_mimetype(i, m) }
  };

  public func set_callback(inode: Inode, cb: Callback): () {
    switch inode { case (#mfsv0 i) MFSv0.set_callback(i, cb) }
  };

  public func set_token(inode: Inode, tok: Token): () {
    switch inode { case (#mfsv0 i) MFSv0.set_token(i, tok) }
  };

  public func set_data(inode: Inode, data: Directory or File): () {
    switch inode { case (#mfsv0 i) MFSv0.set_data(i, data) }
  };

  public func set_size(inode: Inode, size: Bytecount): () {
    switch inode { case (#mfsv0 i) MFSv0.set_size(i, size) }
  };

  public func is_file(inode: Inode): Bool {
    switch inode { case (#mfsv0 i) MFSv0.is_file( i ) }
  };

  public func is_directory(inode: Inode): Bool {
    switch inode { case (#mfsv0 i) MFSv0.is_directory( i ) }
  };

  public func is_hidden(inode: Inode): Bool {
    switch inode { case (#mfsv0 i) MFSv0.is_hidden( i ) }
  };

  public func is_orphaned(inode: Inode): Bool {
    switch inode { case (#mfsv0 i) MFSv0.is_orphaned( i ) }
  };

  public func is_formatted(inode: Inode): Bool {
    switch inode { case (#mfsv0 i) MFSv0.is_formatted( i ) }
  };

  public func is_populated(inode: Inode): Bool {
    switch inode { case (#mfsv0 i) isSome(MFSv0.children(i).next()) }
  };

  public func children(inode: Inode): Children {
    switch inode { case (#mfsv0 i) MFSv0.children( i ) }
  };

  public func dentries(inode: Inode): Dentries {
    switch inode { case (#mfsv0 i) MFSv0.dentries( i ) }
  };

  public func mimetype(inode: Inode): Mimetype {
    switch inode { case (#mfsv0 i) MFSv0.mimetype( i ) }
  };

  public func inspect(inode: Inode): {#directory;#file;#orphan} {
    switch inode { case (#mfsv0 i) MFSv0.inspect( i ) }
  };

  public func callback(inode: Inode): Callback {
    switch inode { case (#mfsv0 i) MFSv0.callback( i ) }
  };

  public func token(inode: Inode): Token {
    switch inode { case (#mfsv0 i) MFSv0.token( i ) }
  };

  public func find(inode: Inode, handle: Handle): ?Nat {
    switch inode { case (#mfsv0 i) MFSv0.find(i, handle) }
  };

  public func delete(inode: Inode, handle: Handle): () {
    switch inode { case (#mfsv0 i) MFSv0.delete(i, handle) }
  };

  public func add_dentry(inode: Inode, handle: Handle, index: Nat): () {
    switch inode { case (#mfsv0 i) MFSv0.add_dentry(i, handle, index) }
  };

  public func format(inode: Inode, obj: Object): () {
    switch inode { case (#mfsv0 i) MFSv0.format(i, obj) }
  };

  public func permits(inode: Inode, eid: UID, grps: [GID], perm: Permission): Bool {
    switch inode { case (#mfsv0 i) MFSv0.permits(i, eid, grps, perm) }
  };

  public func clone(input: Inode): Inode {
    switch input {
      case (#mfsv0 i){
        let inode: MFSv0.Inode = MFSv0.orphan(n32FromNat(MFSv0.index(i)));
        MFSv0.set_mode(inode, MFSv0.mode(i));
        MFSv0.set_size(inode, MFSv0.size(i));
        MFSv0.set_parent(inode, MFSv0.parent(i));
        MFSv0.set_owner(inode, MFSv0.owner(i));
        MFSv0.set_group(inode, MFSv0.group(i));
        if ( MFSv0.is_directory(i) ){
          MFSv0.format(inode, #directory);
          MFSv0.set_data(inode, MFSv0.fromDentries( MFSv0.dentries(i) ));
        };
        if ( MFSv0.is_file(i) ) {
          MFSv0.format(inode, #file);
          MFSv0.set_mimetype(inode, MFSv0.mimetype(i));
          MFSv0.set_callback(inode, MFSv0.callback(i));
          MFSv0.set_token(inode, MFSv0.token(i));
        };
        #mfsv0( inode )
      }
    }
  };

  public func share(inode: Inode): SharedInode {
    switch inode {
      case (#mfsv0 i){
        let mod: Modal = MFSv0.mode(i);
        return (
          MFSv0.index(i),
          MFSv0.parent(i),
          n32ToNat(MFSv0.owner(i)),
          n32ToNat(MFSv0.group(i)),
          n32ToNat(BigEndian.toNat32([mod.0, mod.1, mod.2, mod.3])),
          MFSv0.size(i),
          if ( MFSv0.is_directory(i) ) #directory( iterToArray(MFSv0.dentries(i)) )
          else #file(MFSv0.mimetype(i), (MFSv0.callback(i), MFSv0.token(i)) )
        )
      }
    }
  };

  // public func share(inode: Inode, index: ?Nat, parent: ?Nat): SharedInode {
  //   switch inode {
  //     case (#mfsv0 i){
  //       let mod: Modal = MFSv0.mode(i);
  //       return (
  //         getOpt<Nat>(index, MFSv0.index(i)),
  //         getOpt<Nat>(parent, MFSv0.parent(i)),
  //         n32ToNat(MFSv0.owner(i)),
  //         n32ToNat(MFSv0.group(i)),
  //         n32ToNat(BigEndian.toNat32([mod.0, mod.1, mod.2, mod.3])),
  //         MFSv0.size(i),
  //         if ( MFSv0.is_directory(i) ) #directory( iterToArray(MFSv0.dentries(i)) )
  //         else #file(MFSv0.mimetype(i), (MFSv0.callback(i), MFSv0.token(i)) )
  //       )
  //     }
  //   }
  // };

  public func unshare(shared_: SharedInode): Inode {
    let inode: Inode = orphan(0);
    switch inode {
      case (#mfsv0 i){
        let m: [Nat8] = BigEndian.fromNat32(n32FromNat(shared_.4));
        MFSv0.set_size(i, shared_.5);
        MFSv0.set_index(i, shared_.0);
        MFSv0.set_parent(i, shared_.1);
        MFSv0.set_owner(i, n32FromNat(shared_.2));
        MFSv0.set_group(i, n32FromNat(shared_.3));
        MFSv0.set_mode(i, (m[0], m[1], m[2], m[3]));
        if ( MFSv0.is_directory(i) ){
          MFSv0.format(i, #directory);
          let #directory de = shared_.6 else { trap("expected directory data but didn't find any") };
          MFSv0.set_data(i, MFSv0.fromDentries( de.vals() ));
        };
        if ( MFSv0.is_file(i) ){
          MFSv0.format(i, #file);
          let #file f = shared_.6 else { trap("expected file data but didn't find any") };
          MFSv0.set_mimetype(i, f.0);
          MFSv0.set_callback(i, f.1.0);
          MFSv0.set_token(i, f.1.1);
        }
      }
    };
    inode
  };

}