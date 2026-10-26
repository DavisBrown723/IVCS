// Used by run.ps1 inside the isolated Altis dedicated-server mission.
waitUntil { time > 0 };
call compile preprocessFileLineNumbers "IVCS\Experiments\RoadNetwork\Locations\init.sqf";
private _emit = {
    params ["_kind", "_value"];
    for "_offset" from 0 to ((count _value) - 1) step 600 do {
        diag_log text format ["IVCS_AF_INDEX_%1_PART %2", _kind, _value select [_offset, 600]];
    };
    diag_log text format ["IVCS_AF_INDEX_%1_END", _kind];
};
private _settings = call IVCS_AF_indexSettings;
private _start = diag_tickTime;
private _records = if (isNil "IVCS_AF_IndexRecords") then { [_settings] call IVCS_AF_indexScan } else { IVCS_AF_IndexRecords };
private _result = [_records, _settings] call IVCS_AF_indexBuild;
private _catalogCount = 0;
{ _catalogCount = _catalogCount + (_x select 3); } forEach (_result get "catalog");
if (count _records == 0 || {count (_result get "locations") == 0} || {_catalogCount != count _records}) exitWith {
    diag_log "[IVCS TASK TEST] FAIL empty index or incomplete catalog";
    diag_log "[IVCS TASK TEST] DONE passed=0 failed=1";
};
{
    ["LOCATION", _x] call _emit;
} forEach (([_result get "locations"] call IVCS_AF_exportLocationsMapData) splitString toString [13,10]);
{ ["CATALOG", [_x] call IVCS_AF_serializeMapValue] call _emit; } forEach (_result get "catalog");
if !(missionNamespace getVariable ["IVCS_AF_IndexKeepInventory", false]) then {
private _groups = createHashMap;
{
    _x params ["_class", "_model", "_position"];
    private _key = str [_class, _model];
    if !(_key in _groups) then { _groups set [_key, [_class, _model, []]]; };
    ((_groups get _key) select 2) pushBack _position;
} forEach _records;
private _groupKeys = keys _groups;
_groupKeys sort true;
{
    (_groups get _x) params ["_class", "_model", "_positions"];
    for "_offset" from 0 to ((count _positions) - 1) step 200 do {
        ["OBJECT", [[_class, _model, _positions select [_offset, 200]]] call IVCS_AF_serializeMapValue] call _emit;
    };
} forEach _groupKeys;
};
private _counts = createHashMap;
{ private _type = _x get "type"; _counts set [_type, (_counts getOrDefault [_type, 0]) + 1]; } forEach (_result get "locations");
diag_log format ["[IVCS TASK TEST] INDEX world=%1 objects=%2 unclassified=%3 locations=%4 counts=%5 seconds=%6 rejectedPortObjects=%7", worldName, count _records, _result get "unclassifiedCount", count (_result get "locations"), _counts, diag_tickTime - _start, _result get "rejectedPortObjects"];
diag_log "[IVCS TASK TEST] DONE passed=1 failed=0";
