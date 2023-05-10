import { Index } "../../common";

module {

  type Index = Index.Index;

  public type Indices = {
    var i: Index;
    var p: Index;
  };

  public func orphan(index: Index): Indices {{var i=index; var p=0}};

  public func self(indices: Indices): Index { indices.i };

  public func parent(indices: Indices): Index { indices.p };

  public func set_parent(indices: Indices, parent: Index): () { indices.p := parent };

  public func set_self(indices: Indices, self: Index): () { indices.i := self };

  public func is_child(indices: Indices, cindex: Indices): Bool {indices.i == cindex.p };

  public func is_parent(indices: Indices, pindex: Indices): Bool { indices.p == pindex.i };

};