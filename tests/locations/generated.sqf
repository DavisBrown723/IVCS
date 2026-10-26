waitUntil { time > 0 };
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
private _locations = call compile preprocessFileLineNumbers "IVCS\Locations\Indexing\output\altis\locations.sqf";
private _catalog = call compile preprocessFileLineNumbers "IVCS\Locations\Indexing\output\altis\catalog.sqf";
private _records = call compile preprocessFileLineNumbers "IVCS\Locations\Indexing\output\altis\objects.sqf";
IVCS_IndexPassed = 0;
IVCS_IndexFailed = 0;
private _assert = {
    params ["_ok", "_label"];
    if (_ok) then { IVCS_IndexPassed = IVCS_IndexPassed + 1; } else { IVCS_IndexFailed = IVCS_IndexFailed + 1; };
    diag_log format ["[IVCS TASK TEST] %1 %2", if (_ok) then { "PASS" } else { "FAIL" }, _label];
};
[count _locations > 0 && {count _catalog > 0} && {count _records > 0}, "generated SQF artifacts load in the engine"] call _assert;
private _count = 0;
{ _count = _count + (_x select 3); } forEach _catalog;
[_count == count _records, "compact inventory retains every cataloged instance"] call _assert;
[(_records findIf { count _x != 3 || {!((_x select 0) isEqualType "")} || {!((_x select 1) isEqualType "")} || {count (_x select 2) != 3} }) == -1, "compact inventory expands to the documented object record format"] call _assert;
private _ids = createHashMap;
{ _ids set [_x get "id", true]; } forEach _locations;
[count _ids == count _locations, "generated location IDs are unique"] call _assert;
[(_locations findIf { (_x get "world") != worldName || {(_x get "size") <= 0} || {_x get "reviewed"} }) == -1, "generated objectives are usable Altis candidates pending review"] call _assert;
[(call compile ([_locations] call IVCS_Locations_exportLocationsMapData)) isEqualTo _locations, "complete generated index survives a precise export round trip"] call _assert;
private _markers = [_locations select [0,3], "IVCS_IndexTest"] call IVCS_Locations_indexPreview;
[count _markers == 6 && {(_markers findIf { !(_x in allMapMarkers) }) == -1}, "preview creates radius and label markers"] call _assert;
{ deleteMarkerLocal _x; } forEach _markers;
private _settings = call IVCS_Locations_indexSettings;
[(_catalog findIf { !(([_x select 0, _x select 1, _settings] call IVCS_Locations_indexClassify) isEqualTo (_x select 2)) }) == -1, "saved catalog matches current classification rules"] call _assert;
[(_locations findIf { (_x get "indexVersion") != (_settings get "version") || {isNil {_x get "types"}} || {isNil {_x get "typeCounts"}} || {!(isNil {_x get "_members"})} }) == -1, "saved locations use the refined schema without internal member indices"] call _assert;
[(_locations findIf { (_x get "type") == "port" && {(_x get "position") distance2D [20942.27,16992.13,0] < 250} }) == -1, "Paros inland pier models no longer produce a port"] call _assert;
[(_locations findIf { "port" in (_x get "types") && {(_x get "position") distance2D [21858.85,10898.18,0] < 250} }) >= 0, "genuine coastal port east of Chalkeia remains indexed"] call _assert;
private _chalkeia = _locations select {
    "fuel" in (_x get "types") && {
        ((_x get "type") == "fuel" && {(_x get "position") distance2D [19970,11460,0] < 250}) ||
        {((_x getOrDefault ["components", []]) findIf { (_x select 0) == "altis_fuel_86" }) >= 0}
    }
};
[count _chalkeia == 1 && {((createHashMapFromArray (_chalkeia select 0 get "typeCounts")) get "fuel") == 7}, "Chalkeia retains one seven-object fuel component after support absorption"] call _assert;
[(_locations findIf { (_x get "type") == "power" && {((createHashMapFromArray (_x get "typeCounts")) get "power") < 2} }) == -1, "no standalone single-object power facilities remain"] call _assert;
private _athira = _locations select { (_x get "type") == "factory" && {(_x get "position") distance2D [14338.49,18940.1,0] < 200} };
[count _athira == 1 && {(_athira select 0 get "objectCount") == 46} && {(_athira select 0 get "types") isEqualTo ["factory","power","town"]} && {count (_athira select 0 get "components") == 4}, "Athira factory reports its barracks as housing and retains nearby power evidence"] call _assert;
[(_locations findIf {
    (_x get "id") == "altis_town_3707" && {(_x get "type") == "town"} &&
    {(_x get "objectCount") == 170} && {(_x get "typeCounts") isEqualTo [["fuel",7],["town",163]]} &&
    {((_x get "components") findIf { (_x select 0) == "altis_fuel_57" && {(_x select 2) == 7} }) >= 0}
}) >= 0, "Athira's larger settlement stays separate from the factory and absorbs its own fuel station"] call _assert;
[(_locations findIf { (_x get "type") == "base" && {(_x get "objectCount") == 6} && {(_x get "position") distance2D [13815.82,18962.97,0] < 10} }) >= 0, "the separate military compound west of the factory remains independent"] call _assert;
if !( _athira isEqualTo [] ) then {
    private _compoundMarkers = [_athira, "IVCS_CompoundTest"] call IVCS_Locations_indexPreview;
    [(markerText (_compoundMarkers select 1) find "(+ power, housing)") >= 0, "compound map label describes all secondary functions"] call _assert;
    { deleteMarkerLocal _x; } forEach _compoundMarkers;
};
[(_locations findIf {
    private _total = 0;
    { _total = _total + (_x select 1); } forEach (_x get "models");
    _total != (_x get "objectCount")
}) == -1, "saved model evidence counts equal unique object counts after merging"] call _assert;
// Exercise the actual demo with map opening disabled on the dedicated test server.
private _demo = [["power"], "", false] execVM "IVCS\demos\map-index.sqf";
waitUntil { scriptDone _demo };
[count IVCS_Demo_MapIndexLocations > 0 && {(IVCS_Demo_MapIndexLocations findIf { !("power" in (_x get "types")) }) == -1} && {count IVCS_Demo_MapIndexMarkers == 2 * count IVCS_Demo_MapIndexLocations}, "demo category filtering shows matching functions with labels and footprints"] call _assert;
[(IVCS_Demo_MapIndexLocations findIf { (_x get "type") == "factory" && {(_x get "position") distance2D [14338.49,18940.1,0] < 200} }) >= 0, "power filter includes the Athira industrial compound through its secondary role"] call _assert;
call compile preprocessFileLineNumbers "IVCS\demos\stop-map-index.sqf";
private _radarBase = _locations select { (_x get "type") == "base" && {(_x get "position") distance2D [25300,21820,0] < 200} };
[count _radarBase == 1 && {"radar" in (_radarBase select 0 get "types")} && {"power" in (_radarBase select 0 get "types")}, "northeastern radar base retains radar and absorbs its nearby power site"] call _assert;
[(_locations findIf { (_x get "type") == "power" && {(_x get "position") distance2D [25300,21820,0] < 200} }) == -1, "power support at the radar base is no longer a separate location"] call _assert;
private _heliBase = _locations select { (_x get "type") == "base" && {(_x get "position") distance2D [12495.8,15195.9,0] < 150} };
[count _heliBase == 1 && {"radiotower" in (_heliBase select 0 get "types")} && {"heli" in (_heliBase select 0 get "types")}, "small military base near the central airfield absorbs radio and retains its helipad"] call _assert;
private _roleModels = createHashMap;
{ _roleModels set [_x select 1, _x select 2]; } forEach _catalog;
{
    private _role = _x;
    private _withRole = _locations select { _role in (_x get "types") };
    [count _withRole > 0 && {(_withRole findIf {
        private _expected = 0;
        {
            private _tags = _roleModels getOrDefault [_x select 0, []];
            if (_role in _tags || {_role == "air" && {"airfield" in _tags}}) then { _expected = _expected + (_x select 1); };
        } forEach (_x get "models");
        private _counts = createHashMapFromArray (_x get "typeCounts");
        _expected == 0 || {(_counts get _role) != _expected}
    }) == -1}, format ["saved %1 roles have matching object evidence and counts", _role]] call _assert;
    private _roleDemo = [[_role], "", false] execVM "IVCS\demos\map-index.sqf";
    waitUntil { scriptDone _roleDemo };
    [count IVCS_Demo_MapIndexLocations == count _withRole && {(IVCS_Demo_MapIndexLocations findIf { !(_role in (_x get "types")) }) == -1}, format ["demo supports the %1 secondary-role filter", _role]] call _assert;
    if (_role in ["heli","air"]) then {
        private _expectedBadge = "[" + _role + "]";
        [(IVCS_Demo_MapIndexMarkers findIf { (_x find "_label") >= 0 && {(markerText _x find _expectedBadge) < 0} }) == -1, format ["saved %1 sites display their role badge", _role]] call _assert;
    };
    call compile preprocessFileLineNumbers "IVCS\demos\stop-map-index.sqf";
} forEach ["radar","heli","air"];
[(_locations findIf { (_x get "type") in ["radar","heli","air"] }) == -1, "radar, heli and air remain secondary roles instead of primary site categories"] call _assert;
[(_locations findIf { (_x get "type") == "factory" && {"base" in (_x get "types")} }) == -1, "industrial sites no longer expose a military secondary role"] call _assert;
[count _athira == 1 && {((createHashMapFromArray (_athira select 0 get "typeCounts")) get "town") == 15}, "Athira housing count includes thirteen housing objects and two former military objects"] call _assert;
private _baseFilter = [["base"], "", false] execVM "IVCS\demos\map-index.sqf";
waitUntil { scriptDone _baseFilter };
[count IVCS_Demo_MapIndexLocations > 0 && {(IVCS_Demo_MapIndexLocations findIf { (_x get "type") == "factory" }) == -1}, "military demo filter excludes industrial sites with remapped housing"] call _assert;
call compile preprocessFileLineNumbers "IVCS\demos\stop-map-index.sqf";
private _fuelOwners = createHashMap;
private _uniqueFuelOwners = true;
{
    private _sources = if ((_x get "type") == "fuel") then { [[_x get "id", "fuel", _x get "objectCount"]] } else {
        (_x getOrDefault ["components", []]) select { (_x select 1) == "fuel" }
    };
    {
        private _id = _x select 0;
        if (_id in _fuelOwners) then { _uniqueFuelOwners = false; };
        _fuelOwners set [_id, true];
    } forEach _sources;
} forEach _locations;
[_uniqueFuelOwners && {count _fuelOwners > 0}, "each original fuel cluster has only one saved owner"] call _assert;
private _fuelDemo = [["fuel"], "", false] execVM "IVCS\demos\map-index.sqf";
waitUntil { scriptDone _fuelDemo };
[(IVCS_Demo_MapIndexLocations findIf { (_x get "type") == "town" && {"fuel" in (_x get "types")} }) >= 0, "fuel demo filter includes civilian settlements that absorbed stations"] call _assert;
[(IVCS_Demo_MapIndexLocations findIf { (_x get "type") == "base" && {"fuel" in (_x get "types")} }) >= 0, "fuel demo filter includes military bases that absorbed stations"] call _assert;
call compile preprocessFileLineNumbers "IVCS\demos\stop-map-index.sqf";
// Internal building metadata must describe real members without changing site roles.
private _militarySites = _locations select { "base" in (_x get "types") };
[count _militarySites > 0 && {(_militarySites findIf {
    isNil {_x get "militaryBuildings"} || {isNil {_x get "militaryBuildingCounts"}}
}) == -1}, "every active military site saves building uses and counts"] call _assert;
[(_locations findIf {
    (!("base" in (_x get "types")) && {!(isNil {_x get "militaryBuildings"})}) ||
    {"barracks" in (_x get "types")} || {"fortification" in (_x get "types")}
}) == -1, "military building uses stay internal and exclude industrial housing"] call _assert;
[(_militarySites findIf {
    private _site = _x;
    private _buildings = _site get "militaryBuildings";
    private _counts = createHashMapFromArray (_site get "militaryBuildingCounts");
    private _seen = createHashMap;
    { _seen set [str (_x select [1,3]), true]; } forEach _buildings;
    count _seen != count _buildings ||
    {(_counts get "barracks") != ({(_x select 0) == "barracks"} count _buildings)} ||
    {(_counts get "fortification") != ({(_x select 0) == "fortification"} count _buildings)} ||
    {(_buildings findIf { count _x != 4 || {count (_x select 3) != 3} || {((_x select 3) select 2) != 0} || {(_x select 3) distance2D (_site get "position") > (_site get "size")} }) >= 0}
}) == -1, "saved building counts are unique and their positions lie inside the owning site"] call _assert;
private _buildingModels = createHashMap;
private _savedBuildings = [];
{
    {
        _buildingModels set [_x select 2, true];
        _savedBuildings pushBack _x;
    } forEach (_x get "militaryBuildings");
} forEach _militarySites;
private _inventoryBuildings = createHashMap;
{
    if ((_x select 1) in _buildingModels) then { _inventoryBuildings set [str _x, true]; };
} forEach _records;
[count _savedBuildings > 0 && {(_savedBuildings findIf { !(str (_x select [1,3]) in _inventoryBuildings) }) == -1}, "every saved military building identity and position exists in the raw inventory"] call _assert;
private _buildingRules = _settings get "militaryBuildings";
[(_savedBuildings findIf {
    !((_x select 0) in ([_x select 1, _x select 2, _buildingRules] call IVCS_Locations_indexClassify))
}) == -1, "saved military building uses match the current model rules"] call _assert;
private _fortificationSamples = createHashMap;
{
    if ((_x select 0) == "fortification") then { _fortificationSamples set [_x select 2, _x select 3]; };
} forEach _savedBuildings;
private _allMannable = true;
{
    private _model = _x;
    private _nearby = nearestTerrainObjects [_fortificationSamples get _model, [], 50, false, true];
    private _matches = _nearby select { toLower ((getModelInfo _x) select 1) == _model };
    if (_matches isEqualTo [] || {count ((_matches select 0) buildingPos -1) == 0}) then {
        _allMannable = false;
        diag_log format ["[IVCS TASK TEST] missing native fighting positions for %1", _model];
    };
} forEach (keys _fortificationSamples);
[count _fortificationSamples > 0 && {_allMannable}, "each saved Altis fortification model exposes native occupiable building positions"] call _assert;
[count _radarBase == 1 && {(_radarBase select 0 get "militaryBuildingCounts") isEqualTo [["barracks",1],["fortification",1]]}, "radar base distinguishes its cargo accommodation from its guard post"] call _assert;
// Both turbine variants remain inventoried, but none may enter any site model count.
private _windCatalog = _catalog select { ((_x select 1) find "\wpp_turbine") >= 0 };
private _windCount = 0;
{ _windCount = _windCount + (_x select 3); } forEach _windCatalog;
[count _windCatalog == 2 && {_windCount == 128} && {(_windCatalog findIf { !((_x select 2) isEqualTo []) }) == -1}, "all 128 Altis wind turbines remain in the catalog with no functional tags"] call _assert;
[(_locations findIf { ((_x get "models") findIf { ((_x select 0) find "\wpp_turbine") >= 0 }) >= 0 }) == -1, "wind turbines supply no standalone or secondary site evidence in saved Altis data"] call _assert;
// Public airfield identity is military + air; original source IDs remain traceable.
private _airfields = _locations select { ((_x get "id") find "altis_airfield_") == 0 };
[count _airfields == 5 && {(_airfields findIf { (_x get "type") != "base" || {!("air" in (_x get "types"))} || {!("base" in (_x get "types"))} }) == -1}, "all five Altis airfields are military bases with an air secondary role"] call _assert;
[(_locations findIf { (_x get "type") == "airfield" || {"airfield" in (_x get "types")} || {"airfield" in (createHashMapFromArray (_x get "typeCounts"))} }) == -1, "airfield remains a source category rather than an exported primary or secondary role"] call _assert;
private _airfieldMarkers = [_airfields, "IVCS_AirfieldArtifact"] call IVCS_Locations_indexPreview;
[(_airfieldMarkers findIf { (_x find "_label") >= 0 && {((markerText _x find "Military base") != 0) || {(markerText _x find "[air]") < 0}} }) == -1, "all saved airfields display military-base labels with air badges"] call _assert;
{ deleteMarkerLocal _x; } forEach _airfieldMarkers;
private _militaryDemo = [["base"], "", false] execVM "IVCS\demos\map-index.sqf";
waitUntil { scriptDone _militaryDemo };
[count (IVCS_Demo_MapIndexLocations select { ((_x get "id") find "altis_airfield_") == 0 }) == 5, "military demo filter includes all five airfields"] call _assert;
call compile preprocessFileLineNumbers "IVCS\demos\stop-map-index.sqf";
private _legacyAirDemo = [["airfield"], "", false] execVM "IVCS\demos\map-index.sqf";
waitUntil { scriptDone _legacyAirDemo };
[count IVCS_Demo_MapIndexLocations == count (_locations select { "air" in (_x get "types") }) && {count IVCS_Demo_MapIndexLocations >= 5}, "legacy airfield demo filter also resolves the new air role"] call _assert;
call compile preprocessFileLineNumbers "IVCS\demos\stop-map-index.sqf";
private _smallPierCatalog = _catalog select { (_x select 0) == "land_pier_small_f" || {((_x select 1) find "\pier_small_f.p3d") >= 0} };
private _smallPierCount = 0;
{ _smallPierCount = _smallPierCount + (_x select 3); } forEach _smallPierCatalog;
[_smallPierCount == 18 && {(_smallPierCatalog findIf { !((_x select 2) isEqualTo []) }) == -1}, "all eighteen small piers remain cataloged but are excluded from port evidence"] call _assert;
[(_locations findIf { ((_x get "models") findIf { ((_x select 0) find "\pier_small_f.p3d") >= 0 }) >= 0 }) == -1, "no saved site includes the excluded small-pier model"] call _assert;
private _portOwners = createHashMap;
private _uniquePortOwners = true;
{
    private _sources = if ((_x get "type") == "port") then { [[_x get "id", "port", _x get "objectCount"]] } else {
        (_x getOrDefault ["components", []]) select { (_x select 1) == "port" }
    };
    {
        private _id = _x select 0;
        if (_id in _portOwners) then { _uniquePortOwners = false; };
        _portOwners set [_id, true];
    } forEach _sources;
} forEach _locations;
[_uniquePortOwners && {count _portOwners > 0}, "each original port cluster has only one saved owner"] call _assert;
private _portDemo = [["port"], "", false] execVM "IVCS\demos\map-index.sqf";
waitUntil { scriptDone _portDemo };
[count IVCS_Demo_MapIndexLocations == count (_locations select { "port" in (_x get "types") }) && {count IVCS_Demo_MapIndexLocations > 0}, "port demo filter includes both standalone ports and supporting port roles"] call _assert;
[(IVCS_Demo_MapIndexLocations findIf { (_x get "type") == "town" && {"port" in (_x get "types")} }) >= 0, "saved Altis settlements expose absorbed ports in the port filter"] call _assert;
call compile preprocessFileLineNumbers "IVCS\demos\stop-map-index.sqf";
diag_log format ["[IVCS TASK TEST] ARTIFACTS objects=%1 models=%2 locations=%3", count _records, count _catalog, count _locations];
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2", IVCS_IndexPassed, IVCS_IndexFailed];
