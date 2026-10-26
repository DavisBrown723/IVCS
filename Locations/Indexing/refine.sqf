// Consolidate compatible cores, then reassess support against fixed consolidated cores.
params ["_locations", "_points", "_settings"];
private _options = _settings getOrDefault ["compounds", createHashMap];
private _supportRules = [
    _settings getOrDefault ["militarySupport", createHashMap],
    _settings getOrDefault ["fuelSupport", createHashMap],
    _settings getOrDefault ["portSupport", createHashMap]
];
private _footprintOptions = _settings getOrDefault ["footprints", createHashMap];
private _coreFootprints = _locations apply {
    [(_x get "_members") apply { (_points select _x) select 0 }, _x get "_padding", _footprintOptions] call IVCS_Locations_fitFootprint
};
private _coreAreas = _coreFootprints apply {
    private _axes = _x select 2;
    (_axes select 0) * (_axes select 1) * (if ((_x select 0) == "circle") then {pi} else {4})
};
private _isReverseSupport = {
    params ["_rootType", "_childType"];
    (_supportRules findIf {
        (_x getOrDefault ["enabled", false]) &&
        {_childType in (_x getOrDefault ["primaryTypes", ["base"]])} &&
        {_rootType in (_x get "secondaryTypes")}
    }) >= 0
};
private _isTypedSupport = {
    params ["_rootType", "_childType"];
    (_supportRules findIf {
        (_x getOrDefault ["enabled", false]) &&
        {_rootType in (_x getOrDefault ["primaryTypes", ["base"]])} &&
        {_childType in (_x get "secondaryTypes")}
    }) >= 0
};
private _order = [];
{
    _order pushBack [if ((_x get "type") == "airfield") then {0} else {1}, -(_coreAreas select _forEachIndex), _x get "id", _forEachIndex];
} forEach _locations;
_order sort true;
private _consumed = createHashMap;
private _combined = createHashMap;
private _consolidatingCores = false;
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
    if (_consolidatingCores) then {
        private _shape = [_members apply { (_points select _x) select 0 }, (_locations select _rootIndex) get "_padding", _footprintOptions] call IVCS_Locations_fitFootprint;
        _coreFootprints set [_rootIndex, _shape];
        private _axes = _shape select 2;
        _coreAreas set [_rootIndex, (_axes select 0) * (_axes select 1) * (if ((_shape select 0) == "circle") then {pi} else {4})];
    };
};
// Return [eligible, nearest original-member distance]. All geometry uses the
// consolidated core footprint. Member-distance checks use original host objects;
// support never changes core geometry or expands later eligibility.
private _relationship = {
    params ["_rootIndex", "_childIndex", "_link", "_limit"];
    private _shape = _coreFootprints select _rootIndex;
    private _axes = _shape select 2;
    private _bound = if ((_shape select 0) == "circle") then {_axes select 0} else {sqrt ((_axes select 0)^2 + (_axes select 1)^2)};
    private _child = _locations select _childIndex;
    if ((_shape select 1) distance2D (_child get "position") > _bound + (_child get "size") + _link) exitWith {[false, 1e10]};
    private _childMembers = [_childIndex] call _membersOf;
    private _inside = 0;
    private _outside = 0;
    {
        private _gap = [_shape, (_points select _x) select 0] call IVCS_Locations_footprintDistance;
        if (_gap <= 0.01) then { _inside = _inside + 1; };
        _outside = _outside max _gap;
    } forEach _childMembers;
    private _contained = _inside == count _childMembers;
    private _edgeOverlap = _inside > 0 && {_outside <= _link};
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
        if (!_contained && {!_edgeOverlap} && {_furthest > _limit}) exitWith {};
    } forEach _childMembers;
    // Full containment in the consolidated core does not require object proximity.
    // Edge overlap keeps nearest-member proximity and the existing shape margin.
    // Disjoint sites retain the bounded nearby-member relationship.
    [_contained || {_nearest <= _link && {_edgeOverlap || {
        _furthest <= _limit && {(_shape select 0) == "circle" || {_outside <= _link}}
    }}}, _nearest]
};
private _generalEligible = {
    params ["_rootIndex", "_childIndex"];
    private _root = _locations select _rootIndex;
    private _child = _locations select _childIndex;
    _rootIndex != _childIndex && {!(_rootIndex in _consumed)} && {!(_childIndex in _consumed)} &&
    {(_root get "type") in (_options get "primaryTypes")} &&
    {count (_root get "_members") >= (_root get "_minimum")} &&
    {(_child get "type") != (_root get "type")} &&
    {(_child get "type") in (_options get "secondaryTypes")} &&
    {(_coreAreas select _childIndex) <= (_coreAreas select _rootIndex)} &&
    {!([_root get "type", _child get "type"] call _isReverseSupport)} &&
    {!_consolidatingCores || {!([_root get "type", _child get "type"] call _isTypedSupport)}} &&
    {([_rootIndex, _childIndex, _options get "linkDistance", _options get "maximumMemberDistance"] call _relationship) select 0}
};
// Dual-tag structures must not export duplicate base and airfield source sites.
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
private _supportCandidates = {
    params ["_childIndex", "_support"];
    private _candidates = [];
    {
        private _rootIndex = _forEachIndex;
        if (_rootIndex != _childIndex && {!(_rootIndex in _consumed)} &&
            {(_x get "type") in (_support getOrDefault ["primaryTypes", ["base"]])} &&
            {count (_x get "_members") >= (_x get "_minimum")}) then {
            ([_rootIndex, _childIndex, _support get "linkDistance", _support get "maximumMemberDistance"] call _relationship) params ["_eligible", "_near"];
            if (_eligible) then { _candidates pushBack [_near, _x get "id", _rootIndex]; };
        };
    } forEach _locations;
    _candidates sort true;
    _candidates
};
// Reserve eligible typed support without attaching it. This preserves settlement
// port/fuel and military support preference, but cannot veto their host's core merge.
private _reservedSupport = createHashMap;
{
    private _support = _x;
    if (_support getOrDefault ["enabled", false]) then {
        {
            private _childIndex = _forEachIndex;
            if (!(_childIndex in _consumed) && {(_x get "type") in (_support get "secondaryTypes")} &&
                {!(([_childIndex, _support] call _supportCandidates) isEqualTo [])}) then {
                _reservedSupport set [_childIndex, true];
            };
        } forEach _locations;
    };
} forEach _supportRules;
if (_options getOrDefault ["enabled", false]) then {
    _consolidatingCores = true;
    private _changed = true;
    while {_changed} do {
        private _previousCount = count _consumed;
        {
            private _rootIndex = _x select 3;
            if !(_rootIndex in _reservedSupport) then {
                {
                    private _childIndex = _forEachIndex;
                    if (!(_childIndex in _reservedSupport) && {[_rootIndex, _childIndex] call _generalEligible}) then {
                        [_rootIndex, _childIndex] call _merge;
                    };
                } forEach _locations;
            };
        } forEach _order;
        _changed = count _consumed > _previousCount;
    };
    _consolidatingCores = false;
};
// Freeze the consolidated core geometry, then resolve support against surviving hosts. Outlying support is never
// carried along blindly with an absorbed core and can remain independent.
{
    private _support = _x;
    if (_support getOrDefault ["enabled", false]) then {
        {
            private _childIndex = _forEachIndex;
            if (!(_childIndex in _consumed) && {(_x get "type") in (_support get "secondaryTypes")}) then {
                private _candidates = [_childIndex, _support] call _supportCandidates;
                if !(_candidates isEqualTo []) then { [(_candidates select 0) select 2, _childIndex] call _merge; };
            };
        } forEach _locations;
    };
} forEach _supportRules;
// A former military support component may now fit a civilian host, e.g. industry.
// Only unclaimed reserved children are reconsidered; this is not a new growth pass.
if (_options getOrDefault ["enabled", false]) then {
    {
        private _rootIndex = _x select 3;
        {
            private _childIndex = _forEachIndex;
            if (_childIndex in _reservedSupport && {[_rootIndex, _childIndex] call _generalEligible}) then {
                [_rootIndex, _childIndex] call _merge;
            };
        } forEach _locations;
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
            private _siteFootprint = [_coreMembers apply { (_points select _x) select 0 }, _location get "_padding", _footprintOptions] call IVCS_Locations_fitFootprint;
            // Attach role evidence inside the original footprint only, without growing a chain.
            // Overlapping sites may share evidence, as they already do for multi-tag objects.
            {
                private _allowedRoles = (_x select 1) arrayIntersect _roles;
                if !("base" in _coreTypes) then { _allowedRoles = _allowedRoles - ["radar"]; };
                if (!(_allowedRoles isEqualTo []) && {[_siteFootprint, _x select 0] call IVCS_Locations_footprintContains}) then {
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
            // Role evidence is admitted into a fixed shape; it never grows that shape.
            // Legacy position/size remain a conservative circle enclosing the whole shape.
            if ((_siteFootprint select 0) == "circle") then {
                _finalRadius = _finalRadius max ((_finalCenter distance2D (_siteFootprint select 1)) + ((_siteFootprint select 2) select 0));
            } else {
                { _finalRadius = _finalRadius max (_finalCenter distance2D _x); } forEach ([_siteFootprint] call IVCS_Locations_footprintCorners);
            };
            _location set ["footprint", _siteFootprint];
            _location set ["indexVariant", _settings get "variant"];
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
