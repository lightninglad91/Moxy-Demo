import { Index } "../common";
import V0 "v0";

module {

  type Index = Index.Index;
  type Indices = V0.Indices;

  public type Location = { #v0: V0.Indices };

  public func orphan(index: Index): Location { #v0( V0.orphan(index) ) };

  public func index(loc: Location): Nat {
    switch loc {
      case ( #v0 indices ) Index.toNat(indices.i)
    }
  };

  public func parent(loc: Location): Nat {
    switch loc {
      case ( #v0 indices ) Index.toNat(indices.p)
    }
  };

  public func set_index(loc: Location, index: Nat): () {
    switch loc {
      case ( #v0 indices ) indices.i := Index.fromNat(index)
    }
  };

  public func set_parent(loc: Location, index: Nat): () {
    switch loc {
      case ( #v0 indices ) indices.p := Index.fromNat(index)
    }
  };

  public func is_child(l1: Location, l2: Location): Bool {
    index(l1) == parent(l2)
  };

  public func is_parent(l1: Location, l2: Location): Bool {
    parent(l1) == index(l2)
  };
  
};