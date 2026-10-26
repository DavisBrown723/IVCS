params ["_entityID", "_waypointID", ["_generation", -1]];

private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
if (isNil "_entity") exitWith {};
private _waypoint = [_entity, _waypointID] call IVCS_VirtualSpace_getEntityWaypoint;
if (isNil "_waypoint" || { _generation >= 0 && { _generation != (_waypoint get "nativeGeneration") } }) exitWith {};
private _ignore = _entity get "ignoreWpCallback";
_entity set ["ignoreWpCallback", ""];
if (_waypointID == _ignore) exitWith {};
if ((_entity get "combatID") != "" && {(_entity get "vehiclesInCommandOf") findIf {private _v=[_x] call IVCS_VirtualSpace_getEntity; (_v get "vehicleType")=="helicopter"} == -1}) exitWith {
    (_entity get "combatWaypointCompletions") pushBackUnique _waypointID;
};

if ((_entity get "vehicleType")=="helicopter") then {[_entity,_waypoint] call IVCS_VirtualSpace_onWaypointStarted};
private _type = _waypoint get "type";
if (_type == "CYCLE") exitWith {};

private _minIndex = _entity get "minWaypointIndex";
// Advance the cycle cursor before callbacks can suspend the task.
if (_minIndex != -1) then {
    private _index = _entity get "currentWaypointIndex";
    _entity set ["currentWaypointIndex", if (_index == (_entity get "maxWaypointIndex")) then { _minIndex } else { _index + 1 }];
};
[_waypoint] call IVCS_VirtualSpace_resetEntityWaypoint;
{ [_entity, _waypoint] call (compile _x); } forEach (_waypoint get "statements");
{
    _x params ["_arguments", "_code"];
    [_entity, _waypoint, _arguments] call _code;
} forEach (_waypoint get "callbacks");

// A completion callback can switch tasks and detach this waypoint.
if (isNil { _waypoint get "entity" }) exitWith {
    if (_minIndex == -1) then { [_entity, _waypoint] call IVCS_VirtualSpace_entityRemoveWaypoint; };
};
if (_minIndex == -1) then {
    // Removal maintains the current index as the next surviving slot.
    [_entity, _waypoint] call IVCS_VirtualSpace_entityRemoveWaypoint;
};

if (_type == "LAND" && { !(_entity get "active") } && { (_entity get "waypoints") isEqualTo [] }) then {
    {
        private _vehicle = [_x] call IVCS_VirtualSpace_getEntity;
        _vehicle set ["engineOn", (_waypoint getOrDefault ["landingType", "LAND"]) != "LAND"];
        private _position = +(_vehicle get "position");
        _position set [2, 0.2];
        [_vehicle, _position] call IVCS_VirtualSpace_setEntityPosition;
    } forEach (_entity get "vehiclesInCommandOf");

    private _position = +(_entity get "position");
    _position set [2, 0.2];
    [_entity, _position] call IVCS_VirtualSpace_setEntityPosition;
};
