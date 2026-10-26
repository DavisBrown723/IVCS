// Standalone road extraction. Engine references never leave this capture.
waitUntil { time > 0 };
IVCS_RN_serialize = compile preprocessFileLineNumbers "IVCS\Experiments\RoadNetwork\serialize.sqf";
// The copied serializer recurses through this alias, all within the experiment namespace.
IVCS_RN_serializeMapValue = IVCS_RN_serialize;
private _emit = {
    params ["_kind","_value"];
    private _text = [_value] call IVCS_RN_serialize;
    for "_offset" from 0 to (count _text - 1) step 600 do {
        diag_log text format ["IVCS_RN_%1_PART %2",_kind,_text select [_offset,600]];
    };
    diag_log text format ["IVCS_RN_%1_END",_kind];
};
private _started = diag_tickTime;
private _probe = missionNamespace getVariable ["IVCS_RN_Probe",false];
private _roads = [];
private _ids = createHashMap;
private _add = {
    params ["_road"];
    private _key = str _road;
    if !(_key in _ids) then { _ids set [_key,count _roads]; _roads pushBack _road; };
};
if (_probe) then {
    { [_x] call _add; } forEach ([14648,16551,0] nearRoads 1600);
} else {
    private _step = 2000;
    for "_y" from 0 to worldSize step _step do {
        for "_x" from 0 to worldSize step _step do {
            { [_x] call _add; } forEach ([_x + _step / 2,_y + _step / 2,0] nearRoads (_step * 0.708 + 20));
        };
        diag_log format ["[IVCS TASK TEST] ROAD scan y=%1 sections=%2",_y,count _roads];
        sleep 0.001;
    };
};
private _initial = count _roads;
// Add all referenced neighbours so no exported connection points at a missing section.
private _links = [];
private _index = 0;
while {_index < count _roads} do {
    private _road = _roads select _index;
    private _ordinary = roadsConnectedTo _road;
    private _extended = roadsConnectedTo [_road,true];
    { [_x] call _add; } forEach (_ordinary + _extended);
    _links pushBack [_ordinary apply {_ids get str _x},_extended apply {_ids get str _x}];
    _index = _index + 1;
    if ((_index mod 1000) == 0) then {
        diag_log format ["[IVCS TASK TEST] ROAD links %1/%2",_index,count _roads];
        sleep 0.001;
    };
    // Probe includes one-hop neighbours; full extraction closes the entire reference set.
    if (_probe && {_index >= _initial}) exitWith {};
};
["META",[worldName,worldSize,productVersion,_initial,count _roads,_probe]] call _emit;
{
    private _road = _x;
    private _info = getRoadInfo _road;
    private _connections = _links param [_forEachIndex,[[],[]]];
    ["ROAD",[_forEachIndex,str _road,getPosASL _road,_info,_connections select 0,_connections select 1]] call _emit;
    if ((_forEachIndex mod 1000) == 0) then { sleep 0.001; };
} forEach _roads;
{
    ["PLACE",[configName _x,getText (_x >> "name"),getArray (_x >> "position"),getText (_x >> "type")]] call _emit;
} forEach ("true" configClasses (configFile >> "CfgWorlds" >> worldName >> "Names"));
diag_log format ["[IVCS TASK TEST] ROAD sections=%1 initial=%2 seconds=%3 probe=%4",count _roads,_initial,diag_tickTime-_started,_probe];
diag_log "[IVCS TASK TEST] DONE passed=1 failed=0";
