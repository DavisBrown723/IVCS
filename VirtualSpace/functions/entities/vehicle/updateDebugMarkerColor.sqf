params ["_entity"];

private _debugMarker = _entity get "debugMarker";
if (_debugMarker != "") then {
    private _commandingEntityID = _entity get "commandingEntity";
    private _entitiesInCargo = _entity get "entitiesInCargo";

    if (_commandingEntityID != "") then {
        private _commandingEntity = [_commandingEntityID] call IVCS_VirtualSpace_getEntity;
        private _commandingEntitySide = _commandingEntity get "side";

        private _entitySideColor = [_commandingEntitySide] call IVCS_Common_sideStringToColor;
        _debugMarker setMarkerColor _entitySideColor;
    } else {
        if !(_entitiesInCargo isequalto []) then {
            private _cargoEntityID = _entitiesInCargo select 0;
            private _cargoEntity = [_cargoEntityID] call IVCS_VirtualSpace_getEntity;
            private _cargoEntitySide = _cargoEntity get "side";

            private _entitySideColor = [_cargoEntitySide] call IVCS_Common_sideStringToColor;
            _debugMarker setMarkerColor _entitySideColor;
        } else {
            private _entitySideColor = ["NONE"] call IVCS_Common_sideStringToColor;
            _debugMarker setMarkerColor _entitySideColor;
        };
    };
};