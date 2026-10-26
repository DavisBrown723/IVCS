waitUntil { time > 0 };
// Loading and running the experiment must not replace production functions or state.
IVCS_Locations_indexBuild = { "production-sentinel" };
IVCS_Locations_CurrentMapData = ["production-data-sentinel"];
call compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\init.sqf";
private _locations = call compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\output\altis\locations.sqf";
private _baseline = call compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\baseline\locations.sqf";
private _catalog = call compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\output\altis\catalog.sqf";
private _baselineCatalog = call compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\baseline\catalog.sqf";
private _passed = 0;
private _failed = 0;
private _assert = {
    params ["_ok","_message"];
    if (_ok) then { _passed = _passed + 1; } else { _failed = _failed + 1; };
    diag_log format ["[IVCS TASK TEST] %1 %2",if (_ok) then {"PASS"} else {"FAIL"},_message];
};
[count _locations > 0 && {count _baseline == 280}, "experimental output and frozen v6 baseline load separately"] call _assert;
[(call IVCS_Locations_indexBuild) == "production-sentinel" && {IVCS_Locations_CurrentMapData isEqualTo ["production-data-sentinel"]}, "experimental init leaves production functions and mission data untouched"] call _assert;
[_catalog isEqualTo _baselineCatalog, "classification catalog is unchanged by the geometry experiment"] call _assert;
private _ids = createHashMap;
{ _ids set [_x get "id",true]; } forEach _locations;
[count _ids == count _locations, "experimental location IDs are unique"] call _assert;
[(_locations findIf {
    (_x get "world") != worldName || {(_x get "indexVariant") != "adaptive-footprints-v1"} || {(_x get "indexVersion") != 6} || {_x get "reviewed"}
}) == -1, "experimental records identify their variant without promoting candidates"] call _assert;
[(_locations findIf {
    private _f = _x getOrDefault ["footprint",[]];
    count _f != 4 || {!((_f select 0) in ["circle","rectangle"])} || {count (_f select 1) != 3} || {((_f select 1) select 2) != 0} || {((_f select 2) select 0) <= 0} || {((_f select 2) select 1) <= 0} || {(_f select 3) < 0} || {(_f select 3) >= 90}
}) == -1, "saved footprints have usable dimensions, centers and normalized rotations"] call _assert;
private _rectangles = _locations select { (_x get "footprint" select 0) == "rectangle" };
[count _rectangles > 0 && {count _rectangles < count _locations}, "Altis uses a mixture of rectangles and circles"] call _assert;
[(_locations findIf {
    private _site = _x;
    private _f = _site get "footprint";
    if ((_f select 0) == "circle") then {
        ((_site get "position") distance2D (_f select 1)) + ((_f select 2) select 0) > (_site get "size") + 0.05
    } else {
        (([_f] call IVCS_AF_footprintCorners) findIf { _x distance2D (_site get "position") > (_site get "size") + 0.05 }) >= 0
    }
}) == -1, "every legacy radius encloses the full saved footprint"] call _assert;
[(_locations findIf {
    private _f = _x get "footprint";
    ((_x getOrDefault ["militaryBuildings",[]]) findIf { !([_f,_x select 3,0.05] call IVCS_AF_footprintContains) }) >= 0
}) == -1, "every retained military building lies within its saved footprint"] call _assert;
[(call compile ([_locations] call IVCS_AF_exportLocationsMapData)) isEqualTo _locations, "complete experimental output round-trips precisely"] call _assert;
private _mainAirport = _locations select { (_x get "id") == "altis_airfield_169" };
[count _mainAirport == 1 && {(_mainAirport select 0 get "footprint" select 0) == "rectangle"}, "main Altis airport receives a rotated rectangular footprint"] call _assert;
[(_locations findIf {
    private _n = 0;
    { _n = _n + (_x select 1); } forEach (_x get "models");
    _n != (_x get "objectCount")
}) == -1, "model evidence still counts each site member once"] call _assert;
[(_locations findIf { (_x get "type") == "airfield" || {"airfield" in (_x get "types")} }) == -1, "airfield military identity survives geometry changes"] call _assert;
private _markers = [_rectangles select [0,4],"IVCS_AF_ArtifactTest"] call IVCS_AF_indexPreview;
private _matching = true;
{
    private _f = _x get "footprint";
    private _name = _markers select (2 * _forEachIndex);
    if (markerShape _name != "RECTANGLE" || {markerSize _name distance2D (_f select 2) > 0.01} || {abs (markerDir _name - (_f select 3)) > 0.01} || {markerPos _name distance2D (_f select 1) > 0.01}) then { _matching = false; };
} forEach (_rectangles select [0,4]);
[_matching, "native marker centers, dimensions and rotations match saved geometry"] call _assert;
{ deleteMarkerLocal _x; } forEach _markers;
private _guard = createMarkerLocal ["IVCS_Demo_MapIndex_Preserved",[0,0,0]];
private _demo = ["compare",[],false] execVM "IVCS\Experiments\AdaptiveFootprints\demo.sqf";
waitUntil { scriptDone _demo };
[count IVCS_AF_DemoLocations == count _locations && {count IVCS_AF_DemoMarkers == count _baseline + 2 * count _locations}, "comparison mode overlays frozen baseline outlines and experimental labels"] call _assert;
[_guard in allMapMarkers && {(call IVCS_Locations_indexBuild) == "production-sentinel"}, "comparison preview leaves normal demo markers and functions intact"] call _assert;
private _oldOutlines = IVCS_AF_DemoMarkers select { (_x find "IVCS_AF_Demo_Baseline_") == 0 };
[(_oldOutlines findIf { markerShape _x != "ELLIPSE" || {markerColor _x != "ColorGrey"} }) == -1, "comparison baseline uses grey circular outlines"] call _assert;
private _filter = ["adaptive",["air"],false] execVM "IVCS\Experiments\AdaptiveFootprints\demo.sqf";
waitUntil { scriptDone _filter };
[count IVCS_AF_DemoLocations == count (_locations select {"air" in (_x get "types")}) && {count IVCS_AF_DemoMarkers == 2 * count IVCS_AF_DemoLocations}, "rerunning the isolated demo replaces its own markers and applies role filters"] call _assert;
private _oldDemo = ["baseline",[],false] execVM "IVCS\Experiments\AdaptiveFootprints\demo.sqf";
waitUntil { scriptDone _oldDemo };
[IVCS_AF_DemoLocations isEqualTo _baseline && {count IVCS_AF_DemoMarkers == 2 * count _baseline}, "baseline-only mode loads the frozen original data"] call _assert;
call compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\stop-demo.sqf";
[_guard in allMapMarkers && {(allMapMarkers findIf { (_x find "IVCS_AF_Demo_") == 0 }) == -1} && {IVCS_Locations_CurrentMapData isEqualTo ["production-data-sentinel"]}, "experimental cleanup removes only experimental state"] call _assert;
deleteMarkerLocal _guard;
diag_log format ["[IVCS TASK TEST] FOOTPRINTS sites=%1 rectangles=%2 circles=%3",count _locations,count _rectangles,count _locations - count _rectangles];
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
