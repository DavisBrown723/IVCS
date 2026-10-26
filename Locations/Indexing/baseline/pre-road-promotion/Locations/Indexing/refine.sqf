// Internal stage. Raw clusters carry member indices into the shared classified array.
params ["_locations", "_points", "_settings"];
private _options = _settings getOrDefault ["compounds", createHashMap];
private _supportRules = [
    _settings getOrDefault ["militarySupport", createHashMap],
    _settings getOrDefault ["fuelSupport", createHashMap],
    _settings getOrDefault ["portSupport", createHashMap]
];
private _order = [];
{ _order pushBack [-(_x get "objectCount"), _x get "id", _forEachIndex]; } forEach _locations;
_order sort true;
private _consumed = createHashMap;
private _combined = createHashMap;
private _membersOf = {
    params ["_index"];
    if (_index in _combined) exitWith { (_combined get _index) select 0 };
    (_locations select _index) get "_members"
};
private _componentsOf = {
    params ["_index"];
    if (_index in _combined) exitWith { (_combined get _index) select 1 };
    private _location = _locations select _index;
    [[_location get "id", _location get "type", _location get "objectCount"]]
};
private _merge = {
    params ["_rootIndex", "_childIndex"];
    private _members = +([_rootIndex] call _membersOf);
    { _members pushBackUnique _x; } forEach ([_childIndex] call _membersOf);
    private _components = +([_rootIndex] call _componentsOf);
    { _components pushBackUnique _x; } forEach ([_childIndex] call _componentsOf);
    _members sort true;
    _components sort true;
    _combined set [_rootIndex, [_members, _components]];
    _consumed set [_childIndex, true];
};
// Always measure against the original primary core. A merged child must fit in full.
private _distances = {
    params ["_rootIndex", "_childIndex", "_limit"];
    private _core = (_locations select _rootIndex) get "_members";
    private _originalChild = (_locations select _childIndex) get "_members";
    private _nearest = 1e10;
    private _furthest = 0;
    {
        private _member = _x;
        private _pos = (_points select _member) select 0;
        private _distance = 1e10;
        { _distance = _distance min (_pos distance2D ((_points select _x) select 0)); } forEach _core;
        if (_member in _originalChild) then { _nearest = _nearest min _distance; };
        _furthest = _furthest max _distance;
        if (_furthest > _limit) exitWith {};
    } forEach ([_childIndex] call _membersOf);
    [_nearest, _furthest]
};
// Dual-tag structures can seed both categories. Collapse a fully contained base
// before support ownership so an airfield does not export a duplicate military site.
{
    private _airfieldIndex = _forEachIndex;
    if ((_x get "type") == "airfield") then {
        private _airfieldCore = _x get "_members";
        {
            private _baseIndex = _forEachIndex;
            if ((_x get "type") == "base" && {!(_baseIndex in _consumed)} && {((_x get "_members") findIf { !(_x in _airfieldCore) }) == -1}) then {
                [_airfieldIndex, _baseIndex] call _merge;
            };
        } forEach _locations;
    };
} forEach _locations;
// Support rules apply to valid sites without generic dominance thresholds.
// The closest original eligible core owns each support site; ID breaks ties.
{
    private _support = _x;
    if (_support getOrDefault ["enabled", false]) then {
        {
            private _childIndex = _forEachIndex;
            if (!(_childIndex in _consumed) && {(_x get "type") in (_support get "secondaryTypes")} && {(_x get "objectCount") <= (_support get "maximumSecondaryObjects")}) then {
                private _candidates = [];
                {
                    private _rootIndex = _forEachIndex;
                    if (_rootIndex != _childIndex && {!(_rootIndex in _consumed)} && {(_x get "type") in (_support getOrDefault ["primaryTypes", ["base"]])}) then {
                        private _limit = _support get "maximumMemberDistance";
                        ([_rootIndex, _childIndex, _limit] call _distances) params ["_near", "_far"];
                        if (_near <= (_support get "linkDistance") && {_far <= _limit}) then {
                            _candidates pushBack [_near, _x get "id", _rootIndex];
                        };
                    };
                } forEach _locations;
                if !(_candidates isEqualTo []) then {
                    _candidates sort true;
                    [(_candidates select 0) select 2, _childIndex] call _merge;
                };
            };
        } forEach _locations;
    };
} forEach _supportRules;
if (_options getOrDefault ["enabled", false]) then {
    {
        private _rootIndex = _x select 2;
        private _root = _locations select _rootIndex;
        private _core = _root get "_members";
        if (!(_rootIndex in _consumed) && {(_root get "type") in (_options get "primaryTypes")} && {count _core >= (_options get "minimumPrimaryObjects")}) then {
            {
                private _childIndex = _forEachIndex;
                private _child = _x;
                private _childMembers = [_childIndex] call _membersOf;
                if (_childIndex != _rootIndex && {!(_childIndex in _consumed)} && {(_child get "type") != (_root get "type")} && {(_child get "type") in (_options get "secondaryTypes")} && {count _childMembers <= (_options get "maximumSecondaryObjects")} && {count _childMembers <= count _core * (_options get "maximumSecondaryRatio")}) then {
                    private _link = _options get "linkDistance";
                    private _limit = _options get "maximumMemberDistance";
                    if ((_child get "position") distance2D (_root get "position") <= (_child get "size") + (_root get "size") + _link) then {
                        ([_rootIndex, _childIndex, _limit] call _distances) params ["_near", "_far"];
                        if (_near <= _link && {_far <= _limit}) then { [_rootIndex, _childIndex] call _merge; };
                    };
                };
            } forEach _locations;
        };
    } forEach _order;
};
private _roles = _settings getOrDefault ["secondaryRoles", []];
private _rolePoints = _points select { ((_x select 1) findIf { _x in _roles }) >= 0 };
private _footprint = {
    params ["_members", "_padding"];
    private _center = [0,0,0];
    { _center = _center vectorAdd ((_points select _x) select 0); } forEach _members;
    _center = _center vectorMultiply (1 / count _members);
    private _radius = 0;
    { _radius = _radius max (_center distance2D ((_points select _x) select 0)); } forEach _members;
    [_center, _radius + _padding]
};
private _result = [];
{
    private _index = _forEachIndex;
    private _location = _x;
    if !(_index in _consumed) then {
        private _members = +([_index] call _membersOf);
        if (count _members >= (_location get "_minimum")) then {
            private _coreMembers = +_members;
            private _coreTypes = [];
            { { _coreTypes pushBackUnique _x; } forEach ((_points select _x) select 1); } forEach _coreMembers;
            // Preserve airfield-scale clustering and source IDs, but expose military identity.
            // This also applies when an airfield is absorbed into another compound.
            if ("airfield" in _coreTypes) then {
                _location set ["type", "base"];
                _coreTypes pushBackUnique "base";
            };
            ([_coreMembers, _location get "_padding"] call _footprint) params ["_center", "_radius"];
            // Attach role evidence inside the original footprint only, without growing a chain.
            // Overlapping sites may share evidence, as they already do for multi-tag objects.
            {
                private _allowedRoles = (_x select 1) arrayIntersect _roles;
                if !("base" in _coreTypes) then { _allowedRoles = _allowedRoles - ["radar"]; };
                if (!(_allowedRoles isEqualTo []) && {(_x select 0) distance2D _center <= _radius}) then {
                    _members pushBackUnique (_x select 3);
                };
            } forEach _rolePoints;
            _members sort true;
            private _models = createHashMap;
            private _types = createHashMap;
            private _militaryBuildings = [];
            private _militaryCounts = createHashMap;
            private _roleRemaps = (_settings getOrDefault ["secondaryTypeRemaps", createHashMap]) getOrDefault [_location get "type", createHashMap];
            {
                private _member = _x;
                private _point = _points select _member;
                private _model = _point select 2;
                _models set [_model, (_models getOrDefault [_model, 0]) + 1];
                // Annotation of a runway does not absorb its whole airfield category.
                private _tags = if (_member in _coreMembers) then { +(_point select 1) } else { (_point select 1) arrayIntersect _roles };
                if ("airfield" in _tags) then {
                    _tags = _tags - ["airfield"];
                    _tags pushBackUnique "base";
                    _tags pushBackUnique "air";
                };
                if !("base" in _coreTypes) then { _tags = _tags - ["radar"]; };
                // Remap after merging and role annotation; preserve source components.
                // Deduplicate per object when it already supplies the replacement role.
                private _mappedTags = [];
                { _mappedTags pushBackUnique (_roleRemaps getOrDefault [_x, _x]); } forEach _tags;
                { _types set [_x, (_types getOrDefault [_x, 0]) + 1]; } forEach _mappedTags;
                // The final member role controls military use: industrial housing is excluded.
                // Keep structures and their map positions, not engine references or garrison slots.
                if ("base" in _mappedTags) then {
                    {
                        _militaryBuildings pushBack [_x, _point select 5, _model, +(_point select 0)];
                        _militaryCounts set [_x, (_militaryCounts getOrDefault [_x, 0]) + 1];
                    } forEach (_point select 4);
                };
            } forEach _members;
            ([_members, _location get "_padding"] call _footprint) params ["_finalCenter", "_finalRadius"];
            _location set ["position", _finalCenter];
            _location set ["size", _finalRadius];
            _location set ["objectCount", count _members];
            private _modelKeys = keys _models;
            _modelKeys sort true;
            _location set ["models", _modelKeys apply { [_x, _models get _x] }];
            private _typeKeys = keys _types;
            _typeKeys sort true;
            _location set ["types", _typeKeys];
            _location set ["typeCounts", _typeKeys apply { [_x, _types get _x] }];
            if ("base" in _typeKeys) then {
                _location set ["militaryBuildings", _militaryBuildings];
                _location set ["militaryBuildingCounts", [
                    ["barracks", _militaryCounts getOrDefault ["barracks", 0]],
                    ["fortification", _militaryCounts getOrDefault ["fortification", 0]]
                ]];
            };
            private _components = [_index] call _componentsOf;
            if (count _components > 1) then { _location set ["components", _components]; };
            _location deleteAt "_members";
            _location deleteAt "_padding";
            _location deleteAt "_minimum";
            _result pushBack _location;
        };
    };
} forEach _locations;
_result
