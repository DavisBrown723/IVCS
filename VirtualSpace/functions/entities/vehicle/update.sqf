params ["_entity", "_deltaTime"];

private _active = _entity getvariable "active";
if (_active) then {
    private _vehicleObject = _entity getvariable "object";

    private _newEntityPos = getpos _vehicleObject;
    [_entity, _newEntityPos] call IVCS_VirtualSpace_setEntityPosition;

    private _debug = IVCS_VirtualSpace_Controller getvariable "debug";
    if (_debug) then {
        private _entityPos = _entity getvariable "position";
        private _debugMarker = _entity getvariable "debugMarker";
        _debugMarker setMarkerPos _entityPos;
    };
} else {
    private _commandingEntityID = _entity getvariable "commandingEntity";
    if (_commandingEntityID != "") then {
        private _commandingEntity = [_commandingEntityID] call IVCS_VirtualSpace_getEntity;
        private _commandingEntityPos = _commandingEntity getvariable "position";

        [_entity, _commandingEntityPos] call IVCS_VirtualSpace_setEntityPosition;

        private _debug = IVCS_VirtualSpace_Controller getvariable "debug";
        if (_debug) then {
            private _debugMarker = _entity getvariable "debugMarker";
            _debugMarker setMarkerPos _commandingEntityPos;
        };
    };
};