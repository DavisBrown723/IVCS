params ["_entity", "_deltaTime"];

private _active = _entity get "active";
if (_active) then {
    private _vehicleObject = _entity get "object";

    private _newEntityPos = getpos _vehicleObject;
    [_entity, _newEntityPos] call IVCS_VirtualSpace_setEntityPosition;

    private _debug = IVCS_VirtualSpace_Controller get "debug";
    if (_debug) then {
        private _entityPos = _entity get "position";
        private _debugMarker = _entity get "debugMarker";
        _debugMarker setMarkerPos _entityPos;
    };
} else {
    private _commandingEntityID = _entity get "commandingEntity";
    if (_commandingEntityID != "") then {
        private _commandingEntity = [_commandingEntityID] call IVCS_VirtualSpace_getEntity;
        private _commandingEntityPos = _commandingEntity get "position";

        [_entity, _commandingEntityPos] call IVCS_VirtualSpace_setEntityPosition;

        private _debug = IVCS_VirtualSpace_Controller get "debug";
        if (_debug) then {
            private _debugMarker = _entity get "debugMarker";
            _debugMarker setMarkerPos _commandingEntityPos;
        };
    };
};