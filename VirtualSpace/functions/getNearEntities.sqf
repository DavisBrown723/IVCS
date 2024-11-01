params [
    "_position",
    "_radius",
    ["_filters", []],
    ["_checkVisiblity", false]
];

_filters params [
    ["_type", "ALL"],
    ["_side",""],
    ["_faction", ""]
];

private _entitiesSpacialGrid = IVCS_VirtualSpace_Controller get "entitiesSpacialGrid";
private _entitiesInRange = [_entitiesSpacialGrid, _position, _radius, false] call IVCS_SpacialGrid_findInRange;
if (_checkVisiblity) then {
    _entitiesInRange = _entitiesInRange select {
        private _entityPosition = _x get "position";
        
        !(terrainIntersect [_position, [_entityPosition select 0, _entityPosition select 1, (_entityPosition select 2) + 2]])
    };
};

// private _entities = IVCS_VirtualSpace_Controller get "entities";
// private _allEntities = _entities get "ALL";

// private _inRange = (keys _allEntities) apply { _allEntities get _x } select {
//     if (!isnil "_x") then {
//         private _entityPosition = _x get "position";

//         _entityPosition distance _position <= _radius &&
//         (
//             !_checkVisiblity ||
//             { !(terrainIntersect [_position, [_entityPosition select 0, _entityPosition select 1, (_entityPosition select 2) + 2]]) }
//         )
//     };
// };

private _filter = "true";
if (_type != "ALL") then {
    _filter = _filter + format [" && { (_x get 'entityType') == _type }"];
};
if !(_side isequalto "") then {
    if (_side isequaltype []) then {
        _filter = _filter + format [" && { (_x get 'side') in _side }"];
    } else {
        _filter = _filter + format [" && { (_x get 'side') == _side }"];
    };
};
if !(_faction isequalto "") then {
    if (_faction isequaltype []) then {
        _filter = _filter + format [" && { (_x get 'faction') in _faction }"];
    } else {
        _filter = _filter + format [" && { (_x get 'faction') == _faction }"];
    };
};

_entitiesInRange = _entitiesInRange select (compile _filter);

_entitiesInRange
