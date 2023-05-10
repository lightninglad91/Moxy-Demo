import { ID } "../../common";
import { isSome } "mo:base/Option";
import { find } "mo:base/Array";
import { print } "mo:base/Debug";
import Mode "mode";
import Groups "groups";
import Actors "actors";

module {

  public type UID = Actors.UID;
  public type GID = Groups.GID;
  public type Mode = Mode.Mode;
  public type Modal = Mode.Modal;
  public type Permission = Mode.Permission;
  public type Object = {#file; #directory};
  public type ACL = {var o: UID; var g: GID} and Mode;

  public let ROOT_UID = Actors.SUID;
  public let ROOT_GID = Groups.SGID;

  public func orphan(): ACL { {var o=ROOT_UID; var g=ROOT_GID; var m=Mode.orphan().m} };

  public func mode(acl: ACL): Modal { Mode.to_modal(acl) };

  public func owner(acl: ACL) : UID { acl.o };
 
  public func group(acl: ACL) : GID { acl.g };

  public func set_owner(acl: ACL, oid: UID) : () { acl.o := oid };

  public func set_group(acl: ACL, gid: GID) : () { acl.g := gid };

  public func set_file(acl: ACL): () { Mode.set_file(acl) };
  
  public func set_directory(acl: ACL): () { Mode.set_directory(acl) };

  public func set_mode(acl: ACL, mod: Modal): () { Mode.from_modal(acl, mod) };

  public func is_file(acl: ACL) : Bool { Mode.is_file(acl) };

  public func is_hidden(acl: ACL): Bool { Mode.is_hidden(acl)};

  public func is_directory(acl: ACL) : Bool { Mode.is_directory(acl) };

  public func is_owner(acl: ACL, id: UID) : Bool { acl.o == id };

  public func is_group_owner(acl: ACL, grps: [GID]) : Bool { isSome( find<GID>(grps, func(x) = x == group(acl)) ) };

  public func has_read(acl: ACL, eid: UID, grps: [GID]) : Bool {
    if ( eid == ROOT_UID ) true
    else if ( is_owner(acl, eid) ) Mode.has(acl, #owner(#read))
    else if ( is_group_owner(acl, grps) ) Mode.has(acl, #group(#read))
    else Mode.has(acl, #other(#read))
  };

  public func has_write(acl : ACL, eid: UID, grps: [GID]) : Bool {
    if ( eid == ROOT_UID ) true
    else if ( is_owner(acl, eid) ) Mode.has(acl, #owner(#write))
    else if ( is_group_owner(acl, grps) ) Mode.has(acl, #group(#write))
    else Mode.has(acl, #other(#write))
  };

  public func has_exec(acl : ACL, eid: UID, grps: [GID]) : Bool {
    if ( eid == ROOT_UID ) true
    else if ( is_owner(acl, eid) ) Mode.has(acl, #owner(#exec))
    else if ( is_group_owner(acl, grps) ) Mode.has(acl, #group(#exec))
    else Mode.has(acl, #other(#exec))
  };

};