import Path "mo:filepaths/Path";
import Index "mo:base-ext/Nat";
import HB "mo:scheduling/Tasks";
import Http "mo:base-ext/Utils/Http";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat8 "mo:base/Nat8";
import Order "mo:base/Order";
import Time "mo:base/Time";
import Result "mo:base/Result";

module {

  public type Handle = Text;
  public type MimeType = Text;
  public type Bytes = Nat;
  public type Range   = (Point,Point);
  public type Point   = (Index,Index);
  public type Mapping = (Index,Principal,Range);
  public type Index = Nat;
  public type Path = Path.Path;
  public type Priv = { #RO; #WO; #RW; #NO };
  public type Mode = (Priv,Priv); // ( Group, World )
  public type Dentry = (Index,Index,Handle,DState); 
  public type StagedFiles = [(Index, StorageStrategy)];
  public type Filedata = {name : Handle; size : Bytes; ftype : MimeType};
  public type Strategy = [(Text,[Instruction])];
  public type Instruction = (Handle,Index,Nat);
  public type DState = { #Valid; #Hidden };
  public type Mount = [Inode];
  public type Manifest = [(Index, Filedata)];
  public type Transition = {#Mapped; #Finished};
  public type CyclesReport = HB.CyclesReport;
  public type ChainReport = HB.ChainReport;
  public type ChildService = HB.ChildService;
  public type UploadStrategy = (Bytes,BlockCount,BlockCount,Strategy);

  public type Error = {
    #FatalFault;
    #FailedInit : Text;
    #NotPermitted;
    #NotFound : Path;
    #Corrupted;
    #EmptyPath : Path;
    #AlreadyExists : Path;
    #NotFile : Path;
    #NotDirectory : Path;
    #Unauthorized;
    #IncompatibleInode;
    #Invalid : Path;
    #ServiceLimit;
    #TryAgain;
    #Busy;
  };

  public type Return<T> = Result.Result<T,Error>;

  public type IC = actor {
    update_settings : shared ({
      canister_id : Principal;
      settings : {
        controllers : [Principal];
      }
    }) -> async () };

  public type SaveCmd = shared ([(Index,File)]) -> async ();
  public type SaveFn = ([(Index,File)]) -> ();
  public type RegisterCmd = shared (HB.Task,HB.Task) -> async ();

  public type OptStrategyMethod = () -> async ?UploadStrategy;
  public type Status = {
    #Finished : (OptStrategyMethod,Principal);
    #Busy;
    #Staged;
    #Ready;
    #Mapped;
    #Delete;
    #Reserved;
    #Null;
  };

  public type Metadata = {
    owner : Principal;
    range : Range;
    key   : Text;
    open  : Bool;
  };

  public type UploadRequest = {
    path : Path;
    delegate : ?Principal;
    manifest : [Filedata];
    group : [Principal];
  };

  public type WriteRequest = {
    delegate : Principal;
    owners : [Principal];
    manifest : Manifest;
  };

  public type TempFile = {
    var name : Handle;
    var size : Bytes;
    var ftype : MimeType;
    var owner : Principal;
    var timestamp : Time.Time;
    var owners : [Principal];
    var bytecount: Bytes;
  };

  public type StorageDevice = {
    open      : shared (FormatRequest) -> async Return<FormatResponse>;
    close     : shared (Index) -> async ();
    principal : Principal;
    available : BlockCount;
  };

  public type StorageStrategy = {
    #Direct : BlockCount;
    #Distributed : (SectorCount, BlockCount);
  };

  public type FormatRequest = [(Index,Principal,BlockCount,Text)];
  public type FormatResponse = {
    callback : Http.StreamingCallback;
    tokens   : [(Index,Index,Http.StreamingToken)];
  };

  public type Filesystem = {
    var root   : Principal;
    var count  : Nat;
    var inodes : [var Inode];
  };

  public type Inode = {
    #Reserved : Principal;
    #Directory : Directory;
    #File : File;
  };

  public type Directory = {
    inode : Index;
    parent : Index;
    name : Handle;
    owner : Principal;
    group : [Principal];
    mode : Mode;
    contents : [Dentry];
  };

  public type File = {
    name : Handle;
    size : Bytes;
    ftype : MimeType;
    timestamp : Time.Time;
    owner : Principal;
    group : [Principal];
    mode : Mode;
    pointer : {
      callback : Http.StreamingCallback;
      token    : Http.StreamingToken;
    };
  };

  public type DACL = {
    owner : Principal;
    group : [Principal];
    mode : Mode;
  };

  public type BlockCount = Nat;
  public type PageCount = Nat;
  public type SectorCount = Nat;

  public type StorageArray = [var Object];
  public type Object = [var Blob];

  public let BLOCK_SIZE : Bytes = 4000;
  public let PAGE_SIZE : Bytes = 2000000;
  public let SECTOR_SIZE : Bytes = 2000000000;

  private func mul( x : Nat, y : Bytes ) : Bytes { x * y };

  private func div( x : Bytes, y : Bytes ) : Nat {
    var ret : Nat = x / y;
    let rem : Nat = x % y;
    if (rem > 0){ ret += 1 };
    ret;  
  };

  public module Filedata = {
    public func compare( x : (Index, Filedata), y : (Index, Filedata) ) : Order.Order {
      Nat.compare(x.1.size, y.1.size);
    };
  };

  public module BlockCount = {
    public func bytes( x : BlockCount ) : Bytes {
      mul(x, BLOCK_SIZE);
    };
    public func from_bytes( x : Bytes ) : BlockCount {
      div(x, BLOCK_SIZE);
    };
  };

  public module PageCount = {
    public func bytes( x : PageCount ) : Bytes {
      mul(x, PAGE_SIZE);
    };
    public func from_bytes( x : Bytes ) : PageCount {
      div(x, PAGE_SIZE);
    };
    public func blocks( x : PageCount ) : BlockCount {
      BlockCount.from_bytes( bytes(x) );
    };
    public func from_blocks( x : BlockCount ) : PageCount {
      from_bytes( BlockCount.bytes(x) );
    };
  };

  public module SectorCount = {
    public func bytes( x : SectorCount ) : Bytes {
      mul(x, SECTOR_SIZE);
    };
    public func from_bytes( x : Bytes ) : SectorCount {
      div(x, SECTOR_SIZE);
    };
    public func blocks( x : SectorCount ) : BlockCount {
      BlockCount.from_bytes( bytes(x) );
    };
    public func from_blocks( x : BlockCount ) : SectorCount {
      from_bytes( BlockCount.bytes(x) );
    };
    public func pages( x : SectorCount ) : PageCount {
      PageCount.bytes( bytes(x) );
    };
    public func from_pages( x : PageCount ) : SectorCount {
      from_bytes( PageCount.bytes(x) );
    };
  };

};