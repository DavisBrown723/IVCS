// Authoring stage: reusable inventory -> spatially validated functional compounds.
// No engine object references, namespaces, markers or global map data are mutated.
params ["_records", ["_settings", call IVCS_Locations_indexSettings], ["_world", worldName], ["_isWater", { surfaceIsWater (_this select 0) }]];
private _catalog = createHashMap;
private _militaryKinds = createHashMap;
private _militaryRules = _settings getOrDefault ["militaryBuildings", createHashMap];
private _classified = [];
private _untagged = 0;
private _rejectedPortObjects = 0;
{
    _x params ["_class", "_model", "_position"];
    _class = toLower _class;
    _model = toLower _model;
    private _key = str [_class, _model];
    if !(_key in _catalog) then {
        private _tags = [_class, _model, _settings] call IVCS_Locations_indexClassify;
        _catalog set [_key, [_class, _model, _tags, 0, +_position]];
        private _kinds = [];
        if (("base" in _tags || {"airfield" in _tags}) && {count _militaryRules > 0}) then {
            _kinds = ([_class, _model, _militaryRules] call IVCS_Locations_indexClassify) arrayIntersect ["barracks","fortification"];
        };
        _militaryKinds set [_key, _kinds];
    };
    private _entry = _catalog get _key;
    _entry set [3, (_entry select 3) + 1];
    private _sample = _entry select 4;
    if ((_position select 0) < (_sample select 0) || {(_position select 0) == (_sample select 0) && {(_position select 1) < (_sample select 1)}}) then { _entry set [4, +_position]; };
    private _tags = +(_entry select 2);
    if ("port" in _tags && {!([_position, _settings getOrDefault ["portWaterRadius", 150], _settings getOrDefault ["portWaterStep", 25], _isWater] call IVCS_Locations_indexNearWater)}) then {
        _tags = _tags - ["port"];
        _rejectedPortObjects = _rejectedPortObjects + 1;
    };
    if (_tags isEqualTo []) then { _untagged = _untagged + 1; } else {
        _classified pushBack [_position select 0, _position select 1, _model, _class, _tags, _militaryKinds get _key];
    };
} forEach _records;
// Sorting only tagged evidence avoids sorting hundreds of thousands of clutter objects.
_classified sort true;
// Internal point: [position, functional tags, model, member index, building kinds, class].
_classified = _classified apply { [[_x select 0, _x select 1, 0], _x select 4, _x select 2, 0, _x select 5, _x select 3] };
{ _x set [3, _forEachIndex]; } forEach _classified;
private _locations = [];
{
    _x params ["_type", "_link", "_minimum", "_extent", "_density", "_padding"];
    _link = _link max 1;
    private _points = _classified select { _type in (_x select 1) };
    private _buckets = createHashMap;
    {
        private _pos = _x select 0;
        private _key = str [floor ((_pos select 0) / _link), floor ((_pos select 1) / _link)];
        if !(_key in _buckets) then { _buckets set [_key, []]; };
        (_buckets get _key) pushBack _forEachIndex;
    } forEach _points;
    private _neighbours = {
        params ["_index"];
        private _pos = (_points select _index) select 0;
        private _cx = floor ((_pos select 0) / _link);
        private _cy = floor ((_pos select 1) / _link);
        private _result = [];
        for "_dy" from -1 to 1 do {
            for "_dx" from -1 to 1 do {
                {
                    if (((_points select _x) select 0) distance2D _pos <= _link) then { _result pushBack _x; };
                } forEach (_buckets getOrDefault [str [_cx + _dx, _cy + _dy], []]);
            };
        };
        _result
    };
    private _assigned = createHashMap;
    {
        private _seed = _forEachIndex;
        if !(_seed in _assigned) then {
            private _near = [_seed] call _neighbours;
            if (count _near >= _density) then {
                private _anchor = _x select 0;
                private _queue = [_seed];
                private _queued = createHashMapFromArray [[_seed, true]];
                private _cursor = 0;
                while {_cursor < count _queue} do {
                    private _current = _queue select _cursor;
                    _cursor = _cursor + 1;
                    private _adjacent = [_current] call _neighbours;
                    if (count _adjacent >= _density) then {
                        {
                            if (!(_x in _assigned) && {!(_x in _queued)} && {((_points select _x) select 0) distance2D _anchor <= _extent}) then {
                                _queued set [_x, true];
                                _queue pushBack _x;
                            };
                        } forEach _adjacent;
                    };
                };
                // Failed candidates do not consume points needed by a later seed.
                // Retain lone power objects as compound evidence, but not standalone sites.
                if (count _queue >= _minimum || {_type == "power" && {count _queue == 1}}) then {
                    private _center = [0,0,0];
                    private _models = createHashMap;
                    {
                        _assigned set [_x, true];
                        private _point = _points select _x;
                        _center = _center vectorAdd (_point select 0);
                        private _model = _point select 2;
                        _models set [_model, (_models getOrDefault [_model, 0]) + 1];
                    } forEach _queue;
                    _center = _center vectorMultiply (1 / count _queue);
                    private _radius = 0;
                    { _radius = _radius max (_center distance2D ((_points select _x) select 0)); } forEach _queue;
                    private _location = [_type, _center, _radius + _padding] call IVCS_Locations_createLocation;
                    _location set ["id", format ["%1_%2_%3", toLower _world, _type, _seed]];
                    _location set ["objectCount", count _queue];
                    _location set ["_members", _queue apply { (_points select _x) select 3 }];
                    _location set ["_padding", _padding];
                    _location set ["_minimum", _minimum];
                    private _modelKeys = keys _models;
                    _modelKeys sort true;
                    _location set ["models", _modelKeys apply { [_x, _models get _x] }];
                    _location set ["source", "terrain-index"];
                    _location set ["indexVersion", _settings get "version"];
                    _location set ["world", _world];
                    _location set ["reviewed", false];
                    _locations pushBack _location;
                };
            };
        };
    } forEach _points;
    diag_log format ["[IVCS INDEX] clustered %1: %2 matching objects", _type, count _points];
} forEach (_settings get "categories");
_locations = [_locations, _classified, _settings] call IVCS_Locations_indexRefine;
private _keys = keys _catalog;
_keys sort true;
createHashMapFromArray [
    ["world", _world], ["version", _settings get "version"],
    ["locations", _locations], ["catalog", _keys apply { _catalog get _x }],
    ["objectCount", count _records],
    ["unclassifiedCount", _untagged],
    ["rejectedPortObjects", _rejectedPortObjects]
]
