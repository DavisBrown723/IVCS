params ["_entity"];

private _active = _entity get "active";
if (!_active || { _entity get "simulationTransition" }) exitWith {};
[_entity] call IVCS_Ammo_cancelGroup;
[_entity,false] call IVCS_Combat_clearAirDefense;
_entity set ["simulationTransition", true];
if ((_entity get "combatID") != "") then {
    (((IVCS_VirtualSpace_Controller get "combat") get "engagements") get (_entity get "combatID")) set ["mode", "despawning"];
};

[_entity, false] call IVCS_VirtualSpace_setEntityActive;
[_entity, getPos leader (_entity get "group")] call IVCS_VirtualSpace_setEntityPosition;

private _units = _entity get "units";
private _group = _entity get "group";
// Freeze the snapshot across scheduled frames before reading any unit state.
{ (_x get "object") allowDamage false; } forEach _units;
private _deadUnits = [];

// delete units

{
    private _object = _x get "object";
    if (!alive _object) then { _deadUnits pushBack _x; };

    private _inventory = [_object] call IVCS_Common_getUnitInventoryInfo;
    _inventory params ["_unitWeapons", "_magazineCargo"];

    _x set ["object", objnull];
    _x set ["weapons", _unitWeapons];
    _x set ["magazineCargo", _magazineCargo];
    _x set ["damage", damage _object];
    private _nativeDamage = getAllHitPointsDamage _object;
    private _hitpoints = [];
    { _hitpoints pushBack [_x, (_nativeDamage select 2) select _forEachIndex]; } forEach (_nativeDamage select 0);
    _x set ["hitpoints", _hitpoints];
    [_x] call IVCS_Combat_getHitpointLayout;
    _x set ["equipment", [vest _object, headgear _object]];

    deletevehicle _object;
} foreach _units;

deleteGroup _group;
_entity set ["group", grpNull];
_entity set ["movementStopped", false];
// Killed handlers may still be queued when capture starts. Never let a captured
// corpse re-enter the virtual firing roster or respawn before that handler runs.
{ [_entity, _x] call IVCS_VirtualSpace_Group_RemoveUnit; } forEach _deadUnits;
_entity set ["simulationTransition", false];
if ((_entity get "combatID") != "") then { [_entity] call IVCS_Combat_onDespawn; };

private _debug = IVCS_VirtualSpace_Controller get "debug";
if (_debug) then {
    private _debugMarker = _entity get "debugMarker";
    _debugMarker setMarkerAlpha 0.35;
};

private _currentWaypoint = [_entity] call IVCS_VirtualSpace_getEntityCurrentWaypoint;
if (!isnil "_currentWaypoint") then {
    [_currentWaypoint] call IVCS_VirtualSpace_resetEntityWaypoint;
};

// despawn any connected vehicles

private _vehiclesInCommandOf = _entity get "vehiclesInCommandOf";
private _vehiclesInCargoOf = _entity get "vehiclesInCargoOf";
{
    private _vehicleEntity = [_x] call IVCS_VirtualSpace_getEntity;
    private _vehicleEntityActive = _vehicleEntity get "active";
    if (_vehicleEntityActive) then {
        private _despawnFunc = missionnamespace getvariable (_vehicleEntity get "despawn");
        [_vehicleEntity] call _despawnFunc;
    };
} foreach (_vehiclesInCommandOf + _vehiclesInCargoOf);
