params ["_entity", "_position", ["_moveObjects", false]];

private _oldPosition = _entity get "position";
if (_oldPosition isNotEqualTo _position) then {
    _entity set ["position", _position];
    // Teardown can update metadata after the profile has left the registry.
    if ((_entity get "id") in (IVCS_VirtualSpace_Controller get "entities" get "ALL")) then {
        private _grid = IVCS_VirtualSpace_Controller get "entitiesSpacialGrid";
        [_grid, _oldPosition, _position, _entity] call IVCS_SpacialGrid_move;
    };
};

if (_moveObjects && { _entity get "active" }) then {
    switch (_entity get "entityType") do {
        case "group": {
            { (_x get "object") setPosATL _position; } forEach (_entity get "units");
        };
        case "vehicle";
        case "uav": {
            (_entity get "object") setPosATL _position;
        };
    };
};
