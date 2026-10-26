params ["_entity", "_request"];
if !(_request get "native") exitWith {};
private _object = (_request get "recipient") get "object";
if (isNull _object || { !local _object } || { !alive _object }) exitWith {};
_object forceWalk (_request get "oldForcedWalk");
if ((_request get "phase") == "collecting") then { _object playActionNow "Stop"; };
if ((_request get "oldCommand") == "STOP") then {
    doStop _object;
} else {
    if ((_request get "oldCommand") == "MOVE") then { _object doMove (_request get "oldDestination"); } else {
        // doFollow also releases a leader back to its group's waypoint orders.
        _object doFollow leader group _object;
    };
};
