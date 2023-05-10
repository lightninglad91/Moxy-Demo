import Common "common";
import Access "access_control";
import Location "location";
import Data "data";

module {

  public type Bytecount = Common.Bytecount.Bytecount;
  public type Location = Location.Location;
  public type Access = Access.Access;
  public type Data = Data.Data;

  public type Inode = {
    var l: Location;
    var b: Bytecount;
    var a: Access;
    var d: Data;
  };

}