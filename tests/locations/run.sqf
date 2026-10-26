waitUntil { time > 0 };
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
IVCS_IndexPassed = 0;
IVCS_IndexFailed = 0;
private _assert = {
    params ["_ok", "_label"];
    if (_ok) then { IVCS_IndexPassed = IVCS_IndexPassed + 1; } else { IVCS_IndexFailed = IVCS_IndexFailed + 1; };
    diag_log format ["[IVCS TASK TEST] %1 %2", if (_ok) then { "PASS" } else { "FAIL" }, _label];
};
private _settings = call IVCS_Locations_indexSettings;
{
    [(["", _x, _settings] call IVCS_Locations_indexClassify) isEqualTo [], format ["decorative or ambiguous model does not create an objective: %1", _x]] call _assert;
} forEach ["a3\structures_f\ind\powerlines\powerpolewooden_f.p3d", "a3\structures_f\ind\cargo\cargo20_blue_f.p3d", "a3\structures_f\ind\transmitter_tower\tbox_f.p3d"];
[(["", "a3\structures_f\households\stone_big\i_stone_housebig_v1_f.p3d", _settings] call IVCS_Locations_indexClassify) isEqualTo ["town"], "Altis stone houses contribute settlement evidence"] call _assert;
[(["", "a3\structures_f\mil\barracks.p3d", _settings] call IVCS_Locations_indexClassify) isEqualTo ["base"], "model classification works without a config class"] call _assert;
[(["", "unknown.p3d", _settings] call IVCS_Locations_indexClassify) isEqualTo [], "unknown models remain unclassified"] call _assert;
(_settings get "modelOverrides") set ["unknown.p3d", ["power", "base"]];
[(["", "UNKNOWN.P3D", _settings] call IVCS_Locations_indexClassify) isEqualTo ["power", "base"], "exact model overrides support multiple roles and case normalization"] call _assert;
(_settings get "classOverrides") set ["ignoreme", []];
[(["IGNOREME", "unknown.p3d", _settings] call IVCS_Locations_indexClassify) isEqualTo [], "explicit class exclusion takes precedence"] call _assert;
_settings set ["categories", [["town", 60, 4, 130, 3, 10],["radiotower",60,1,130,1,10],["base",60,2,130,1,10]]];
(_settings get "modelOverrides") set ["house.p3d", ["town"]];
(_settings get "modelOverrides") set ["radio.p3d", ["radiotower"]];
(_settings get "modelOverrides") set ["base.p3d", ["base"]];
private _records = [
    ["", "house.p3d", [0,0,0]], ["", "house.p3d", [20,0,0]],
    ["", "house.p3d", [0,20,0]], ["", "house.p3d", [20,20,0]],
    ["", "house.p3d", [300,0,0]], ["", "house.p3d", [320,0,0]],
    ["", "house.p3d", [300,20,0]], ["", "house.p3d", [320,20,0]],
    ["", "radio.p3d", [10,10,0]],
    ["", "base.p3d", [10,10,0]], ["", "base.p3d", [20,10,0]],
    ["", "house.p3d", [1000,0,0]], ["", "unmapped.p3d", [0,0,0]]
];
private _built = [_records, _settings, "TestWorld"] call IVCS_Locations_indexBuild;
private _locations = _built get "locations";
[count _locations == 3, "separate towns remain distinct while the base absorbs its radio site"] call _assert;
[count (_locations select { (_x get "type") == "town" }) == 2, "isolated house does not become a town"] call _assert;
[(_built get "unclassifiedCount") == 1, "catalog reports unmapped evidence"] call _assert;
[(_locations findIf { private _loc = _x; (_loc get "size") <= 0 || {(_loc get "position") select 2 != 0} }) == -1, "locations have usable 2D centers and positive footprints"] call _assert;
private _export = [_locations] call IVCS_Locations_exportLocationsMapData;
private _roundtrip = call compile _export;
[_roundtrip isEqualTo _locations, "export round trip preserves all location metadata"] call _assert;
[(_export find toString [13,10]) >= 0, "export uses CRLF"] call _assert;
private _reversed = +_records;
reverse _reversed;
private _again = [_reversed, _settings, "TestWorld"] call IVCS_Locations_indexBuild;
[(_again get "locations") isEqualTo _locations, "scan order does not change cluster membership or IDs"] call _assert;
private _chain = [];
for "_i" from 0 to 20 do { _chain pushBack ["", "base.p3d", [_i * 50,0,0]]; };
private _bounded = ([_chain, _settings] call IVCS_Locations_indexBuild) get "locations";
[count _bounded > 1 && {(_bounded findIf { (_x get "size") > 140 }) == -1}, "linked objects cannot grow a cluster across the terrain"] call _assert;
[(count (([[], _settings] call IVCS_Locations_indexBuild) get "locations")) == 0, "empty inventory yields no locations"] call _assert;
IVCS_Locations_CurrentMapData = _locations;
[(call compile ([] call IVCS_Locations_exportLocationsMapData)) isEqualTo _locations, "existing no-argument export remains compatible"] call _assert;
private _quoted = ["town",[1,2,0],5] call IVCS_Locations_createLocation;
_quoted set ["name", "O'Brien ""Town"""];
[(call compile ([[_quoted]] call IVCS_Locations_exportLocationsMapData)) isEqualTo [_quoted], "export safely preserves quoted metadata"] call _assert;
// Refinement rules use deterministic fixtures; only the water predicate is substituted.
private _refineSettings = call IVCS_Locations_indexSettings;
private _overrides = _refineSettings get "modelOverrides";
{ _overrides set [_x select 0, _x select 1]; } forEach [
    ["factory.p3d",["factory"]], ["shared.p3d",["factory","base"]],
    ["base.p3d",["base"]], ["power.p3d",["power"]], ["house.p3d",["town"]],
    ["radio.p3d",["radiotower"]], ["fuel.p3d",["fuel"]], ["pier.p3d",["port"]]
];
private _waterRecords = [
    ["","pier.p3d",[0,0,0]], ["","pier.p3d",[20,0,0]],
    ["","pier.p3d",[1000,0,0]], ["","pier.p3d",[1020,0,0]]
];
private _waterBuilt = [_waterRecords, _refineSettings, "TestWorld", { ((_this select 0) select 0) <= 100 }] call IVCS_Locations_indexBuild;
private _ports = (_waterBuilt get "locations") select { (_x get "type") == "port" };
[count _ports == 1 && {(_ports select 0 get "objectCount") == 2}, "water context retains coastal piers and rejects inland reuse of the same model"] call _assert;
[(_waterBuilt get "rejectedPortObjects") == 2 && {(_waterBuilt get "unclassifiedCount") == 2}, "rejected inland port evidence is counted"] call _assert;
[((_waterBuilt get "catalog") select 0 select 2) isEqualTo ["port"], "catalog retains model-level classification before spatial validation"] call _assert;
[([ [0,0,0], 100, 25, { (_this select 0) isEqualTo [50,0,0] } ] call IVCS_Locations_indexNearWater), "water sampling checks surrounding terrain, not only the object origin"] call _assert;
private _compoundRecords = [];
for "_i" from 0 to 18 do { _compoundRecords pushBack ["","factory.p3d",[_i * 2,0,0]]; };
_compoundRecords pushBack ["","shared.p3d",[38,0,0]];
private _factoryCore = +_compoundRecords;
{ _compoundRecords pushBack ["","base.p3d",[_x,0,0]]; } forEach [55,60];
_compoundRecords pushBack ["","power.p3d",[70,0,0]];
for "_i" from 0 to 5 do { _compoundRecords pushBack ["","house.p3d",[90 + _i * 5,0,0]]; };
// Within 100 m of absorbed housing, but outside 100 m of the original factory core.
_compoundRecords pushBack ["","radio.p3d",[200,0,0]];
{ _compoundRecords pushBack ["","power.p3d",[_x,0,0]]; } forEach [1000,1500,1520];
{ _compoundRecords pushBack ["","fuel.p3d",[_x,0,0]]; } forEach [2000,2080,2165];
private _refined = ([_compoundRecords, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations";
private _factory = (_refined select { (_x get "type") == "factory" }) select 0;
[count _refined == 4 && {(_factory get "objectCount") == 29}, "dominant compound absorbs nearby small functions with shared objects counted once"] call _assert;
[(_factory get "types") isEqualTo ["factory","power","town"] && {count (_factory get "components") == 4}, "industrial compound reports housing while preserving original component identities"] call _assert;
[(_factory get "typeCounts") isEqualTo [["factory",20],["power",1],["town",9]], "role evidence survives consolidation, including a lone supporting power object"] call _assert;
private _modelTotal = 0;
{ _modelTotal = _modelTotal + (_x select 1); } forEach (_factory get "models");
[_modelTotal == 29 && {isNil {_factory get "_members"}} && {isNil {_factory get "_minimum"}}, "exported compound has unique model counts and no internal clustering state"] call _assert;
[(_compoundRecords select [0,29] findIf { (_x select 2) distance2D (_factory get "position") > (_factory get "size") }) == -1, "compound footprint contains all absorbed evidence"] call _assert;
[count (_refined select { (_x get "type") == "radiotower" }) == 1, "absorbed components cannot create a chain of further merges"] call _assert;
private _power = _refined select { (_x get "type") == "power" };
[count _power == 1 && {(_power select 0 get "objectCount") == 2}, "standalone power needs two objects; isolated singleton is removed"] call _assert;
private _fuel = _refined select { (_x get "type") == "fuel" };
[count _fuel == 1 && {(_fuel select 0 get "objectCount") == 3}, "nearby fuel evidence spanning 165 m forms a single site"] call _assert;
reverse _compoundRecords;
[(([_compoundRecords, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") isEqualTo _refined, "compound membership and metadata are independent of input order"] call _assert;
private _separateRecords = +_factoryCore;
{ _separateRecords pushBack ["","base.p3d",[_x,0,0]]; } forEach [100,260,420];
for "_i" from 0 to 20 do { _separateRecords pushBack ["","house.p3d",[100 + _i * 2,0,0]]; };
private _factoryHostSettings = call IVCS_Locations_indexSettings;
_factoryHostSettings set ["modelOverrides",_overrides];
(_factoryHostSettings get "compounds") set ["primaryTypes",["factory"]];
private _separate = ([_separateRecords, _factoryHostSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations";
[count _separate == 2 && {(_separate findIf { (_x get "type") == "factory" && {(_x get "objectCount") == 41} }) >= 0}, "spatially eligible housing joins industry regardless of its twenty-one-object count"] call _assert;
[(_separate findIf { (_x get "type") == "base" && {(_x get "objectCount") == 4} }) >= 0, "a touching secondary cluster extending too far from the core remains separate"] call _assert;
private _equalRecords = [];
for "_i" from 0 to 9 do {
    _equalRecords pushBack ["","factory.p3d",[_i * 2,0,0]];
    _equalRecords pushBack ["","base.p3d",[50 + _i * 2,0,0]];
};
[count (([_equalRecords, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") == 1, "compatible nearby facilities can merge without a half-size requirement"] call _assert;
// Secondary-role classification and military support behavior.
{
    _x params ["_model", "_expected", "_label"];
    [(["", _model, _refineSettings] call IVCS_Locations_indexClassify) isEqualTo _expected, _label] call _assert;
} forEach [
    ["a3\structures_f\mil\radar\radar_f.p3d",["base","radar"],"large radar dome grants military and radar evidence"],
    ["a3\structures_f\mil\radar\radar_small_f.p3d",["base","radar"],"small radar dome grants military and radar evidence"],
    ["a3\structures_f\mil\helipads\helipadsquare_f.p3d",["heli"],"helipads provide only a secondary heli role"],
    ["a3\roads_f\runway\runwaylights\runway_papi.p3d",["airfield","air"],"runway landing guidance provides air evidence"],
    ["a3\structures_f\ind\airport\landmark_f.p3d",["air"],"runway boundary markers provide secondary air evidence"],
    ["a3\roads_f\runway\invisibleroadway_square_f.p3d",["airfield"],"generic apron paving does not prove a runway"],
    ["a3\roads_f\runway\runwaylights\runway_edgelight_blue_f.p3d",["airfield"],"taxiway lights do not prove a runway"],
    ["a3\structures_f\mil\tenthangar\tenthangar_v1_f.p3d",["airfield","base"],"tent hangars retain internal airfield and military classification"]
];
private _militaryRecords = [["","base.p3d",[0,0,0]],["","base.p3d",[20,0,0]]];
{ _militaryRecords pushBack ["","radio.p3d",[_x,0,0]]; } forEach [40,50,60];
{ _militaryRecords pushBack ["","power.p3d",[_x,0,0]]; } forEach [70,80,90,100];
private _military = ([_militaryRecords, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations";
[count _military == 1 && {(_military select 0 get "type") == "base"} && {(_military select 0 get "objectCount") == 9} && {(_military select 0 get "types") isEqualTo ["base","power","radiotower"]}, "two-object military base absorbs larger small radio and power sites"] call _assert;
reverse _militaryRecords;
[(([_militaryRecords, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") isEqualTo _military, "military support ownership is independent of scan order"] call _assert;
private _sharedSupport = [
    ["","base.p3d",[0,0,0]], ["","base.p3d",[10,0,0]],
    ["","base.p3d",[200,0,0]], ["","base.p3d",[210,0,0]],
    ["","radio.p3d",[100,0,0]]
];
private _owned = ([_sharedSupport, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations";
[count _owned == 2 && {(_owned select 0 get "types") isEqualTo ["base","radiotower"]} && {(_owned select 1 get "types") isEqualTo ["base"]}, "radio site shared by two eligible bases is absorbed once by the closest base"] call _assert;
private _limited = [["","base.p3d",[0,0,0]],["","base.p3d",[10,0,0]],["","radio.p3d",[80,0,0]],["","power.p3d",[270,0,0]],["","power.p3d",[280,0,0]]];
private _limitedBuilt = ([_limited, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations";
[count _limitedBuilt == 2 && {(_limitedBuilt findIf { (_x get "type") == "power" }) >= 0}, "radio absorption cannot extend military support reach to a distant power site"] call _assert;
private _largePower = [["","base.p3d",[0,0,0]],["","base.p3d",[10,0,0]]];
for "_i" from 0 to 20 do { _largePower pushBack ["","power.p3d",[30 + _i,0,0]]; };
private _supportOnly = call IVCS_Locations_indexSettings;
_supportOnly set ["modelOverrides", _overrides];
(_supportOnly get "compounds") set ["enabled", false];
[count (([_largePower, _supportOnly, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") == 1, "military support uses geometry rather than a twenty-object power cap"] call _assert;
private _domeModel = "a3\structures_f\mil\radar\radar_f.p3d";
private _heliModel = "a3\structures_f\mil\helipads\helipadsquare_f.p3d";
private _runwayModel = "a3\roads_f\runway\runwaylights\runway_papi.p3d";
private _radarSite = (([[["","base.p3d",[0,0,0]],["",_domeModel,[20,0,0]]], _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") select 0;
[(_radarSite get "types") isEqualTo ["base","radar"] && {(_radarSite get "objectCount") == 2} && {(_radarSite get "typeCounts") isEqualTo [["base",2],["radar",1]]}, "radar dome is counted once and grants its military base a secondary radar role"] call _assert;
private _roleRecords = [
    ["","factory.p3d",[0,0,0]], ["","factory.p3d",[20,0,0]], ["","factory.p3d",[0,20,0]],
    ["",_heliModel,[10,10,0]], ["",_runwayModel,[10,20,0]],
    ["",_heliModel,[80,0,0]], ["",_heliModel,[1000,0,0]]
];
// Isolate annotation behavior: an actual runway now forms a mergeable military airfield.
private _annotationSettings = call IVCS_Locations_indexSettings;
private _annotationOverrides = createHashMap;
{ _annotationOverrides set [_x,_overrides get _x]; } forEach keys _overrides;
_annotationOverrides set [_runwayModel,["air"]];
_annotationSettings set ["modelOverrides",_annotationOverrides];
private _roleSites = ([_roleRecords, _annotationSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations";
private _roleFactory = (_roleSites select { (_x get "type") == "factory" }) select 0;
[(_roleFactory get "types") isEqualTo ["air","factory","heli"] && {(_roleFactory get "objectCount") == 5}, "any site can gain heli and air roles from evidence inside its footprint"] call _assert;
[(_roleFactory get "typeCounts") isEqualTo [["air",1],["factory",3],["heli",1]], "nearby outside helipads do not leak into the site or extend attachment reach"] call _assert;
[count (([[["",_heliModel,[0,0,0]]], _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") == 0, "a standalone helipad does not create a site"] call _assert;
private _sparse = [["","factory.p3d",[0,0,0]],["","factory.p3d",[20,0,0]],["",_heliModel,[10,0,0]]];
[count (([_sparse, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") == 0, "secondary-only evidence cannot satisfy the minimum for a primary site"] call _assert;
private _hangarOnly = (([[["","a3\structures_f\mil\tenthangar\tenthangar_v1_f.p3d",[0,0,0]]], _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") select 0;
[(_hangarOnly get "type") == "base" && {(_hangarOnly get "types") isEqualTo ["air","base"]}, "every classified airfield is a military base with air even without runway evidence"] call _assert;
private _roleMarkers = [[_roleFactory], "IVCS_RoleTest"] call IVCS_Locations_indexPreview;
private _roleLabel = markerText (_roleMarkers select 1);
[(_roleLabel find "[heli]") >= 0 && {(_roleLabel find "[air]") >= 0}, "preview labels show literal heli and air badges"] call _assert;
{ deleteMarkerLocal _x; } forEach _roleMarkers;
// Industrial role interpretation is contextual and counts each housing object once.
_overrides set ["dual_housing.p3d", ["factory","base","town"]];
private _housingOverlap = +_factoryCore;
_housingOverlap set [19, ["","dual_housing.p3d",[38,0,0]]];
private _housingSite = (([_housingOverlap, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") select 0;
[(_housingSite get "types") isEqualTo ["factory","town"] && {(_housingSite get "typeCounts") isEqualTo [["factory",20],["town",1]]} && {(_housingSite get "objectCount") == 20}, "industrial military-to-housing remap deduplicates existing housing evidence"] call _assert;
[(["","dual_housing.p3d",_refineSettings] call IVCS_Locations_indexClassify) isEqualTo ["factory","base","town"], "contextual housing remap does not change global model classification"] call _assert;
private _housingOnly = +_factoryCore;
_housingOnly pushBack ["","base.p3d",[55,0,0]];
private _housingOnlySite = (([_housingOnly, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") select 0;
[(_housingOnlySite get "typeCounts") isEqualTo [["factory",20],["town",2]] && {count (_housingOnlySite get "components") == 2}, "industrial site gains housing even when all housing evidence originated as military"] call _assert;
private _housingMarkers = [[_housingOnlySite], "IVCS_HousingTest"] call IVCS_Locations_indexPreview;
private _housingLabel = markerText (_housingMarkers select 1);
[(_housingLabel find "housing") >= 0 && {(_housingLabel find "military") < 0}, "industrial label describes remapped military structures as housing"] call _assert;
{ deleteMarkerLocal _x; } forEach _housingMarkers;
private _industrialRadar = [];
for "_i" from 0 to 19 do { _industrialRadar pushBack ["","factory.p3d",[_i * 2,0,0]]; };
{ _industrialRadar pushBack ["",_domeModel,[_x,0,0]]; } forEach [50,60];
private _industrialRadarSite = (([_industrialRadar, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") select 0;
[(_industrialRadarSite get "types") isEqualTo ["factory","radar","town"], "housing reinterpretation retains actual radar evidence"] call _assert;
// Fuel support applies to civilian settlements and military bases of any valid size.
private _houses = [];
for "_i" from 0 to 5 do { _houses pushBack ["","house.p3d",[_i * 5,0,0]]; };
private _civilianFuel = +_houses;
{ _civilianFuel pushBack ["","fuel.p3d",[_x,0,0]]; } forEach [50,65,80,400,420];
private _civilianSites = ([_civilianFuel, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations";
private _civilianSite = (_civilianSites select { (_x get "type") == "town" }) select 0;
[count _civilianSites == 2 && {(_civilianSite get "objectCount") == 9} && {(_civilianSite get "typeCounts") isEqualTo [["fuel",3],["town",6]]}, "six-object civilian settlement absorbs nearby fuel as a secondary role"] call _assert;
[(_civilianSites findIf { (_x get "type") == "fuel" && {(_x get "objectCount") == 2} }) >= 0, "distant fuel station remains independent"] call _assert;
private _militaryFuel = [["","base.p3d",[0,0,0]],["","base.p3d",[20,0,0]],["","fuel.p3d",[70,0,0]],["","fuel.p3d",[80,0,0]]];
private _militaryFuelSites = ([_militaryFuel, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations";
[count _militaryFuelSites == 1 && {(_militaryFuelSites select 0 get "types") isEqualTo ["base","fuel"]} && {(_militaryFuelSites select 0 get "objectCount") == 4}, "two-object military base absorbs fuel without a dominance ratio requirement"] call _assert;
private _competingFuel = +_houses;
_competingFuel append [["","base.p3d",[150,0,0]],["","base.p3d",[160,0,0]],["","fuel.p3d",[90,0,0]]];
private _competition = ([_competingFuel, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations";
[count _competition == 2 && {(_competition findIf { (_x get "type") == "base" && {"fuel" in (_x get "types")} }) >= 0} && {(_competition findIf { (_x get "type") == "town" && {"fuel" in (_x get "types")} }) == -1}, "closer military base wins fuel ownership over an eligible civilian settlement"] call _assert;
_competingFuel set [8, ["","fuel.p3d",[70,0,0]]];
private _civilianWins = ([_competingFuel, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations";
[count _civilianWins == 2 && {(_civilianWins findIf { (_x get "type") == "town" && {"fuel" in (_x get "types")} }) >= 0} && {(_civilianWins findIf { (_x get "type") == "base" && {"fuel" in (_x get "types")} }) == -1}, "closer civilian settlement wins fuel ownership over an eligible base"] call _assert;
reverse _competingFuel;
[(([_competingFuel, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") isEqualTo _civilianWins, "fuel ownership and role counts are independent of inventory ordering"] call _assert;
private _fuelChain = [["","base.p3d",[0,0,0]],["","base.p3d",[10,0,0]],["","radio.p3d",[90,0,0]],["","fuel.p3d",[180,0,0]]];
private _fuelChainSites = ([_fuelChain, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations";
[count _fuelChainSites == 2 && {(_fuelChainSites findIf { (_x get "type") == "fuel" }) >= 0}, "absorbed military support cannot bridge to an otherwise distant fuel station"] call _assert;
private _largeFuel = [["","base.p3d",[0,0,0]],["","base.p3d",[10,0,0]]];
for "_i" from 0 to 20 do { _largeFuel pushBack ["","fuel.p3d",[30 + _i,0,0]]; };
[count (([_largeFuel, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") == 1, "fuel support uses geometry rather than a twenty-object fuel cap"] call _assert;
private _longFuel = +_houses;
{ _longFuel pushBack ["","fuel.p3d",[_x,0,0]]; } forEach [90,210,330];
[count (([_longFuel, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") == 2, "a touching fuel cluster extending beyond the support radius remains separate"] call _assert;
private _nestedFuel = +_factoryCore;
_nestedFuel append [["","base.p3d",[55,0,0]],["","fuel.p3d",[70,0,0]]];
private _nestedFuelSite = (([_nestedFuel, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") select 0;
[(_nestedFuelSite get "typeCounts") isEqualTo [["factory",20],["fuel",1],["town",2]] && {(_nestedFuelSite get "objectCount") == 22} && {count (_nestedFuelSite get "components") == 3}, "fuel survives absorption of its military host into an industrial housing compound"] call _assert;
// Internal military building uses do not change strategic site roles or labels.
private _buildingRules = _refineSettings get "militaryBuildings";
private _barracksModel = "a3\structures_f\mil\barracks\i_barracks_v1_f.p3d";
private _cargoHouseModel = "a3\structures_f\mil\cargo\cargo_house_v1_f.p3d";
private _patrolModel = "a3\structures_f\mil\cargo\cargo_patrol_v1_f.p3d";
private _towerModel = "a3\structures_f\mil\cargo\cargo_tower_v1_f.p3d";
{
    _x params ["_model", "_expected"];
    [(["", _model, _buildingRules] call IVCS_Locations_indexClassify) isEqualTo _expected, format ["military building use: %1", _model]] call _assert;
} forEach [
    [_barracksModel,["barracks"]], [_cargoHouseModel,["barracks"]],
    [_patrolModel,["fortification"]], [_towerModel,["fortification"]],
    ["a3\structures_f\mil\bagbunker\bagbunker_small_f.p3d",["fortification"]],
    ["a3\structures_f_exp\military\pillboxes\pillboxbunker_01_hex_f.p3d",["fortification"]],
    ["a3\structures_f_argo\military\bunkers\bunker_01_small_f.p3d",["fortification"]],
    ["a3\structures_f\mil\cargo\cargo_patrol_v3_ruins_f.p3d",[]],
    ["a3\structures_f\mil\cargo\cargo_hq_v1_f.p3d",[]],
    ["a3\structures_f\mil\bunker\bunker_f.p3d",[]],
    ["a3\structures_f\mil\fortification\hbarrier_5_f.p3d",[]],
    [_domeModel,[]]
];
private _buildingRecords = [
    ["LAND_I_BARRACKS_V1_F",_barracksModel,[0,0,0]],
    ["",_cargoHouseModel,[10,0,0]], ["",_patrolModel,[20,0,0]],
    ["",_towerModel,[30,0,0]], ["",_domeModel,[40,0,0]],
    ["","radio.p3d",[50,0,0]], ["",_heliModel,[20,10,0]]
];
private _buildingSite = (([_buildingRecords, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") select 0;
[(_buildingSite get "militaryBuildingCounts") isEqualTo [["barracks",2],["fortification",2]], "military accommodation and fighting structures have separate internal counts"] call _assert;
[(_buildingSite get "militaryBuildings") isEqualTo [
    ["barracks","land_i_barracks_v1_f",_barracksModel,[0,0,0]],
    ["barracks","",_cargoHouseModel,[10,0,0]],
    ["fortification","",_patrolModel,[20,0,0]],
    ["fortification","",_towerModel,[30,0,0]]
], "internal military metadata retains each classified structure's identity and map position"] call _assert;
[(_buildingSite get "types") isEqualTo ["base","heli","radar","radiotower"] && {(_buildingSite get "objectCount") == 7}, "building subtypes neither become site roles nor double-count site members"] call _assert;
reverse _buildingRecords;
[(([_buildingRecords, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations" select 0) isEqualTo _buildingSite, "internal military metadata is independent of inventory order"] call _assert;
[(call compile ([[_buildingSite]] call IVCS_Locations_exportLocationsMapData)) isEqualTo [_buildingSite], "building positions and subtype metadata survive saved SQF round trip"] call _assert;
private _internalMarkers = [[_buildingSite], "IVCS_BuildingTest"] call IVCS_Locations_indexPreview;
private _internalLabel = markerText (_internalMarkers select 1);
[(_internalLabel find "barracks") < 0 && {(_internalLabel find "fortification") < 0}, "internal building uses do not add map label badges"] call _assert;
{ deleteMarkerLocal _x; } forEach _internalMarkers;
private _industrialBuildings = +_factoryCore;
_industrialBuildings append [["",_barracksModel,[50,0,0]],["",_patrolModel,[60,0,0]]];
private _industrialBuildingSite = (([_industrialBuildings, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") select 0;
[!("base" in (_industrialBuildingSite get "types")) && {isNil {_industrialBuildingSite get "militaryBuildings"}}, "industrial housing remap does not expose active military building metadata"] call _assert;
[(_radarSite get "militaryBuildingCounts") isEqualTo [["barracks",0],["fortification",0]], "military sites without either building use report zero rather than guessing"] call _assert;
private _overrideSettings = call IVCS_Locations_indexSettings;
private _overrideBuildings = _overrideSettings get "militaryBuildings";
(_overrideSettings get "modelOverrides") set ["custom.p3d",["base","airfield"]];
(_overrideBuildings get "modelOverrides") set ["custom.p3d",["barracks"]];
(_overrideBuildings get "classOverrides") set ["custom_post",["fortification"]];
private _customBuildings = [["CUSTOM_POST","custom.p3d",[0,0,0]],["","custom.p3d",[10,0,0]]];
private _customSite = (([_customBuildings, _overrideSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") select 0;
[(_customSite get "militaryBuildingCounts") isEqualTo [["barracks",1],["fortification",1]], "building class override takes precedence over model override for other terrains"] call _assert;
(_overrideSettings get "classOverrides") set ["custom_post",["town"]];
private _customCivilian = (([_customBuildings, _overrideSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") select 0;
[(_customCivilian get "militaryBuildingCounts") isEqualTo [["barracks",1],["fortification",0]], "building use override cannot turn civilian evidence into a military member"] call _assert;
// Turbines cannot seed, grow, bridge, or provide secondary power evidence.
private _turbineModel = "a3\structures_f\ind\windpowerplant\wpp_turbine_v1_f.p3d";
private _windRecords = [["",_turbineModel,[0,0,0]],["",_turbineModel,[20,0,0]]];
private _windBuilt = [_windRecords, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild;
[(_windBuilt get "locations") isEqualTo [] && {(_windBuilt get "unclassifiedCount") == 2} && {count (_windBuilt get "catalog") == 1}, "wind farm produces no power objective while remaining in the catalog"] call _assert;
_windRecords pushBack ["","power.p3d",[40,0,0]];
[count (([_windRecords, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") == 0, "turbines cannot satisfy a power site's two-object minimum"] call _assert;
private _baseWithoutWind = ([_militaryFuel, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations";
private _baseWithWind = +_militaryFuel;
_baseWithWind append [["",_turbineModel,[30,0,0]],["",_turbineModel,[40,0,0]]];
[(([_baseWithWind, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations") isEqualTo _baseWithoutWind, "nearby turbines cannot add secondary power, change footprint, or count toward a base"] call _assert;
// Small piers are excluded by either class identity or model, even at the coast.
private _smallPierModel = "a3\structures_f\naval\piers\pier_small_f.p3d";
[(["LAND_PIER_SMALL_F","custom\pier.p3d",_refineSettings] call IVCS_Locations_indexClassify) isEqualTo [], "small-pier class is excluded regardless of its model path"] call _assert;
[(["",toUpper _smallPierModel,_refineSettings] call IVCS_Locations_indexClassify) isEqualTo [], "small-pier model is excluded even without a class"] call _assert;
private _smallPiers = [["",_smallPierModel,[0,0,0]],["Land_Pier_small_F",_smallPierModel,[20,0,0]]];
private _smallPierBuilt = [_smallPiers, _refineSettings, "TestWorld", {true}] call IVCS_Locations_indexBuild;
[(_smallPierBuilt get "locations") isEqualTo [] && {(_smallPierBuilt get "unclassifiedCount") == 2}, "coastal small piers cannot create a port"] call _assert;
_smallPiers pushBack ["","pier.p3d",[30,0,0]];
[count (([_smallPiers, _refineSettings, "TestWorld", {true}] call IVCS_Locations_indexBuild) get "locations") == 0, "small piers cannot satisfy the port minimum alongside one genuine pier"] call _assert;
// Ports follow the same bounded support ownership as fuel.
private _civilianPort = +_houses;
{ _civilianPort pushBack ["","pier.p3d",[_x,0,0]]; } forEach [60,75,90,500,520];
private _civilianPortSites = ([_civilianPort, _refineSettings, "TestWorld", {true}] call IVCS_Locations_indexBuild) get "locations";
private _portTown = (_civilianPortSites select { (_x get "type") == "town" }) select 0;
[count _civilianPortSites == 2 && {(_portTown get "typeCounts") isEqualTo [["port",3],["town",6]]} && {(_portTown get "objectCount") == 9}, "settlement absorbs its nearby port and leaves the distant port independent"] call _assert;
private _militaryPort = [["","base.p3d",[0,0,0]],["","base.p3d",[10,0,0]],["","pier.p3d",[60,0,0]],["","pier.p3d",[70,0,0]]];
private _militaryPortSites = ([_militaryPort, _refineSettings, "TestWorld", {true}] call IVCS_Locations_indexBuild) get "locations";
[count _militaryPortSites == 1 && {(_militaryPortSites select 0 get "type") == "base"} && {(_militaryPortSites select 0 get "typeCounts") isEqualTo [["base",2],["port",2]]}, "small military base absorbs a port without a dominance ratio"] call _assert;
private _dryPortSites = ([_militaryPort, _refineSettings, "TestWorld", {false}] call IVCS_Locations_indexBuild) get "locations";
[count _dryPortSites == 1 && {(_dryPortSites select 0 get "types") isEqualTo ["base"]}, "inland pier evidence cannot become an absorbed port"] call _assert;
private _competingPort = +_houses;
_competingPort append [["","base.p3d",[200,0,0]],["","base.p3d",[210,0,0]],["","pier.p3d",[120,0,0]],["","pier.p3d",[130,0,0]]];
private _portCompetition = ([_competingPort, _refineSettings, "TestWorld", {true}] call IVCS_Locations_indexBuild) get "locations";
[count _portCompetition == 2 && {(_portCompetition findIf { (_x get "type") == "base" && {"port" in (_x get "types")} }) >= 0} && {(_portCompetition findIf { (_x get "type") == "town" && {"port" in (_x get "types")} }) == -1}, "closest eligible civilian or military core owns each port once"] call _assert;
reverse _competingPort;
[(([_competingPort, _refineSettings, "TestWorld", {true}] call IVCS_Locations_indexBuild) get "locations") isEqualTo _portCompetition, "port ownership is independent of input order"] call _assert;
private _longPort = [["","base.p3d",[0,0,0]],["","base.p3d",[10,0,0]]];
{ _longPort pushBack ["","pier.p3d",[_x,0,0]]; } forEach [80,230,380];
[count (([_longPort, _refineSettings, "TestWorld", {true}] call IVCS_Locations_indexBuild) get "locations") == 2, "a port extending beyond the member-distance limit remains independent"] call _assert;
private _largePort = [["","base.p3d",[0,0,0]],["","base.p3d",[10,0,0]]];
for "_i" from 0 to 20 do { _largePort pushBack ["","pier.p3d",[40 + _i,0,0]]; };
[count (([_largePort, _supportOnly, "TestWorld", {true}] call IVCS_Locations_indexBuild) get "locations") == 1, "port support uses geometry rather than a twenty-object port cap"] call _assert;
private _portChain = [["","base.p3d",[0,0,0]],["","base.p3d",[10,0,0]],["","radio.p3d",[90,0,0]],["","pier.p3d",[180,0,0]],["","pier.p3d",[190,0,0]]];
[count (([_portChain, _refineSettings, "TestWorld", {true}] call IVCS_Locations_indexBuild) get "locations") == 2, "absorbed radio support cannot bridge to a distant port"] call _assert;
private _portMarkers = [[_portTown], "IVCS_PortTest"] call IVCS_Locations_indexPreview;
[(markerText (_portMarkers select 1) find "(+ port)") >= 0, "settlement label retains its absorbed port role"] call _assert;
{ deleteMarkerLocal _x; } forEach _portMarkers;
// Airfields keep broad spatial clustering but always export as military bases with air.
private _airportOnly = [
    ["","a3\structures_f\ind\airport\hangar_f.p3d",[0,0,0]],
    ["","a3\roads_f\runway\invisibleroadway_square_f.p3d",[500,0,0]]
];
private _airportSites = ([_airportOnly, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations";
private _airport = _airportSites select 0;
[count _airportSites == 1 && {(_airport get "type") == "base"} && {(_airport get "typeCounts") isEqualTo [["air",2],["base",2]]} && {(_airport get "objectCount") == 2}, "non-runway airfield objects retain wide clustering and imply base plus air once per member"] call _assert;
[(_airport get "militaryBuildingCounts") isEqualTo [["barracks",0],["fortification",0]], "new airfield military identity exposes empty building metadata without inventing barracks"] call _assert;
private _airSupportRecords = [_airportOnly select 0];
_airSupportRecords append [["","radio.p3d",[20,0,0]],["","power.p3d",[30,0,0]],["","power.p3d",[40,0,0]],["","fuel.p3d",[50,0,0]],["","pier.p3d",[60,0,0]],["","pier.p3d",[70,0,0]]];
private _airSupport = ([_airSupportRecords, _refineSettings, "TestWorld", {true}] call IVCS_Locations_indexBuild) get "locations";
[count _airSupport == 1 && {(_airSupport select 0 get "types") isEqualTo ["air","base","fuel","port","power","radiotower"]} && {(_airSupport select 0 get "objectCount") == 7}, "airfield military identity participates in radio, power, fuel and port support ownership"] call _assert;
[(_airSupport select 0 get "components" findIf { (_x select 1) == "airfield" }) >= 0, "compound provenance retains its original airfield component"] call _assert;
private _airCompound = +_factoryCore;
_airCompound pushBack ["","a3\structures_f\ind\airport\hangar_f.p3d",[50,0,0]];
private _airCompoundSites = ([_airCompound, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations";
[count _airCompoundSites == 1 && {(_airCompoundSites select 0 get "type") == "base"} && {(_airCompoundSites select 0 get "types") isEqualTo ["air","base","factory"]}, "absorbing an airfield into a compound preserves military primary identity and the air role"] call _assert;
private _dualAirport = [["","a3\structures_f\mil\tenthangar\tenthangar_v1_f.p3d",[0,0,0]],["","a3\structures_f\mil\tenthangar\tenthangar_v1_f.p3d",[20,0,0]]];
private _dualAirportSites = ([_dualAirport, _refineSettings, "TestWorld"] call IVCS_Locations_indexBuild) get "locations";
[count _dualAirportSites == 1 && {(_dualAirportSites select 0 get "typeCounts") isEqualTo [["air",2],["base",2]]} && {(_dualAirportSites select 0 get "objectCount") == 2}, "shared airfield and base members produce one military site with deduplicated evidence"] call _assert;
reverse _airSupportRecords;
[(([_airSupportRecords, _refineSettings, "TestWorld", {true}] call IVCS_Locations_indexBuild) get "locations") isEqualTo _airSupport, "airfield support and military normalization are deterministic"] call _assert;
private _airMarkers = [[_airport], "IVCS_AirfieldTest"] call IVCS_Locations_indexPreview;
private _airLabel = markerText (_airMarkers select 1);
[(_airLabel find "Military base") == 0 && {(_airLabel find "[air]") >= 0} && {(_airLabel find "Airfield") < 0}, "airfield preview uses military styling and an air badge"] call _assert;
{ deleteMarkerLocal _x; } forEach _airMarkers;
// Compare adjacent scanner tiles to one large tile in a real Altis built-up area.
private _scanSettings = call IVCS_Locations_indexSettings;
_scanSettings set ["tileSize", 250];
private _small = [_scanSettings, [14250,16000,15000,16500]] call IVCS_Locations_indexScan;
_scanSettings set ["tileSize", 1000];
private _large = [_scanSettings, [14250,16000,15000,16500]] call IVCS_Locations_indexScan;
private _smallKeys = _small apply { str _x };
private _largeKeys = _large apply { str _x };
_smallKeys sort true;
_largeKeys sort true;
[count _small > 0, "native terrain scan discovers Altis structures"] call _assert;
[_smallKeys isEqualTo _largeKeys, "tile boundaries neither lose nor duplicate objects"] call _assert;
private _native = [_small, _scanSettings] call IVCS_Locations_indexBuild;
[count (_native get "catalog") > 0, "native model catalog includes evidence for review"] call _assert;
// Exercise the OPCOM hash-map path without requiring CBA in this vanilla test mission.
CBA_fnc_createNamespace = { createLocation ["NameLocal", [0,0,0], 0, 0] };
private _objective = [_locations select 0] call IVCS_OPCOM_createObjectiveFromLocation;
[(_objective getVariable "position") isEqualTo ((_locations select 0) get "position"), "OPCOM reads newly indexed hash-map locations"] call _assert;
deleteLocation _objective;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2", IVCS_IndexPassed, IVCS_IndexFailed];
