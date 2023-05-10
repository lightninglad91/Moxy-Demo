import V0 "v0";

module {

  public type UID = V0.UID;
  public type GID = V0.GID;
  public type Mode = V0.Mode;
  public type Modal = V0.Modal;
  public type Permission = V0.Permission;
  public type Object = V0.Object;

  public type Access = { #v0: V0.ACL };

  public let ROOT_UID = V0.ROOT_UID;
  public let ROOT_GID = V0.ROOT_GID;

  public func orphan(): Access { #v0( V0.orphan() ) };

  public func get_mode(acc: Access): Modal {
    switch acc { case (#v0 acl) V0.mode( acl ) }
  };

  public func get_owner(acc: Access) : UID {
    switch acc { case (#v0 acl) V0.owner( acl ) }
  };
 
  public func get_group(acc: Access) : GID {
    switch acc { case (#v0 acl) V0.group( acl ) }
  };

  public func set_owner(acc: Access, oid: UID) : () { 
    switch acc { case (#v0 acl) V0.set_owner(acl, oid) }
  };

  public func set_group(acc: Access, gid: UID) : () { 
    switch acc { case (#v0 acl) V0.set_group(acl, gid) }
  };

  public func set_mode(acc: Access, mod: Modal) : () { 
    switch acc { case (#v0 acl) V0.set_mode(acl, mod) }
  };

  public func format_file(acc: Access) : () { 
    switch acc { case (#v0 acl) V0.set_file( acl ) }
  };

  public func format_directory(acc: Access) : () { 
    switch acc { case (#v0 acl) V0.set_directory( acl ) }
  };

  public func is_file(acc: Access) : Bool { 
    switch acc { case (#v0 acl) V0.is_file(acl) }
  };

  public func is_directory(acc: Access) : Bool { 
    switch acc { case (#v0 acl) V0.is_directory(acl) }
  };

  public func is_hidden(acc: Access) : Bool { 
    switch acc { case (#v0 acl) V0.is_hidden(acl) }
  };

  public func is_owner(acc: Access, uid: UID) : Bool { 
    switch acc { case (#v0 acl) V0.is_owner(acl, uid) }
  };

  public func is_group_owner(acc: Access, grps: [GID]) : Bool { 
    switch acc { case (#v0 acl) V0.is_group_owner(acl, grps) }
  };

  public func has_read(acc: Access, eid: UID, grps: [GID]): Bool {
    switch acc { case (#v0 acl) V0.has_read(acl, eid, grps) }
  };

  public func has_write(acc: Access, eid: UID, grps: [GID]): Bool {
    switch acc { case (#v0 acl) V0.has_write(acl, eid, grps) }
  };

  public func has_exec(acc: Access, eid: UID, grps: [GID]): Bool {
    switch acc { case (#v0 acl) V0.has_exec(acl, eid, grps) }
  };

};