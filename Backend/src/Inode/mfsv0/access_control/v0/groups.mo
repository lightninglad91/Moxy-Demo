import { ID; Handle } "../../common";
import Debug "mo:base/Debug";
import Text "mo:base-ext/Text";
import Option "mo:base/Option";
import { map } "mo:base/Array";
import Sbuffer "mo:stableBuffer/StableBuffer";

module {

  public type ID = ID.ID;
  public type GID = ID.ID;
  public type Handle = Handle.Handle;
  public type Owner = {#uid: ID; #gid: GID};
  public type Group = (Owner, ID.Set);

  public type Groups = {
    var registry : Handle.Tree<GID>;
    var lookup   : Sbuffer.StableBuffer<Handle>;
    var groups   : Sbuffer.StableBuffer<Group>;
  };

  public let SGID: GID = 0;

  public module Group = {

    public type Members = { next : () -> ?ID };

    public func new( owner : Owner ) : Group { (owner, ID.Set.init()) };

    public func size( grp : Group ) : Nat { ID.Set.size(grp.1) };

    public func members( grp : Group ) : Members { ID.Set.keys(grp.1) };

    public func isMember( grp: Group, uid: ID ) : Bool { ID.Set.match(grp.1, uid) };

    public func isOwner(grp: Group, eid: ID ) : Bool {
      switch( grp.0 ){
        case ( #uid oid ) oid == eid;
        case ( #gid gid ) Group.isMember(grp, eid)
      }
    };

  };

  public func init() : Groups {{
    var lookup = Sbuffer.init<Handle>();
    var groups = Sbuffer.init<Group>();
    var registry = Handle.Tree.init<GID>();
  }};

  public func lookup(reg: Groups, gid: GID): Handle {
    let index: Nat = ID.toNat(gid);
    assert index < reg.groups.count;
    reg.lookup.elems[index]
  };

  public func isRegistered(reg : Groups, handle : Handle) : Bool {
    Option.isSome( Handle.Tree.find<GID>(reg.registry, handle) );
  };

  public func isMemberOf(reg : Groups, k : Handle, v : ID) : Bool {
    let ?group = getGroupByHandle(reg, k) else return false;
    Group.isMember(group, v);
  };
  
  public func getGroupByGID(reg : Groups, gid : GID) : ?Group {
    if ( gid < ID.fromNat(reg.groups.count) ) ?reg.groups.elems[ID.toNat(gid)] else null
  };

  public func getGID(reg: Groups, handle: Handle): ?GID {
    Handle.Tree.find<GID>(reg.registry, handle)
  };

  public func getGroupByHandle(reg : Groups, handle : Handle) : ?Group {
    let ?gid = Handle.Tree.find<GID>(reg.registry, handle) else return null;
    if ( gid >= ID.fromNat(reg.groups.count) ) Debug.trap("Groups: registered Group ID is out of bounds");
    ?reg.groups.elems[ID.toNat(gid)];
  };

  public func getGroupMembers(reg: Groups, handle: Handle): [GID] {
    let ?(_, idset) = getGroupByHandle(reg, handle) else { return [] };
    ID.Set.toArray(idset);
  };

  public func addGroupMember(reg: Groups, eid: ID, k: Handle, v: ID) : Bool {
    let ?group = getGroupByHandle(reg, k) else return false;
    if ( Group.isOwner(group, eid) ){ ID.Set.insert(group.1, v); true } else false
  };

  public func removeGroupMember(reg: Groups, eid: ID, k: Handle, v: ID) : Bool {
    let ?group = getGroupByHandle(reg, k) else return false;
    if ( Group.isOwner(group, eid) ){ ID.Set.delete(group.1, v); true } else false
  };

  public func register(reg : Groups, oid : Owner, handle : Handle) : GID {
    assert reg.groups.count == reg.lookup.count;
    switch( Handle.Tree.find<GID>(reg.registry, handle) ){
      case ( ?gid ) gid;
      case null {
        let gid: GID = ID.fromNat(reg.groups.count);
        Sbuffer.add(reg.lookup, handle);
        Sbuffer.add(reg.groups, Group.new( oid ));
        reg.registry := Handle.Tree.insert<GID>(reg.registry, handle, gid);
        gid
      }
    }
  }; 

};