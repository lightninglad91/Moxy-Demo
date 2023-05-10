
import { Index } "../../common";
import Inode "../../InodeType";
import DQ "mo:base/Deque";


/*THIS IS A WORK IN PROGRESS*/

module {

  public type Index = Nat;
  public type Inode = Inode.Inode;

  public type Inodes = {
    var size: Nat;
    var count: Nat;
    var inodes: [var ?Inode];
    var orphaned: DQ.Deque<Index>;
  };

  public type Overlay = {
    var nodes: Inodes;
    var local: Inode;
  };

//   public func entries(o: Overlay): Entries { Handle.Tree.entries(tree.t) };

//   public func fromEntries(e: Entries): Tree { { var t = Handle.Tree.fromEntries<Index>(toArray(e)) } };

//   public func children(tree: Tree): Children { Handle.Tree.vals(tree.t) };

//   public func find(tree: Tree, key: Handle): ?Index { Handle.Tree.find<Index>(tree.t, key) };

//   public func insert(tree: Tree, key: Handle, val: Index): () { tree.t := Handle.Tree.insert<Index>(tree.t, key, val) };

//   public func delete(tree: Tree, key: Handle): () { tree.t := Handle.Tree.delete<Index>(tree.t, key) };

};