params ["_entity"];

private _vehicleObject = _entity getvariable "object";

deletevehicle _vehicleObject;

_entity setvariable ["object", objNull];

private _debug = IVCS_VirtualSpace_Controller getvariable "debug";
if (_debug) then {
    private _debugMarker = _entity getvariable "debugMarker";
    _debugMarker setMarkerAlpha 0.35;
};