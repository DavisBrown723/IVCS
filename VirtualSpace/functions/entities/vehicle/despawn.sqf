params ["_entity"];

private _vehicleObject = _entity getvariable "object";

private _hitpoints = _entity getvariable "hitpoints";
{
    private _hitpoint = _x select 0;

    private _hitpointDamage = _vehicleObject getHitPointDamage _hitpoint;
    _x set [1, _hitpointDamage];
} foreach _hitpoints;

deletevehicle _vehicleObject;

_entity setvariable ["object", objNull];

private _debug = IVCS_VirtualSpace_Controller getvariable "debug";
if (_debug) then {
    private _debugMarker = _entity getvariable "debugMarker";
    _debugMarker setMarkerAlpha 0.35;
};

_entity setvariable ["active", false];