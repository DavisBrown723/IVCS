params ["_entity"];

// Claim spawning and flush recorded virtual time without scheduled-script interleaving.
private _ready = false;
isNil {
    if (_entity get "active" || { _entity get "simulationTransition" }) exitWith {};
    private _combatID = _entity get "combatID";
    if (_combatID != "") then { [_entity] call IVCS_Combat_flushPending; };
    // Preserve ordinary empty-group spawning; only a flush-deleted combatant is rejected.
    if (_combatID != "" && { (_entity get "units") isEqualTo [] }) exitWith {};
    [_entity] call IVCS_Ammo_cancelGroup;
    _entity set ["simulationTransition",true];
    _combatID = _entity get "combatID";
    if (_combatID != "") then {
        (((IVCS_VirtualSpace_Controller get "combat") get "engagements") get _combatID) set ["mode","spawning"];
    };
    _ready = true;
};
if (!_ready) exitWith {};
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
    private _equipment = _x get "equipment";
    if (vest _unit != (_equipment select 0)) then {
        removeVest _unit;
        if ((_equipment select 0) != "") then { _unit addVest (_equipment select 0); };
    };
    if (headgear _unit != (_equipment select 1)) then {
        removeHeadgear _unit;
        if ((_equipment select 1) != "") then { _unit addHeadgear (_equipment select 1); };
    };
    _unit setDamage [_damage, false];
    // Restore aggregate regions before their anatomical leaves.
    private _profile = [_class] call IVCS_Combat_getUnitProfile;
    private _orderedDamage = +(_x get "hitpoints");
    _orderedDamage = _orderedDamage apply {
        private _info = (_profile get "hitpoints") getOrDefault [toLower (_x select 0), [1, 1, "torso", "0"]];
        [if ((_info select 3) in ["", "0"]) then { 1 } else { 0 }, _x select 0, _x select 1]
    };
    _orderedDamage sort true;
    { _unit setHitPointDamage [_x select 1, _x select 2, false]; } forEach _orderedDamage;
    // Keep an incompletely restored roster from taking untracked native damage.
    _unit allowDamage false;

    removeAllWeapons _unit;
    {_unit removeMagazine _x} forEach magazines _unit;

    private _spareMagazines = [];
    {
        _x params ["_weaponClass","_magazines"];

        // Load one magazine before adding reserves. A launcher's loaded rocket
        // must not temporarily require an extra slot in an already full backpack.
        private _loadedIndices = [];
        {
            private _compatible = _x select 1;
            private _index = _magazines findIf { (_x select 1) > 0 && { _compatible getOrDefault [_x select 0,false] } };
            if (_index != -1 && { !(_index in _loadedIndices) }) then {
                private _loaded = _magazines select _index;
                _unit addMagazine [_loaded select 0,_loaded select 1];
                _loadedIndices pushBack _index;
            };
        } forEach (([_weaponClass] call IVCS_Combat_getWeaponProfile) get "attackMuzzles");
        _unit addWeapon _weaponClass;
        {
            _x params ["_magazineClass","_ammoCount"];
            if (!(_forEachIndex in _loadedIndices) && { _ammoCount > 0 }) then { _spareMagazines pushBack [_magazineClass,_ammoCount]; };
        } forEach _magazines;
    } foreach _weapons;
    { _unit addMagazine _x; } forEach _spareMagazines;

    // Restore support ammunition and explosives without making them fireable.
    { if ((_x select 1) > 0) then { _unit addMagazine [_x select 0, _x select 1]; }; } forEach (_x get "magazineCargo");

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
                _unit assignAsDriver _vehicleObject;
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

    _unit addEventHandler ["Killed", IVCS_VirtualSpace_Group_onUnitKilled];

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
    // Native selection completes the first restored waypoint. IDs are global.
    _entity set ["ignoreWpCallback", (_waypoints select 0) get "name"];

    _group setCurrentWaypoint [_group, _currentWaypointIndex];
};

private _debug = IVCS_VirtualSpace_Controller get "debug";
if (_debug) then {
    private _debugMarker = _entity get "debugMarker";
    _debugMarker setMarkerAlpha 0.75;
};

_entity set ["simulationTransition", false];
[_entity, true] call IVCS_VirtualSpace_setEntityActive;
{ (_x get "object") allowDamage true; } forEach _units;
if ((_entity get "combatID") != "") then { [_entity] call IVCS_Combat_onSpawn; } else {
    {
        private _v=[_x] call IVCS_VirtualSpace_getEntity;
        if ((_v get "vehicleType")=="helicopter") then {private _object=_v get "object";_object setDir (_v get "flightHeading");_object setVelocity (_v get "flightVelocity");_v set ["flightRestorePending",false]};
    } forEach (_entity get "vehiclesInCommandOf");
};
