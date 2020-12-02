params ["_entity","_position",["_moveObjects", false]];

private _oldPosition = _entity getvariable "position";
_entity setvariable ["position", _position];

private _entitiesSpacialGrid = IVCS_VirtualSpace_Controller getvariable "entitiesSpacialGrid";
[_entitiesSpacialGrid, _oldPosition, _position, _entity] call IVCS_SpacialGrid_move;

if (_moveObjects) then {
    private _active = _entity getvariable "active";
    if (_active) then {
        private _entityType = _entity getvariable "entityType";
        switch (_entityType) do {
            case "group": {
                private _units = _entity getvariable "units";
                {
                    private _object = _x getvariable "object";
                    _object setPosATL _position;
                } foreach _units;
            };
            case "vehicle": {
                private _object = _entity getvariable "object";
                _object setPosATL _position;
            };
            case "uav": {

            };
        };
    };
};