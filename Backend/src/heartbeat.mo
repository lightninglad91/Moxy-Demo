import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base-ext/Principal";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Result "mo:base/Result";
import Task "mo:scheduling/Tasks";


shared ({ caller = _installer }) actor class Heartbeat() = this {

  // ========================================================================= //
  // Type Definitions                                                          // 
  // ========================================================================= //
  //
  private type ScheduledTask = Task.ScheduledTask;
  private type Schedule = Task.Schedule;
  private type Registry = Task.Registry;
  private type Increments = Task.Increments;
  private type Return<X,Y> = { #ok : X; #err : Y };
  private type CyclesReport = {
    balance : Nat;
    transfer : shared () -> async ();
  };

  // ======================================================================== //
  // Stable Memory                                                            //
  // ======================================================================== //
  private stable var _TICK_       : Nat           = 0;
  private stable var _INIT_       : Bool          = false;
  private stable var _MIN_CYCLES_ : Nat           = 8000000000000;
  private stable var _MAX_CYCLES_ : Nat           = 9000000000000;
  private stable var _registry    : Registry      = Task.Registry.init();
  private stable var _increments  : Increments    = Task.Increments.init();
  private stable var _services    : Principal.Set = Principal.Set.init();
  private stable var _admins      : Principal.Set = Principal.Set.init();

  // ======================================================================== //
  // Public Interface                                                         //
  // ======================================================================== //
  public shared ({caller}) func init() : async Return<(),Text> {
    assert caller == _installer and not _INIT_;
    let _ = _set_admins([Principal.Base.toText(_installer)]);
    _INIT_ := true;
    return #ok();
  };

  public shared ({caller}) func schedule( tasks : [ScheduledTask] ) : async () {
    assert Principal.Set.match(_services, caller) and _INIT_;
    var t_schedule : Schedule = Task.Schedule.init();
    for ( task in tasks.vals() ){ 
      Task.Schedule.schedule_task(t_schedule, task);
      Task.Increments.add(_increments, task.interval, caller);
    };
    Task.Registry.put(_registry, caller, t_schedule);
  };

  public shared ({caller}) func set_cycle_thresholds( min : ?Nat, max : ?Nat ) : async {min:Nat;max:Nat} {
    assert Principal.Set.match(_admins, caller) and _INIT_;
    _MIN_CYCLES_ := Option.get(min, _MIN_CYCLES_);
    _MAX_CYCLES_ := Option.get(max, _MAX_CYCLES_);
    return { min = _MIN_CYCLES_; max = _MAX_CYCLES_};
  };

  public shared query func get_cycle_thresholds() : async {min:Nat;max:Nat} {
    return { min = _MIN_CYCLES_; max = _MAX_CYCLES_};
  };

  public shared ({caller}) func add_service( svc : Text ) : async [Principal] {
    assert Principal.Set.match(_admins, caller) and _INIT_;
    _add_service(svc);
  };

  public shared ({caller}) func remove_service( svc : Text ) : async [Principal] {
    assert Principal.Set.match(_admins, caller) and _INIT_;
    _remove_service(svc);
  };

  public shared ({caller}) func set_services( sa : [Text] ) : async [Principal] {
    assert Principal.Set.match(_admins, caller) and _INIT_;
    _set_services(sa);
  };

  public shared query ({caller}) func services() : async [Principal] {
    Principal.Set.toArray(_services);
  };

  public shared ({caller}) func add_admin( admin : Text ) : async [Principal] {
    assert Principal.Set.match(_admins, caller) and _INIT_;
    _add_admin(admin);
  };

  public shared ({caller}) func remove_admin( admin : Text ) : async [Principal] {
    assert Principal.Set.match(_admins, caller) and _INIT_;
    _remove_admin(admin);
  };

  public shared ({caller}) func set_admins( ta : [Text] ) : async [Principal] {
    assert Principal.Set.match(_admins, caller) and _INIT_;
    _set_admins(ta);
  };

  public shared query ({caller}) func admins() : async [Principal] {
    Principal.Set.toArray(_admins);
  }; 

  // ======================================================================== //
  // Cycles Management Interface                                              //
  // ======================================================================== //
  //
  public query func availableCycles() : async Nat { Cycles.balance() };

  public shared func acceptCycles() : async () {
    let available = Cycles.available();
    let accepted = Cycles.accept(available);
    assert accepted == available;
  };

  public shared ({caller}) func report_balance( report : CyclesReport ) : () {
    assert Principal.Set.match(_services, caller) and _INIT_;
    if ( report.balance < _MIN_CYCLES_ ){
      let balance : Nat = Cycles.balance();
      let topup : Nat = _MAX_CYCLES_ - report.balance;
      if ( balance > (topup + 1000000000000) ){
        Cycles.add(topup);
        await report.transfer();
      };
    };
  }; 

  // ======================================================================== //
  // System Methods                                                           //
  // ======================================================================== //
  //
  system func heartbeat() : async () {
    if _INIT_ {
      _TICK_ += 1;
      for ( interval in Task.Increments.interval(_increments) ){
        if ( Nat.rem(_TICK_, interval) == 0 ){
          for ( service in Task.Increments.services_by_interval(_increments, interval) ){
            for ( task in Task.Registry.tasks_by_svc_interval(_registry, service, interval) ){ task() };
        }}};
      if ( _TICK_ == 155520 ){ _TICK_ := 0 };
    };
  };

  // ======================================================================== //
  // Private Functions                                                        //
  // ======================================================================== //
  //
  // Add, remove, and get service canister addresses
  //
  func _add_service( t : Text ) : [Principal] {
    _services := Principal.Set.insert(_services, Principal.Base.fromText(t));
    Principal.Set.toArray(_services);
  };
  func _remove_service( t : Text ) : [Principal] {
    _services := Principal.Set.delete(_services, Principal.Base.fromText(t));
    Principal.Set.toArray(_services);  
  };

  func _set_services( ta : [Text] ) : [Principal] {
    _services := Principal.Set.fromArray(Array.map<Text,Principal>(ta, Principal.Base.fromText));
    Principal.Set.toArray(_services);
  };
  //
  // Update, modify, or get a list of admin principals
  //
  func _add_admin( t : Text ) : [Principal] {
    _admins := Principal.Set.insert(_admins, Principal.Base.fromText(t));
    Principal.Set.toArray(_admins);
  };

  func _remove_admin( t : Text ) : [Principal] {
    _admins := Principal.Set.delete(_admins, Principal.Base.fromText(t));
    Principal.Set.toArray(_admins);
  };

  func _set_admins( ta : [Text] ) : [Principal] {
    _admins := Principal.Set.fromArray(Array.map<Text,Principal>(ta, Principal.Base.fromText));
    Principal.Set.toArray(_admins);
  };

};