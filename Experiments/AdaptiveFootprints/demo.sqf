// Local Exec: ["compare"] execVM "IVCS\Experiments\AdaptiveFootprints\demo.sqf";
// Modes: adaptive, baseline, compare. Grey outlines in compare are the frozen v6 baseline.
params [["_mode", "compare"], ["_types", []], ["_openMap", true], ["_focus", []]];
_mode = toLower _mode;
if !(_mode in ["adaptive","baseline","compare"]) exitWith { diag_log "[IVCS AF DEMO] Expected adaptive, baseline, or compare mode."; };
if (_openMap && {!hasInterface}) exitWith { diag_log "[IVCS AF DEMO] Use Local Exec on a player client."; };
private _root = "IVCS\Experiments\AdaptiveFootprints\";
private _path = _root + format ["output\%1\locations.sqf", toLower worldName];
private _baselinePath = _root + "baseline\locations.sqf";
if (_mode == "baseline") then { _path = _baselinePath; };
if (!(fileExists _path) || {_mode == "compare" && {!(fileExists _baselinePath)}}) exitWith {
    diag_log "[IVCS AF DEMO] Generate the experimental index before loading the demo.";
    if (hasInterface) then { hint "Adaptive-footprint index is missing. Run the experiment's run.ps1 first."; };
};
private _locations = call compile preprocessFileLineNumbers _path;
private _baseline = if (_mode == "compare") then { call compile preprocessFileLineNumbers _baselinePath } else { [] };
if (((_locations + _baseline) findIf { toLower (_x get "world") != toLower worldName }) >= 0) exitWith {
    diag_log "[IVCS AF DEMO] Index terrain does not match this mission.";
};
_types = _types apply { toLower _x };
if ("airfield" in _types) then { _types pushBackUnique "air"; };
if !(_types isEqualTo []) then {
    _locations = _locations select { ((_x get "types") findIf { _x in _types }) >= 0 };
    _baseline = _baseline select { ((_x get "types") findIf { _x in _types }) >= 0 };
};
call compile preprocessFileLineNumbers (_root + "stop-demo.sqf");
IVCS_AF_DemoScript = _thisScript;
IVCS_AF_DemoLocations = _locations;
private _preview = compile preprocessFileLineNumbers (_root + "preview.sqf");
private _markers = [];
if (_mode == "compare") then {
    private _oldMarkers = [_baseline, "IVCS_AF_Demo_Baseline"] call _preview;
    {
        if ((_x find "_label") >= 0) then { deleteMarkerLocal _x; } else {
            _x setMarkerColorLocal "ColorGrey";
            _x setMarkerAlphaLocal 0.4;
            _markers pushBack _x;
        };
    } forEach _oldMarkers;
};
_markers append ([_locations, "IVCS_AF_Demo_Active"] call _preview);
IVCS_AF_DemoMarkers = _markers;
if (hasInterface) then {
    if (_openMap) then {
        if (_focus isEqualTo []) then { _focus = [worldSize / 2,worldSize / 2,0]; };
        openMap true;
        mapAnimClear;
        mapAnimAdd [0,0.35,_focus];
        mapAnimCommit;
    };
    hint format ["Footprint experiment: %1 (%2 sites).\n%3", _mode, count _locations, if (_mode == "compare") then { "Grey = original circles; coloured = adaptive footprints." } else { "Labels show the displayed footprint dimensions." }];
};
diag_log format ["[IVCS AF DEMO] mode=%1 sites=%2 markers=%3", _mode, count _locations, count _markers];
