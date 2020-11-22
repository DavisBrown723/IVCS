params ["_entity"];

private _units = _entity getvariable "units";

// create group

private _side = _entity getvariable "side";
private _sideObject = [_side] call IVCS_Common_sideStringToObject;
private _group = createGroup [_sideObject, true];

_entity setvariable ["group", _group];

// spawn units

private _entityID = _entity getvariable "id";
private _position = _entity getvariable "position";

{
    private _class = _x getvariable "class";
    private _damage = _x getvariable "damage";
    private _vehicleAssignment = _x getvariable "vehicleAssignment";
    private _weapons = _x getvariable "weapons";

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
        if !(_vehicleEntity getvariable "active") then {
            private _spawnFunc = missionnamespace getvariable (_vehicleEntity getvariable "spawn");
            [_vehicleEntity] call _spawnFunc;
        };
        private _vehicleObject = _vehicleEntity getvariable "object";
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
    _unit setvariable ["unitID", _x getvariable "id"];

    _unit addEventHandler ["Killed", IVCS_VirtualSpace_onUnitKilled];

    _x setvariable ["object", _unit];
} foreach _units;

// restore waypoints

private _waypoints = _entity getvariable "waypoints";
private _currentWaypoint = _entity getvariable "currentWaypoint";

{
    [_entity, _group, _x] call IVCS_VirtualSpace_entityWaypointToWaypoint;
} foreach _waypoints;

if (_currentWaypoint != -1) then {
    // setting current waypoint sets previous waypoint as completed
    // so lets temporarily ignore its callbacks to counter this
    // since we havent set current waypoint yet, wp_0 will always be the one we ignore
    if (_currentWaypoint > 0) then {
        _entity setvariable ["ignoreWpCallback", "wp_0"];
    };

    _group setCurrentWaypoint [_group, _currentWaypoint + 1];
};

private _debug = IVCS_VirtualSpace_Controller getvariable "debug";
if (_debug) then {
    private _debugMarker = _entity getvariable "debugMarker";
    _debugMarker setMarkerAlpha 0.75;
};

_entity setvariable ["active", true];