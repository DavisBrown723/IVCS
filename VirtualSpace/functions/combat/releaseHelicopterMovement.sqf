// Release only the temporary orders owned by combat flight; keep the original route and task.
params ["_crew","_vehicle"];
[_vehicle,false] call IVCS_Combat_setHelicopterPassHold;
if !(_vehicle get "airMovementOverride") exitWith {};
_vehicle set ["airMovementOverride",false];
_vehicle set ["nativeAirDestination",[]];
private _native=_vehicle get "active";
if (_native && {!isNull (_vehicle get "nativeAirTarget")}) then {
    {_x doTarget objNull} forEach units (_crew getOrDefault ["group",grpNull]);
};
_vehicle set ["nativeAirTarget",objNull];
private _wp=if (count _crew>0) then {[_crew] call IVCS_VirtualSpace_getEntityCurrentWaypoint} else {nil};
if (!isNil "_wp") then {
    [_wp] call IVCS_VirtualSpace_resetEntityWaypoint;
    if (_native) then {(_vehicle get "object") doMove (_wp get "position")};
} else {
    if (_native) then {private _object=_vehicle get "object";_object doMove getPos _object};
};
private _task=_crew get "activeTask";
if (!isNil "_task" && {(_task get "name")=="LAND"}) then {
    private _context=_task get "context";
    _context set ["approachObject",objNull];_context set ["landingObject",objNull];
};
