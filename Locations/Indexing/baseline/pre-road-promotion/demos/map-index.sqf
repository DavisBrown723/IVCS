// Run with Local Exec on the indexed terrain; no IVCS startup is required.
// [] execVM "IVCS\demos\map-index.sqf";
// Optional: [["base","air"]] execVM "IVCS\demos\map-index.sqf";
params [["_types", [], [[]]], ["_path", "", [""]], ["_openMap", true, [true]]];
if (_openMap && {!hasInterface}) exitWith {
    diag_log "[IVCS DEMO] Run the map-index demo with Local Exec on a player client.";
};
if (_path == "") then {
    _path = format ["IVCS\Locations\Indexing\output\%1\locations.sqf", toLower worldName];
};
if !(fileExists _path) exitWith {
    private _message = format ["No generated location file for %1: %2", worldName, _path];
    diag_log ("[IVCS DEMO] " + _message);
    if (hasInterface) then { hint _message; };
};
private _locations = call compile preprocessFileLineNumbers _path;
if (isNil "_locations" || {!(_locations isEqualType [])}) exitWith {
    diag_log "[IVCS DEMO] Location file must return an array of location hash maps.";
    if (hasInterface) then { hint "The location file did not return a location array."; };
};
if ((_locations findIf { toLower (_x getOrDefault ["world", worldName]) != toLower worldName }) != -1) exitWith {
    diag_log "[IVCS DEMO] The location file belongs to a different terrain.";
    if (hasInterface) then { hint "Load this index on its matching terrain."; };
};
_types = _types apply { toLower _x };
// Keep old demo calls working with both legacy files and the new base + air schema.
if ("airfield" in _types) then { _types pushBackUnique "air"; };
if !(_types isEqualTo []) then {
    _locations = _locations select { ((_x getOrDefault ["types", [_x get "type"]]) findIf { toLower _x in _types }) != -1 };
};
call compile preprocessFileLineNumbers "IVCS\demos\stop-map-index.sqf";
IVCS_Demo_MapIndexScript = _thisScript;
IVCS_Demo_MapIndexLocations = _locations;
// Compile just the preview so this demo also works before IVCS initialization.
private _preview = compile preprocessFileLineNumbers "IVCS\Locations\Indexing\preview.sqf";
IVCS_Demo_MapIndexMarkers = [_locations, "IVCS_Demo_MapIndex"] call _preview;
diag_log format ["[IVCS DEMO] Map index: %1 locations, source %2", count _locations, _path];
if (hasInterface) then {
    if (_openMap) then {
        openMap true;
        mapAnimClear;
        mapAnimAdd [0, 1, [worldSize / 2, worldSize / 2, 0]];
        mapAnimCommit;
    };
    hint format ["Map index: %1 locations.\nLabels show function, object count, and radius.\nZoom in to inspect overlapping areas.", count _locations];
};
