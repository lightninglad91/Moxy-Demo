import Metadata "metadata";

module {

  public type Mimetype = Metadata.Mimetype;
  public type Callback = Metadata.Callback;
  public type Token = Metadata.Token;


  public type File = { #metadata: Metadata.Metadata };

  public func empty(): File { #metadata( Metadata.empty() ) };

  public func mimetype(f: File): Mimetype {
    switch f { case (#metadata md) Metadata.mimetype(md) }
  };

  public func callback(f: File): Callback {
    switch f { case (#metadata md) Metadata.callback(md) }
  };

  public func token(f: File): Token {
    switch f { case (#metadata md) Metadata.token(md) }
  };

  public func set_mimetype(f: File, m: Mimetype): File {
    switch f { case (#metadata md) #metadata(Metadata.set_mimetype(md, m)) }
  };

  public func set_callback(f: File, cb: Callback): File {
    switch f { case (#metadata md) #metadata(Metadata.set_callback(md, cb)) }
  };

  public func set_token(f: File, tok: Token): File {
    switch f { case (#metadata md) #metadata(Metadata.set_token(md, tok)) }
  };

};