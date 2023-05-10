import { ID } "../../common";
import Principal "mo:base-ext/Principal";
import { get = getOpt } "mo:base/Option";
import { range } "mo:base/Iter";
import { trap } "mo:base/Debug";
import Actor "mo:base-ext/Principal";
import Buffer "mo:base/Buffer";
import Sbuffer "mo:stableBuffer/StableBuffer";
import Array "mo:base/Array";

module {

  public type UID = ID;
  public type ID = ID.ID;
  public type Actor = Principal;
  public type Identifiers = (UID, [ID]);
  public type Registration = {id: Principal; var groups: [ID]};

  public type Actors = {
    var size: Nat;
    var count: Nat;
    var registered: [var Registration];
  };

  public let SUID: UID = 0;

  public func init(initCapacity: ?Nat) : Actors {{
    var size: Nat = getOpt<Nat>(initCapacity, 1);
    var count : Nat = 0;
    var registered = initialize( getOpt<Nat>(initCapacity, 1) );
  }};

  public func toArray(actors: Actors): [Principal] {
    let buffer = Buffer.Buffer<Principal>(actors.registered.size());
    for ( entry in actors.registered.vals() ) buffer.add( entry.id );
    Buffer.toArray<Principal>( buffer )
  };

  public func lookup(actors: Actors, uid: UID): Principal {
    actors.registered[ID.toNat(uid)].id
  };

  public func get_principal(actors: Actors, uid: UID): ?Principal {
    let index: Nat = ID.toNat(uid);
    if ( index >= actors.count ) null
    else ?actors.registered[index].id
  };

  public func get_identifiers(actors: Actors, actor_: Actor): ?Identifiers {
    let ?index = indexOf(actors, actor_) else { return null };
    ?(ID.fromNat(index), actors.registered[index].groups)
  };

  public func remove_groups(actors: Actors, actor_: Actor, grps: [ID]): () {
    switch( indexOf(actors, actor_) ){
      case null ();
      case ( ?index ){
        let registration = actors.registered[index];
        let groups = Buffer.fromArray<ID>( registration.groups );
        let removed = Buffer.fromArray<ID>( grps );
        groups.filterEntries( func(_, x): Bool { not Buffer.contains<ID>(removed, x, ID.equal) } );
        registration.groups := Buffer.toArray<ID>( groups )
      }
    }
  };

  public func add_groups(actors: Actors, actor_: Actor, grps: [ID]): {#ok;#err} {
    switch( indexOf(actors, actor_) ){
      case null return #err;
      case ( ?index ){
        let registration = actors.registered[index];
        let groups = Buffer.fromArray<ID>( registration.groups );
        let update = Buffer.fromArray<ID>( grps );
        groups.append( update );
        Buffer.removeDuplicates<ID>(groups, ID.compare);
        #ok( registration.groups := Buffer.toArray<ID>( groups ) )
      }
    }
  };

  public func register(actors: Actors, actor_: Actor) : UID {
    switch( indexOf(actors, actor_) ){
      case ( ?index ) return ID.fromNat(index);
      case null {
        let ret: UID = ID.fromNat(actors.count);
        if ( actors.count == actors.size ){
          let size = actors.size * 2;
          let elems2 = initialize(size);
          for ( idx in range(0, actors.count-1) ) elems2[idx] := actors.registered[idx];
          actors.size := size;
          actors.registered := elems2;
        };
        actors.registered[actors.count] := {id=actor_; var groups=[]};
        actors.count += 1;
        ret
      }
    }
  };

  func indexOf (actors: Actors, actor_: Actor): ?Nat {
    for ( idx in range(0,actors.count-1) )
      if ( actors.registered[idx].id == actor_ ) return ?idx;
    null
  };

  func initialize(size: Nat): [var Registration] {
    Array.init<Registration>(size, {id=Principal.placeholder(); var groups=[]})
  };

};