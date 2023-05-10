import { trap } "mo:base/Debug";
import Directory "directory";
import Common "../common";
import File "file"

module {

  type Index = Common.Index.Index;
  type Handle = Common.Handle.Handle;
  type Bytecount = Common.Bytecount.Bytecount;

  type Dentries = Common.Dentries;
  type Children = Common.Children;

  public type Mimetype = File.Mimetype;
  public type Callback = File.Callback;
  public type Token = File.Token;

  public type Directory = Directory.Directory;
  public type File = File.File;

  public type Data = {#orphan} or Directory or File;

  public func orphan(): Data { #orphan };

  public func empty_file(): Data { File.empty() };

  public func empty_directory(): Data { Directory.empty() };

  public func find(data: Data, key: Handle): ?Index { Directory.find(to_directory(data), key) };

  public func fromDentries(de: Dentries) : Directory { Directory.fromEntries(de) };

  public func dentries(data: Data) : Dentries { Directory.entries( to_directory(data) ) };

  public func children(data: Data) : Children { Directory.children( to_directory(data) ) };

  public func delete(data: Data, key: Handle): () { Directory.delete(to_directory(data), key) };

  public func mimetype(data: Data): Mimetype { File.mimetype(to_file(data)) };

  public func callback(data: Data): Callback { File.callback(to_file(data)) };

  public func token(data: Data): Token { File.token(to_file(data)) };
  
  public func set_mimetype(data: Data, m: Mimetype): Data { File.set_mimetype(to_file(data), m) };

  public func set_callback(data: Data, cb: Callback): Data { File.set_callback(to_file(data), cb) };

  public func set_token(data: Data, tok: Token): Data { File.set_token(to_file(data), tok) };

  public func inspect(data: Data): {#file; #directory; #orphan} {
    switch data {
      case ( #tree _ ) #directory;
      case ( #metadata _ ) #file;
      case ( #orphan ) #orphan
    }
  };

  public func insert(data: Data, key: Handle, val: Index): () {
    Directory.insert(to_directory(data), key, val)
  };

  func to_directory(data: Data): Directory {
    let ret: Directory =
      switch data {
        case ( #tree t ) #tree(t);
        case _ trap("Inode.to_directory() failed to recognize variant");
      };
    ret
  };


  func to_file(data: Data): File {
    let ret: File =
      switch data {
        case ( #metadata m ) #metadata(m);
        case _ trap("Inode.to_file() failed to recognize variant");
      };
    ret
  };

};