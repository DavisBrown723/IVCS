params ["_position","_radius",["_filters", []]];

_filters params [
    ["_type", "all"],
    ["_side",""],
    ["_faction", ""]
];

private _entities = IVCS_VirtualSpace_Controller getvariable "entities";
private _allEntities = _entities getvariable "all";

private _inRange = [];

{
    private _entityID = _x;
    private _entity = _allEntities getvariable _entityID; 
    if (!isnil "_entity") then {
        private _entityPosition = _entity getvariable "position";
        if (isnil "_entityPosition") then {
            systemchat format ["Bad entity: %1", _entityID];
        };

        if (_entityPosition distance _position <= _radius) then {
            _inRange pushback _entity;
        };
    };
} foreach (allvariables _allEntities);

private _filter = "true";
if (_type != "all") then {
    _filter = _filter + format [" && { (_x getvariable 'entityType') == _type }"];
};
if (_side != "") then {
    _filter = _filter + format [" && { (_x getvariable 'side') == _side }"];
};
if (_faction != "") then {
    _filter = _filter + format [" && { (_x getvariable 'faction') == _faction }"];
};

_inRange select (compile _filter)