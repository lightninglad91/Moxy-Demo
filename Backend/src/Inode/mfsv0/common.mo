import Nat32 "mo:base-ext/Nat32";
import Nat "mo:base-ext/Nat";
import Text "mo:base-ext/Text";

module {

  public module ID = {
    public type ID = Nat32;
    public type Set = Nat32.Set;
    public let { Set } = Nat32;
    public let { toNat; fromNat } = Nat32.Base;
    public let { mul; rem; div } = Nat32.Base;
    public let { equal; notEqual; compare } = Nat32.Base;
  };

  public module Index = {
    public type Index = Nat32;
    public let { compare } = Nat32.Base;
    public let { toNat; fromNat } = Nat32.Base;
    public let { equal; notEqual } = Nat32.Base;
  };

  public module Handle = {
    public type Handle = Text;
    public type Tree<T> = Text.Tree<T>;
    public let { Tree } = Text;
    public let { equal; notEqual } = Text.Base;
  };

  public module Bytecount = {
    public type Bytecount = Nat;
    public let { mul; rem; div } = Nat.Base;
    public let { equal; notEqual } = Nat.Base;
  };

  public type Dentry = (Handle.Handle,Index.Index);
  public type Dentries = {next: () -> ?Dentry};
  public type Children = {next: () -> ?Index.Index};

};