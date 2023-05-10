import { BigEndian } "mo:encoding/Binary";
import { thaw; freeze } "mo:base/Array";

module {

  public type Mode = {var m: Nat32};

  public type Modal = (Nat8,Nat8,Nat8,Nat8);

  public type Change = { #add : Actor ; #remove : Actor };
  public type Actor = { #owner : Permission; #group : Permission ; #other : Permission };
  public type Permission = { #read; #write; #exec };

  let (FILE, DIRECTORY, HIDDEN) = (0: Nat8, 1: Nat8, 2: Nat8);
  let (READ, WRITE, EXEC) = (4: Nat8, 2: Nat8, 1: Nat8);

  public func orphan(): Mode = {var m = 0xFFFFFFFF};

  public func is_file(mode: Mode) : Bool { BigEndian.fromNat32(mode.m)[0] == FILE };

  public func is_directory(mode: Mode) : Bool { BigEndian.fromNat32(mode.m)[0] == DIRECTORY };

  public func is_hidden(mode: Mode): Bool { BigEndian.fromNat32(mode.m)[0] == HIDDEN };

  public func from_modal(mode: Mode, mod: Modal): () { mode.m := BigEndian.toNat32([mod.0,mod.1,mod.2,mod.3]) };
  
  public func to_modal(mode: Mode): Modal {
    let b = BigEndian.fromNat32( mode.m );
    (b[0],b[1],b[2],b[3])
  };

  public func set_file(mode: Mode) : () {
    let b: [Nat8] = BigEndian.fromNat32(mode.m);
    mode.m := BigEndian.toNat32( [FILE, b[1], b[2], b[3]] )
  };

  public func set_directory(mode: Mode) : () {
    let b: [Nat8] = BigEndian.fromNat32(mode.m);
    mode.m := BigEndian.toNat32( [DIRECTORY, b[1], b[2], b[3]] )
  };

  public func set_hidden(mode: Mode) : () {
    let b: [Nat8] = BigEndian.fromNat32(mode.m);
    mode.m := BigEndian.toNat32( [HIDDEN, b[1], b[2], b[3]] )
  };

  public func has(mode: Mode, actor_: Actor) : Bool {
    switch actor_ {
      case(#owner perm) _has_permission(mode, 1, perm);
      case(#group perm) _has_permission(mode, 2, perm);
      case(#other perm) _has_permission(mode, 3, perm);
    }
  };

  public func change(mode: Mode, change: Change) : () {
    switch change {
      case ( #add subject ) _change(mode, subject, true);
      case ( #remove subject ) _change(mode, subject, false);
    }
  };

  func _has_permission(mode: Mode, subject: Nat, perm: Permission) : Bool {
    switch perm {
      case(#read) BigEndian.fromNat32(mode.m)[subject] & READ == READ;
      case(#write) BigEndian.fromNat32(mode.m)[subject] & WRITE == WRITE;
      case(#exec) BigEndian.fromNat32(mode.m)[subject] & EXEC == EXEC;
    }
  };

  func _change(mode: Mode, subject: Actor, add: Bool) : () {
    switch subject {
      case ( #owner perm ) _change_permission(mode, 1, perm, add);
      case ( #group perm ) _change_permission(mode, 2, perm, add);
      case ( #other perm ) _change_permission(mode, 3, perm, add);
    }
  }; 

  func _change_permission(mode: Mode, subject: Nat, perm : Permission, add: Bool) : () {
    let modifier: Nat8 = switch perm { case(#read) READ; case(#write) WRITE; case(#exec) EXEC };
    let b: [var Nat8] = thaw<Nat8>(BigEndian.fromNat32(mode.m));
    if add b[subject] := b[subject] | modifier
    else b[subject] := b[subject] ^ modifier;
    mode.m := BigEndian.toNat32( freeze<Nat8>(b) );
  };

};