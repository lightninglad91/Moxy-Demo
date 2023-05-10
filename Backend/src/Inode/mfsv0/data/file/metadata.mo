import Http "mo:base-ext/Utils/Http";
import { Base = Principal } "mo:base-ext/Principal";
import { trap } "mo:base/Debug";

module {

  public type Metadata = (Mimetype,Location);

  public type Mimetype = Text;
  public type Callback = Http.StreamingCallback;
  public type Token = Http.StreamingToken;

  public type Location = ?(Callback,Token);

  public func empty(): Metadata {("",null)};

  public func mimetype(md: Metadata): Mimetype { md.0 };

  public func callback(md: Metadata): Callback {
    let ?(cb,_) = md.1 else { return empty_callback() }; cb
  };

  public func token(md: Metadata): Token {
    let ?(_,tok) = md.1 else { return empty_token() }; tok
  };

  public func set_mimetype(md: Metadata, m: Mimetype): Metadata { (m, md.1) };

  public func set_callback(md: Metadata, cb: Callback): Metadata {
    let ?(_,tok) = md.1 else { return (md.0, ?(cb,empty_token())) }; (md.0, ?(cb,tok))
  };

  public func set_token(md: Metadata, tok: Token): Metadata {
    let ?(cb,_) = md.1 else { return (md.0, ?(empty_callback(),tok)) }; (md.0, ?(cb,tok))
  };

  func empty_callback(): Callback {
    let temp = actor("aaaaa-aa") : actor { read: Callback };
    temp.read
  };

  func empty_token(): Token {{
    start = (0,0);
    stop = (0,0);
    key = "";
    nested = [];
  }};

};