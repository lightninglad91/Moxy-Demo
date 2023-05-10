import Common "../../common";
import { toArray } "mo:base/Iter";

module {

  type Entry = Common.Dentry;
  type Entries = Common.Dentries;
  type Children = Common.Children;
  type Index = Common.Index.Index;
  type Handle = Common.Handle.Handle;

  let Handle = Common.Handle;

  public type Tree = {var t: Handle.Tree<Index>};

  public func empty(): Tree { {var t = Handle.Tree.init<Index>() } };

  public func entries(tree: Tree): Entries { Handle.Tree.entries(tree.t) };

  public func fromEntries(e: Entries): Tree { { var t = Handle.Tree.fromEntries<Index>(toArray(e)) } };

  public func children(tree: Tree): Children { Handle.Tree.vals(tree.t) };

  public func find(tree: Tree, key: Handle): ?Index { Handle.Tree.find<Index>(tree.t, key) };

  public func insert(tree: Tree, key: Handle, val: Index): () { tree.t := Handle.Tree.insert<Index>(tree.t, key, val) };

  public func delete(tree: Tree, key: Handle): () { tree.t := Handle.Tree.delete<Index>(tree.t, key) };

};