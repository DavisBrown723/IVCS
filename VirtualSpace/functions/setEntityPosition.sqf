params ["_entity","_position",["_moveObjects", false]];

private _oldPosition = _entity get "position";
_entity set ["position", _position];

private _entitiesSpacialGrid = IVCS_VirtualSpace_Controller get "entitiesSpacialGrid";
[_entitiesSpacialGrid, _oldPosition, _position, _entity] call IVCS_SpacialGrid_move;

if (_moveObjects) then {
    private _active = _entity get "active";
    if (_active) then {
        private _entityType = _entity get "entityType";
        switch (_entityType) do {
            case "group": {
                private _units = _entity get "units";
                {
                    private _object = _x get "object";
                    _object setPosATL _position;
                } foreach _units;
            };
            case "vehicle": {
                private _object = _entity get "object";
                _object setPosATL _position;
            };
            case "uav": {

            };
        };
    };
};