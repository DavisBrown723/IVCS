params ["_entity"];

private _active = _entity get "active";
if (_active) exitwith {};

private _units = _entity get "units";

// create group

private _side = _entity get "side";
private _sideObject = [_side] call IVCS_Common_sideStringToObject;
private _group = createGroup [_sideObject, true];

_entity set ["group", _group];

// spawn units

private _entityID = _entity get "id";
private _position = _entity get "position";

{
    private _class = _x get "class";
    private _damage = _x get "damage";
    private _vehicleAssignment = _x get "vehicleAssignment";
    private _weapons = _x get "weapons";

    private _unit = _group createUnit [_class, _position, [], 0, "NONE"];
    _unit setpos (formationPosition _unit);
    _unit setdamage _damage;

    removeAllWeapons _unit;
    {_unit removeMagazine _x} forEach magazines _unit;

    {
        _x params ["_weaponClass","_magazines"];

        {
            _x params ["_magazineClass","_ammoCount"];
  
            _unit addMagazine [_magazineClass, _ammoCount];
        } foreach _magazines;

        _unit addWeapon _weaponClass;
    } foreach _weapons;

    if !(_vehicleAssignment isequalto []) then {
        _vehicleAssignment params ["_vehicleEntityID","_seat"];
        private _seatPath = _seat select 0;
        
        private _vehicleEntity = [_vehicleEntityID] call IVCS_VirtualSpace_getEntity;
        if !(_vehicleEntity get "active") then {
            private _spawnFunc = missionnamespace getvariable (_vehicleEntity get "spawn");
            [_vehicleEntity] call _spawnFunc;
        };
        private _vehicleObject = _vehicleEntity get "object";
        switch (true) do {
            case (_seatPath isequalto -1): {
                _unit moveInDriver _vehicleObject;
            };
            case (_seatPath isequaltype 0): {
                _unit assignAsCargoIndex [_vehicleObject, _seatPath];
                _unit moveInCargo _vehicleObject;
            };
            case (_seatPath isequaltype []): {
                _unit moveInTurret [_vehicleObject, _seatPath];
                _unit assignAsTurret [_vehicleObject, _seatPath];
            };
        };
    };

    _unit setvariable ["entityID", _entityID];
    _unit setvariable ["unitID", _x get "id"];

    _unit addEventHandler ["Killed", IVCS_VirtualSpace_onUnitKilled];

    _x set ["object", _unit];
} foreach _units;

// restore waypoints

private _waypoints = _entity get "waypoints";
private _currentWaypointIndex = _entity get "currentWaypointIndex";

// newly created groups in arma automatically have a waypoint created at their starting position
// delete it so it doesn't interfere with our indexes
deleteWaypoint [_group, 0];

{
    [_entity, _group, _x] call IVCS_VirtualSpace_entityWaypointToWaypoint;

    [_x] call IVCS_VirtualSpace_resetEntityWaypoint;
} foreach _waypoints;

if (_currentWaypointIndex > 0) then {
    // setting current waypoint sets previous waypoint as completed
    // so lets temporarily ignore its callback to counter this
    // since we havent set current waypoint yet, wp_0 will always be the one we ignore

    _entity set ["ignoreWpCallback", "wp_0"];

    _group setCurrentWaypoint [_group, _currentWaypointIndex];
};

private _debug = IVCS_VirtualSpace_Controller get "debug";
if (_debug) then {
    private _debugMarker = _entity get "debugMarker";
    _debugMarker setMarkerAlpha 0.75;
};

private _any = _waypoints findif { (_x get "pathGenerationRequestID") != "" };
if (_any != -1) then {
    hint "WE GOT ONE";
};

_entity set ["active", true];