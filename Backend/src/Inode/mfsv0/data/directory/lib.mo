import Common "../../common";
import { trap } "mo:base/Debug";
import Tree "tree";

module {

  public type Tree = Tree.Tree;
  public type Directory = {#tree: Tree};

  public type Dentries = Common.Dentries;
  public type Children = Common.Children;
  public type Index = Common.Index.Index;
  public type Handle = Common.Handle.Handle;
  public type Bytecount = Common.Bytecount.Bytecount;

  public func empty(): Directory { #tree( Tree.empty() ) };

  public func find(dir: Directory, handle: Handle) : ?Index {
    switch dir {
      case (#tree tree) Tree.find(tree, handle);
    };
  };

  public func fromEntries(de: Dentries) : Directory {
    #tree( Tree.fromEntries( de ) )
  }; 

  public func entries(dir: Directory) : Dentries {
    switch dir {
      case (#tree tree) Tree.entries(tree);
    };
  };

  public func children(dir: Directory) : Children {
    switch dir {
      case (#tree tree) Tree.children(tree);
    };
  };

  public func insert(dir: Directory, handle: Handle, index: Index): () {
    switch dir {
      case (#tree tree) Tree.insert(tree, handle, index);
    }
  }; 

  public func delete(dir: Directory, handle: Handle): () {
    switch dir {
      case (#tree tree) Tree.delete(tree, handle);
    }
  }; 

};