params ["_entity", "_deltaTime"];

private _active = _entity getvariable "active";
if (_active) then {
    private _vehicleObject = _entity getvariable "object";

    private _newEntityPos = getpos _vehicleObject;
    _entity setvariable ["position", _newEntityPos];

    private _debug = IVCS_VirtualSpace_Controller getvariable "debug";
    if (_debug) then {
        private _debugMarker = _entity getvariable "debugMarker";
        _debugMarker setMarkerAlpha 0.75;
    };
};