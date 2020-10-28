params ["_entity"];

private _position = _entity getvariable "position";
private _entityID = _entity getvariable "id";

private _vehicleClass = _entity getvariable "class";
private _vehicleObject = createVehicle [_vehicleClass, _position];
_vehicleObject setvariable ["entityID", _entityID];

_entity setvariable ["object", _vehicleObject];

private _debug = IVCS_VirtualSpace_Controller getvariable "debug";
if (_debug) then {
    private _debugMarker = _entity getvariable "debugMarker";
    _debugMarker setMarkerAlpha 0.75;
};