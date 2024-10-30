params ["_entity"];

private _active = _entity get "active";
if (!_active) exitwith {};

// despawn any connected entities first

private _commandingEntityID = _entity get "commandingEntity";
private _entitiesInCargo = _entity get "entitiesInCargo";
{
    private _entity = [_x] call IVCS_VirtualSpace_getEntity;
    private _despawnFunc = missionnamespace getvariable (_entity get "despawn");
    [_entity] call _despawnFunc;
} foreach (_entitiesInCargo + [_commandingEntityID]);

// despawn this entity

private _vehicleObject = _entity get "object";

private _hitpoints = _entity get "hitpoints";
{
    private _hitpoint = _x select 0;

    private _hitpointDamage = _vehicleObject getHitPointDamage _hitpoint;
    _x set [1, _hitpointDamage];
} foreach _hitpoints;

private _pylons = _entity get "pylons";
private _pylonMagazines = getPylonMagazines _vehicleObject;
{
    private _pylon = _pylons select _foreachindex;
    private _pylonName = _pylon select 0;

    private _magazineOnPylon = _x;
    private _magazineAmmo = _vehicleObject ammoOnPylon _pylonName;

    _pylon set [1, _magazineOnPylon];
    _pylon set [2, _magazineAmmo];
} foreach _pylonMagazines;

private _waypoints = _entity get "waypoints";
if (_waypoints isequalto []) then {
    _entity set ["engineOn", isEngineOn _vehicleObject];
};

deletevehicle _vehicleObject;

_entity set ["object", objNull];

private _debug = IVCS_VirtualSpace_Controller get "debug";
if (_debug) then {
    private _debugMarker = _entity get "debugMarker";
    _debugMarker setMarkerAlpha 0.35;
};

_entity set ["active", false];