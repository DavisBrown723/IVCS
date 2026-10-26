// Release native holds and helicopter landing orders for the current MOVE.
params ["_entity"];
if !(_entity get "active") exitWith {};
private _waypoint = [_entity] call IVCS_VirtualSpace_getEntityCurrentWaypoint;
if (isNil "_waypoint" || { (_waypoint get "type") != "MOVE" }) exitWith {};
{
    private _vehicle = [_x] call IVCS_VirtualSpace_getEntity;
    if (!isNil "_vehicle" && { _vehicle get "active" } && { (_vehicle get "vehicleType") == "helicopter" }) then {
        private _object = _vehicle get "object";
        _object land "NONE";
        _object engineOn true;
        _object doMove (_waypoint get "position");
    };
} forEach (_entity get "vehiclesInCommandOf");
