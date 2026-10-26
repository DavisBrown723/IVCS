// Run: powershell -File tests/tasks/run.ps1 -TestScript tests/virtualization/run.sqf -Port 2493 -TimeoutSeconds 120
waitUntil { time > 0 };
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
IVCS_Virtual_TestPassed = 0;
IVCS_Virtual_TestFailed = 0;
private _assert = {
    params ["_ok", "_label"];
    if (_ok) then { IVCS_Virtual_TestPassed = IVCS_Virtual_TestPassed + 1; } else {
        IVCS_Virtual_TestFailed = IVCS_Virtual_TestFailed + 1;
    };
    diag_log format ["[IVCS TASK TEST] %1 %2", if (_ok) then { "PASS" } else { "FAIL" }, _label];
};
IVCS_Common_WeaponInfo = createHashMap;
IVCS_Common_MagazineInfo = createHashMap;
IVCS_Common_AmmoInfo = createHashMap;
IVCS_Common_UnitInfo = createHashMap;
IVCS_Common_WeaponAliases = createHashMap;
IVCS_Common_VehicleConfigInventories = createHashMap;
IVCS_Common_VehicleTurrets = [] call IVCS_Common_getAllVehicleTurretsFromConfig;
IVCS_Paths_Generator = createHashMapFromArray [["requestQueue", []], ["currentRequest", []]];
IVCS_VirtualSpace_Controller = createHashMapFromArray [
    ["combat", [] call IVCS_Combat_createController],
    ["debug", false], ["nextEntityID", 0], ["nextWaypointId", 100],
    ["entities", createHashMapFromArray [["ALL", createHashMap], ["active", []], ["inactive", []]]],
    ["entitiesSpacialGrid", [[-4000, -4000], worldSize + 8000, 600] call IVCS_SpacialGrid_create]
];
private _registry = IVCS_VirtualSpace_Controller get "entities";
private _createGroup = {
    params ["_position", ["_class", "C_man_1"], ["_count", 1]];
    private _units = [];
    for "_i" from 0 to (_count - 1) do {
        _units pushBack ([_class, format ["u_%1", _i]] call IVCS_VirtualSpace_Group_createUnit);
    };
    ["WEST", "BLU_F", +_position, _units] call IVCS_VirtualSpace_Group_createEntity
};
private _createVehicle = {
    params ["_class", "_position"];
    [_class, +_position] call IVCS_VirtualSpace_Vehicle_createEntity
};
private _cleanGroup = {
    params ["_entity"];
    if (_entity get "active") then { [_entity] call IVCS_VirtualSpace_Group_despawn; };
    [_entity] call IVCS_VirtualSpace_unregisterEntity;
};
private _cleanVehicle = {
    params ["_entity"];
    if (_entity get "active") then { [_entity] call IVCS_VirtualSpace_Vehicle_despawn; };
    private _object = _entity get "object";
    [_entity] call IVCS_VirtualSpace_unregisterEntity;
    deleteVehicle _object;
};
private _ammoSnapshot = {
    params ["_object"];
    private _snapshot = (magazinesAllTurrets [_object, true]) apply { _x select [0, 3] };
    _snapshot sort true;
    _snapshot
};

// The former capture loop is bounded so a regression cannot hang the test server.
private _rifleGroup = createGroup west;
private _rifleman = _rifleGroup createUnit ["B_Soldier_F", [14500, 16400, 0], [], 0, "NONE"];
_rifleman removeWeapon "hgun_P07_F";
_rifleman addMagazine ["16Rnd_9x21_Mag", 5];
_rifleman addWeapon "hgun_P07_F";
_rifleman setAmmo [primaryWeapon _rifleman, 11];
_rifleman setAmmo ["hgun_P07_F", 5];
IVCS_Virtual_Captured = nil;
private _capture = [_rifleman] spawn {
    IVCS_Virtual_Captured = [_this select 0] call IVCS_Common_getUnitObjectLoadoutInfo;
};
private _deadline = diag_tickTime + 2;
waitUntil { scriptDone _capture || { diag_tickTime >= _deadline } };
private _captureDone = scriptDone _capture;
if (!_captureDone) then { terminate _capture; };
[_captureDone && { !isNil "IVCS_Virtual_Captured" }, "armed capture terminates"] call _assert;
if (_captureDone && { !isNil "IVCS_Virtual_Captured" }) then {
    private _pistol = IVCS_Virtual_Captured select { (_x select 0) == "hgun_P07_F" };
    [(_pistol select 0 select 1) findIf { (_x select 1) == 5 } != -1, "capture includes loaded unselected pistol"] call _assert;
};
deleteVehicle _rifleman;
deleteGroup _rifleGroup;
if (!_captureDone) exitWith {
    diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2", IVCS_Virtual_TestPassed, IVCS_Virtual_TestFailed];
};

// Exercise real armed group despawn/respawn, rather than empty weapon fixtures.
private _rifleEntity = [[14500, 16410, 0], "B_Soldier_F"] call _createGroup;
[_rifleEntity] call IVCS_VirtualSpace_Group_spawn;
private _unit = ((_rifleEntity get "units") select 0) get "object";
_unit setAmmo [primaryWeapon _unit, 11];
_unit addWeapon "Binocular";
private _weapon = primaryWeapon _unit;
private _loadout = [_unit] call IVCS_Common_getUnitObjectLoadoutInfo;
[([_weapon] call IVCS_Common_getWeaponInfo) isEqualRef (IVCS_Common_WeaponInfo get _weapon), "weapon lookup reuses its own cache"] call _assert;
private _expected = (_loadout select { (_x select 0) == _weapon }) select 0 select 1;
for "_cycle" from 1 to 3 do {
    [_rifleEntity] call IVCS_VirtualSpace_Group_despawn;
    [_rifleEntity] call IVCS_VirtualSpace_Group_spawn;
    private _stored = [(((_rifleEntity get "units") select 0) get "object")] call IVCS_Common_getUnitObjectLoadoutInfo;
    private _actual = (_stored select { (_x select 0) == _weapon }) select 0 select 1;
    _expected sort true;
    _actual sort true;
    [_actual isEqualTo _expected, format ["armed round trip %1 preserves ammunition", _cycle]] call _assert;
    ["Binocular" in weapons (((_rifleEntity get "units") select 0) get "object"),format ["armed round trip %1 preserves captured non-firing weapons",_cycle]] call _assert;
};
[_rifleEntity] call _cleanGroup;

// Support magazines and explosives must survive the same lifecycle as usable ammo.
private _inventorySnapshot = {
    params ["_unit"];
    private _records = (_unit get "magazineCargo") apply { [toLower (_x select 0),_x select 1] };
    { { _records pushBack [toLower (_x select 0),_x select 1]; } forEach (_x select 1); } forEach (_unit get "weapons");
    _records sort true;
    _records
};
private _physicalMagazineSnapshot = {
    params ["_object"];
    private _records = (magazinesAmmoFull [_object,true]) apply { [toLower (_x select 0),_x select 1] };
    _records sort true;
    _records
};
private _first = ["B_soldier_A_F"] call IVCS_VirtualSpace_Group_createUnit;
private _second = ["B_soldier_A_F"] call IVCS_VirtualSpace_Group_createUnit;
private _templateCargo = (["B_soldier_A_F"] call IVCS_Common_getUnitInventoryInfo) select 1;
private _originalCargo = (_templateCargo select 0) select 1;
((_first get "magazineCargo") select 0) set [1,0];
((_first get "magazineCargo") select 0 select 2) pushBack "test-only";
[((_second get "magazineCargo") select 0 select 1) == _originalCargo && { (_templateCargo select 0 select 1) == _originalCargo },"cargo ammunition belongs to one unit and cannot mutate cached templates"] call _assert;
[!("test-only" in ((_second get "magazineCargo") select 0 select 2)) && { !("test-only" in (_templateCargo select 0 select 2)) },"cargo metadata is independently copied"] call _assert;
_second set ["weapons",[]];
[([_second] call IVCS_Combat_getShot) isEqualTo [],"unassigned cargo cannot be fired without a compatible carried weapon"] call _assert;
{
    private _class = _x;
    private _entity = [[14600,16400,0],_class] call _createGroup;
    private _storedUnit = (_entity get "units") select 0;
    private _factoryInventory = [_storedUnit] call _inventorySnapshot;
    [_entity] call IVCS_VirtualSpace_Group_spawn;
    private _object = _storedUnit get "object";
    _object disableAI "ALL";
    [([_object] call _physicalMagazineSnapshot) isEqualTo _factoryInventory,format ["%1 spawn restores all factory magazines",_class]] call _assert;
    private _supportClass = if (_class == "B_soldier_A_F") then { "100Rnd_65x39_caseless_mag" } else { "150Rnd_762x54_Box" };
    private _foreignClass = if (_class == "B_soldier_A_F") then { "30Rnd_65x39_caseless_green" } else { "30Rnd_65x39_caseless_mag" };
    _object removeMagazine _supportClass;
    _object addMagazine [_foreignClass,17];
    _object setAmmo [primaryWeapon _object,11];
    private _expected = [_object] call _physicalMagazineSnapshot;
    [[toLower _foreignClass,17] in _expected,format ["%1 fixture carries a partially filled incompatible magazine",_class]] call _assert;
    for "_cycle" from 1 to 3 do {
        [_entity] call IVCS_VirtualSpace_Group_despawn;
        [([_storedUnit] call _inventorySnapshot) isEqualTo _expected,format ["%1 capture %2 preserves every magazine and remaining rounds",_class,_cycle]] call _assert;
        [(_storedUnit get "magazineCargo") findIf { (_x select 0) == _foreignClass && { (_x select 1) == 17 } } != -1,format ["%1 capture %2 retains incompatible partial magazine as cargo",_class,_cycle]] call _assert;
        [_entity] call IVCS_VirtualSpace_Group_spawn;
        private _object = _storedUnit get "object";
        _object disableAI "ALL";
        [([_object] call _physicalMagazineSnapshot) isEqualTo _expected,format ["%1 respawn %2 preserves every magazine without duplication",_class,_cycle]] call _assert;
    };
    [_entity] call _cleanGroup;
} forEach ["B_soldier_A_F","O_soldier_A_F"];

// Both recursion entry points must preserve a vehicle snapshot exactly once.
private _crew = [[14550, 16400, 0]] call _createGroup;
private _cargo = [[14550, 16400, 0], "C_man_1", 2] call _createGroup;
private _van = ["C_Van_01_transport_F", [14550, 16400, 0]] call _createVehicle;
[_crew, _van] call IVCS_VirtualSpace_Group_assignVehicle;
[_cargo, _van] call IVCS_VirtualSpace_Group_assignAsVehicleCargo;
[_crew] call IVCS_VirtualSpace_Group_spawn;
[_cargo] call IVCS_VirtualSpace_Group_spawn;
[count ((_registry get "active") arrayIntersect [_crew get "id", _cargo get "id", _van get "id"]) == 3, "connected spawn updates every active roster entry"] call _assert;
sleep 1.2;
private _object = _van get "object";
_object engineOn true;
_object addItemCargoGlobal ["FirstAidKit", 3];
_object setHitPointDamage ["HitLFWheel", 0.4];
private _inventory = [_object] call IVCS_Common_getContainerInventory;
private _wheelDamage = _object getHitPointDamage "HitLFWheel";
[_van] call IVCS_VirtualSpace_Vehicle_despawn;
[(_van get "inventory") isEqualTo _inventory, "vehicle-led despawn preserves inventory"] call _assert;
[(_van get "engineOn"), "vehicle-led despawn preserves engine state"] call _assert;
private _wheel = (_van get "hitpoints") select { (_x select 0) == "HitLFWheel" };
[abs (((_wheel select 0) select 1) - _wheelDamage) < 0.001, "vehicle-led despawn preserves damage"] call _assert;
[!(_crew get "active") && { !(_cargo get "active") } && { !(_van get "active") }, "connected despawn virtualizes all owners"] call _assert;
[(_registry get "active") isEqualTo [], "connected despawn removes every active roster entry"] call _assert;
[_crew] call IVCS_VirtualSpace_Group_spawn;
[_cargo] call IVCS_VirtualSpace_Group_spawn;
[(_van get "inventory") isEqualTo _inventory, "respawn retains saved inventory"] call _assert;
[abs (((_van get "object") getHitPointDamage "HitLFWheel") - _wheelDamage) < 0.001, "respawn applies saved hitpoint damage"] call _assert;
[_crew] call IVCS_VirtualSpace_Group_despawn;
[(_van get "inventory") isEqualTo _inventory, "group-led despawn preserves inventory"] call _assert;
private _savedInventory = _van get "inventory";
[_van] call IVCS_VirtualSpace_Vehicle_despawn;
[(_van get "inventory") isEqualTo _savedInventory, "repeated despawn is harmless"] call _assert;

// Transport motion must move virtual passengers and their spatial index.
private _travelPoint = [15150, 16400, 0];
[_crew, _travelPoint] call IVCS_VirtualSpace_setEntityPosition;
private _owned = [[15400, 16400, 0]] call IVCS_VirtualSpace_createEntityWaypoint;
[_cargo, _owned] call IVCS_VirtualSpace_entityAddWaypoint;
_owned set ["initialized", true];
_owned set ["pathGenerationRequestID", "COMPLETE"];
_owned set ["movePoints", [[15400, 16400, 0]]];
[_cargo, 1] call IVCS_VirtualSpace_Group_update;
[_van, 1] call IVCS_VirtualSpace_Vehicle_update;
[(_cargo get "position") isEqualTo (_van get "position"), "virtual cargo follows transport even when simulated first"] call _assert;
[_cargo, 1] call IVCS_VirtualSpace_Group_update;
[(_cargo get "position") isEqualTo (_van get "position"), "carried waypoints do not move passengers independently"] call _assert;
[(_owned get "movePoints") isNotEqualTo [], "carried waypoint remains pending"] call _assert;
[([_travelPoint, 2] call IVCS_VirtualSpace_getNearEntities) findIf { (_x get "id") == (_cargo get "id") } != -1, "cargo movement updates spatial index"] call _assert;
[_crew, _van] call IVCS_VirtualSpace_Group_unassignVehicle;
[(_crew get "pathfindingStrategy") == "man", "last vehicle release restores infantry pathfinding"] call _assert;
[(_crew get "moveSpeedPerSecond") == 4.3, "last vehicle release restores walking speed"] call _assert;
[_cargo, _van] call IVCS_VirtualSpace_Group_unassignAsVehicleCargo;
[(_cargo get "moveSpeedPerSecond") == 4.3, "passenger dismount restores walking speed"] call _assert;
[_crew] call _cleanGroup;
[_cargo] call _cleanGroup;
[_van] call _cleanVehicle;

// Debug marker updates must also tolerate an owner being torn down.
IVCS_VirtualSpace_Controller set ["debug", true];
private _owner = [[15000, 16400, 0], "C_man_1", 2] call _createGroup;
private _vehicle = ["C_Van_01_transport_F", [15000, 16400, 0]] call _createVehicle;
[_owner, _vehicle] call IVCS_VirtualSpace_Group_assignVehicle;
[_owner, _vehicle] call IVCS_VirtualSpace_Group_assignAsVehicleCargo;
[_owner] call IVCS_VirtualSpace_unregisterEntity;
[(_vehicle get "commandingEntity") == "" && { (_vehicle get "entitiesInCargo") isEqualTo [] }, "debug teardown detaches combined command and cargo links"] call _assert;
[_vehicle] call _cleanVehicle;
IVCS_VirtualSpace_Controller set ["debug", false];

// Real non-pylon turrets, driver turrets, empty magazines, and repeated cycles.
private _hmg = ["B_MRAP_01_hmg_F", [14650, 16400, 0]] call _createVehicle;
[(_hmg get "turrets") findIf { (_x select 3) isNotEqualTo [] } == -1, "ordinary turret has a valid empty pylon array"] call _assert;
[_hmg] call IVCS_VirtualSpace_Vehicle_spawn;
private _object = _hmg get "object";
_object removeMagazinesTurret ["200Rnd_127x99_mag_Tracer_Red", [0]];
_object addMagazineTurret ["200Rnd_127x99_mag_Tracer_Red", [0], 7];
_object addMagazineTurret ["200Rnd_127x99_mag_Tracer_Red", [0], 0];
private _snapshot = [_object] call _ammoSnapshot;
for "_cycle" from 1 to 3 do {
    [_hmg] call IVCS_VirtualSpace_Vehicle_despawn;
    [_hmg] call IVCS_VirtualSpace_Vehicle_spawn;
    [([_hmg get "object"] call _ammoSnapshot) isEqualTo _snapshot, format ["turret round trip %1 preserves ammo without duplication", _cycle]] call _assert;
};
// Helpers must use their explicit parameter, not a caller's unrelated _entity.
private _entity = _van;
[_hmg] call IVCS_VirtualSpace_Vehicle_storeVehicleObjectWeapons;
[_hmg] call IVCS_VirtualSpace_Vehicle_applyWeaponsToVehicleObject;
[([_hmg get "object"] call _ammoSnapshot) isEqualTo _snapshot, "weapon helpers are independent of caller scope"] call _assert;
[_hmg] call _cleanVehicle;

private _attack = ["B_Heli_Attack_01_dynamicLoadout_F", [14750, 16400, 0]] call _createVehicle;
[(_attack get "turrets") findIf { (_x select 0) isEqualTo [-1] } != -1, "config cache includes driver weapons"] call _assert;
[_attack] call IVCS_VirtualSpace_Vehicle_spawn;
private _object = _attack get "object";
private _pylons = getAllPylonsInfo _object;
private _firstPylon = _pylons select 0;
_object setPylonLoadout [_firstPylon select 0, "PylonRack_12Rnd_PG_missiles", true, [-1]];
_object setAmmoOnPylon [_firstPylon select 0, 3];
_object setPylonLoadout [(_pylons select 1) select 0, ""];
private _snapshot = [_object] call _ammoSnapshot;
private _pylonSnapshot = (getAllPylonsInfo _object) apply { _x select [1, 4] };
for "_cycle" from 1 to 2 do {
    [_attack] call IVCS_VirtualSpace_Vehicle_despawn;
    [_attack] call IVCS_VirtualSpace_Vehicle_spawn;
    [([_attack get "object"] call _ammoSnapshot) isEqualTo _snapshot, format ["pylon round trip %1 does not duplicate turret magazines", _cycle]] call _assert;
    [((getAllPylonsInfo (_attack get "object")) apply { _x select [1, 4] }) isEqualTo _pylonSnapshot, format ["pylon round trip %1 preserves ammo, empty pylons and control turret", _cycle]] call _assert;
};
[_attack] call _cleanVehicle;

// Spawn protection must cover slow inventory restoration, not expire midway.
private _slowVehicle = ["C_Van_01_transport_F", [15050, 16400, 0]] call _createVehicle;
IVCS_Virtual_OriginalApplyInventory = IVCS_Common_applyContainerInventory;
IVCS_Virtual_ProtectedDuringRestore = false;
IVCS_Common_applyContainerInventory = {
    sleep 1.2;
    IVCS_Virtual_ProtectedDuringRestore = !isDamageAllowed (_this select 0);
    _this call IVCS_Virtual_OriginalApplyInventory;
};
[_slowVehicle] call IVCS_VirtualSpace_Vehicle_spawn;
IVCS_Common_applyContainerInventory = IVCS_Virtual_OriginalApplyInventory;
[IVCS_Virtual_ProtectedDuringRestore, "spawn protection covers slow inventory restoration"] call _assert;
sleep 1.2;
[isDamageAllowed (_slowVehicle get "object"), "spawn grace period ends after restoration"] call _assert;
[_slowVehicle] call _cleanVehicle;

// A vehicle GetOut event also receives players and other unprofiled occupants.
private _crew = [[14800, 16400, 0]] call _createGroup;
private _van = ["C_Van_01_transport_F", [14800, 16400, 0]] call _createVehicle;
[_crew, _van] call IVCS_VirtualSpace_Group_assignVehicle;
[_van] call IVCS_VirtualSpace_Vehicle_spawn;
private _nativeGroup = createGroup civilian;
private _nativeUnit = _nativeGroup createUnit ["C_man_1", [14803, 16400, 0], [], 0, "NONE"];
_nativeUnit moveInCargo (_van get "object");
moveOut _nativeUnit;
sleep 0.1;
[_van get "object", "cargo", _nativeUnit, []] call IVCS_VirtualSpace_Vehicle_onUnitGetOut;
[vehicle _nativeUnit == _nativeUnit && { (_van get "commandingEntity") == (_crew get "id") } &&
    { (((_crew get "units") select 0) get "vehicleAssignment") isNotEqualTo [] }, "unprofiled GetOut leaves tracked crew assignments untouched"] call _assert;
deleteVehicle _nativeUnit;
deleteGroup _nativeGroup;
[_crew] call _cleanGroup;
[_van] call _cleanVehicle;

// Actual vehicle death must detach living virtual owners.
private _crew = [[14850, 16400, 0]] call _createGroup;
private _cargo = [[14850, 16400, 0]] call _createGroup;
private _van = ["C_Van_01_transport_F", [14850, 16400, 0]] call _createVehicle;
[_crew, _van] call IVCS_VirtualSpace_Group_assignVehicle;
[_cargo, _van] call IVCS_VirtualSpace_Group_assignAsVehicleCargo;
[_van] call IVCS_VirtualSpace_Vehicle_spawn;
private _wreck = _van get "object";
_wreck allowDamage true;
_wreck setDamage 1;
private _deathDeadline = diag_tickTime + 2;
waitUntil { isNil { [_van get "id"] call IVCS_VirtualSpace_getEntity } || { diag_tickTime >= _deathDeadline } };
[isNil { [_van get "id"] call IVCS_VirtualSpace_getEntity }, "Killed event unregisters vehicle"] call _assert;
[(_crew get "vehiclesInCommandOf") isEqualTo [] && { (_cargo get "vehiclesInCargoOf") isEqualTo [] }, "vehicle death detaches both owner links"] call _assert;
[(_crew get "units") findIf { (_x get "vehicleAssignment") isNotEqualTo [] } == -1 &&
    { (_cargo get "units") findIf { (_x get "vehicleAssignment") isNotEqualTo [] } == -1 }, "vehicle death releases every seat reservation"] call _assert;
[_crew, 0.1] call IVCS_VirtualSpace_Group_update;
[_cargo, 0.1] call IVCS_VirtualSpace_Group_update;
[_crew] call _cleanGroup;
[_cargo] call _cleanGroup;
deleteVehicle _wreck;

// Detach native owners before GetOut callbacks, and clear links on owner removal.
private _crew = [[14900, 16400, 0]] call _createGroup;
private _cargo = [[14900, 16400, 0]] call _createGroup;
private _van = ["C_Van_01_transport_F", [14900, 16400, 0]] call _createVehicle;
[_crew, _van] call IVCS_VirtualSpace_Group_assignVehicle;
[_cargo, _van] call IVCS_VirtualSpace_Group_assignAsVehicleCargo;
[_crew] call IVCS_VirtualSpace_Group_spawn;
[_cargo] call IVCS_VirtualSpace_Group_spawn;
private _object = _van get "object";
[_van] call IVCS_VirtualSpace_unregisterEntity;
private _driver = ((_crew get "units") select 0) get "object";
[_object, "driver", _driver, []] call IVCS_VirtualSpace_Vehicle_onUnitGetOut;
[(assignedVehicle _driver) isEqualTo objNull, "native vehicle removal clears engine assignment"] call _assert;
[(_crew get "vehiclesInCommandOf") isEqualTo [] && { (_cargo get "vehiclesInCargoOf") isEqualTo [] }, "native removal survives late GetOut"] call _assert;
[_crew] call _cleanGroup;
[_cargo] call _cleanGroup;
deleteVehicle _object;
[_van] call IVCS_VirtualSpace_unregisterEntity;
[!((_van get "id") in (_registry get "active")), "repeated unregister keeps active roster clean"] call _assert;

private _crew = [[14950, 16400, 0]] call _createGroup;
private _van = ["C_Van_01_transport_F", [14950, 16400, 0]] call _createVehicle;
[_crew, _van] call IVCS_VirtualSpace_Group_assignVehicle;
[_crew] call IVCS_VirtualSpace_unregisterEntity;
[(_van get "commandingEntity") == "" && { ((_van get "seats") select 0 select 1 select 0 select 1) == "" }, "owner removal clears vehicle command and seats"] call _assert;
[_van, 0.1] call IVCS_VirtualSpace_Vehicle_update;
[_van] call _cleanVehicle;

// Index changes must preserve the current native and virtual waypoint.
{
    private _native = _x;
    private _owner = [[14500, 16500, 0]] call _createGroup;
    private _wps = [[14700, 16500, 0], [14800, 16500, 0], [14900, 16500, 0]] apply {
        private _wp = [_x] call IVCS_VirtualSpace_createEntityWaypoint;
        [_owner, _wp] call IVCS_VirtualSpace_entityAddWaypoint;
        _wp
    };
    _owner set ["currentWaypointIndex", 1];
    if (_native) then {
        [_owner] call IVCS_VirtualSpace_Group_spawn;
        sleep 0.1;
        [([_owner] call IVCS_VirtualSpace_getEntityCurrentWaypoint) isEqualRef (_wps select 1), "spawn resume ignores actual global first waypoint ID"] call _assert;
    };
    [_owner, _wps select 0] call IVCS_VirtualSpace_entityRemoveWaypoint;
    [([_owner] call IVCS_VirtualSpace_getEntityCurrentWaypoint) isEqualRef (_wps select 1), format ["remove prior waypoint preserves current native=%1", _native]] call _assert;
    [_owner, _wps select 1] call IVCS_VirtualSpace_entityRemoveWaypoint;
    [([_owner] call IVCS_VirtualSpace_getEntityCurrentWaypoint) isEqualRef (_wps select 2), format ["remove current selects successor native=%1", _native]] call _assert;
    [_owner, _wps select 2] call IVCS_VirtualSpace_entityRemoveWaypoint;
    [(_owner get "currentWaypointIndex") == -1, "empty waypoint list clears current index"] call _assert;
    private _wp = [[15000, 16500, 0]] call IVCS_VirtualSpace_createEntityWaypoint;
    [_owner, _wp] call IVCS_VirtualSpace_entityAddWaypoint;
    [(_owner get "currentWaypointIndex") == 0, "new waypoint restarts empty list"] call _assert;
    if (_native) then {
        private _position = +(_owner get "position");
        private _unit = ((_owner get "units") select 0) get "object";
        _unit setPosATL (_position vectorAdd [20, 0, 0]);
        [_owner, _position, true] call IVCS_VirtualSpace_setEntityPosition;
        [(getPosATL _unit) distance2D _position < 1, "unchanged virtual position still permits native teleport"] call _assert;
    };
    [_owner] call _cleanGroup;
} forEach [false, true];

private _owner = [[14500, 16500, 0]] call _createGroup;
private _wps = [];
{ private _wp = [_x] call IVCS_VirtualSpace_createEntityWaypoint; [_owner, _wp] call IVCS_VirtualSpace_entityAddWaypoint; _wps pushBack _wp; } forEach [[14600, 16500, 0], [14700, 16500, 0], [14800, 16500, 0]];
private _cycle = [[14600, 16500, 0], "CYCLE"] call IVCS_VirtualSpace_createEntityWaypoint;
[_owner, _cycle] call IVCS_VirtualSpace_entityAddWaypoint;
_owner set ["currentWaypointIndex", 1];
[_owner, _wps select 0] call IVCS_VirtualSpace_entityRemoveWaypoint;
[(_owner get "minWaypointIndex") == 0 && { (_owner get "maxWaypointIndex") == 1 }, "waypoint removal rebuilds shifted cycle bounds"] call _assert;
[_owner, _cycle] call IVCS_VirtualSpace_entityRemoveWaypoint;
[(_owner get "minWaypointIndex") == -1 && { (_owner get "maxWaypointIndex") == -1 }, "removing cycle clears loop bounds"] call _assert;
[_owner] call _cleanGroup;

// Removed owners may still update metadata while their native objects despawn.
// They must not re-enter the spatial grid or remove another entity from its cell.
private _survivor = [[15100, 16400, 0]] call _createGroup;
private _cargo = [[15100, 16400, 0]] call _createGroup;
private _van = ["C_Van_01_transport_F", [15103, 16400, 0]] call _createVehicle;
[_cargo, _van] call IVCS_VirtualSpace_Group_assignAsVehicleCargo;
[_cargo] call IVCS_VirtualSpace_Group_spawn;
[_cargo, [15105, 16400, 10]] call IVCS_VirtualSpace_setEntityPosition;
private _removedID = _cargo get "id";
[_cargo] call IVCS_VirtualSpace_unregisterEntity;
[_cargo] call IVCS_VirtualSpace_Group_despawn;
private _near = [[15100, 16400, 0], 30] call IVCS_VirtualSpace_getNearEntities;
[_near findIf { (_x get "id") == _removedID } == -1, "owner teardown never reinserts removed profile in spatial grid"] call _assert;
[_near findIf { (_x get "id") == (_survivor get "id") } != -1 &&
    { _near findIf { (_x get "id") == (_van get "id") } != -1 }, "owner teardown preserves neighboring spatial entries"] call _assert;
[_survivor] call _cleanGroup;
[_van] call _cleanVehicle;

private _grid = [[0, 0], 100, 10] call IVCS_SpacialGrid_create;
[_grid, [[[1, 1, 0], "first"], [[2, 2, 0], "neighbor"]]] call IVCS_SpacialGrid_insert;
[_grid, [[1, 1, 0], "first"]] call IVCS_SpacialGrid_remove;
[!([_grid, [[1, 1, 0], "first"]] call IVCS_SpacialGrid_remove), "grid removal reports missing entry"] call _assert;
[([_grid, [2, 2, 0], 1] call IVCS_SpacialGrid_findInRange) isEqualTo ["neighbor"], "repeated grid removal preserves last neighbor"] call _assert;
[_grid, [-1, -1, 0], [3, 3, 0], "returning"] call IVCS_SpacialGrid_move;
[([_grid, [3, 3, 0], 0.1] call IVCS_SpacialGrid_findInRange) isEqualTo ["returning"], "out-of-bounds entity can reenter spatial grid"] call _assert;

[([_grid, [100, 0, 0]] call IVCS_SpacialGrid_positionToCoords) isEqualTo [-1, -1] &&
    { ([_grid, [0, 100, 0]] call IVCS_SpacialGrid_positionToCoords) isEqualTo [-1, -1] }, "upper grid bounds exclude nonexistent cells"] call _assert;
private _positiveGrid = [[100, 200], 100, 10] call IVCS_SpacialGrid_create;
[([_positiveGrid, [105, 205, 0]] call IVCS_SpacialGrid_positionToCoords) isEqualTo [0, 0], "positive grid origin converts by subtraction"] call _assert;
// Dedicated server has no spawn sources. Drain real connected entities.
[count allPlayers == 0, "no-source spawner test has zero players"] call _assert;
private _crew = [[14950, 16400, 0]] call _createGroup;
private _cargo = [[14950, 16400, 0]] call _createGroup;
private _van = ["C_Van_01_transport_F", [14950, 16400, 0]] call _createVehicle;
[_crew, _van] call IVCS_VirtualSpace_Group_assignVehicle;
[_cargo, _van] call IVCS_VirtualSpace_Group_assignAsVehicleCargo;
[_crew] call IVCS_VirtualSpace_Group_spawn;
[_cargo] call IVCS_VirtualSpace_Group_spawn;
private _fsm = [_registry get "active", _registry get "inactive"] call IVCS_VirtualSpace_createEntitySpawnerFSM;
for "_i" from 1 to 150 do { [_fsm] call IVCS_FSM_execute; };
[(_registry get "active") isEqualTo [] && { !(_van get "active") }, "no-source spawner drains connected active entities"] call _assert;
private _inactive = _registry get "inactive";
[count _inactive == count (_inactive arrayIntersect _inactive), "recursive queue processing does not duplicate inactive IDs"] call _assert;
// A queue can outlive its entity; this is a real boundary guard, not an assertion.
(_fsm get "variables") set ["spawnQueue", ["removed-owner"]];
_fsm set ["currentState", (_fsm get "nodes") get "ProcessQueues"];
[_fsm] call IVCS_FSM_execute;
[((_fsm get "variables") get "spawnQueue") isEqualTo [], "stale spawn queue entry is discarded"] call _assert;
[_crew] call _cleanGroup;
[_cargo] call _cleanGroup;
[_van] call _cleanVehicle;
[count (_registry get "ALL") == 0 && { (_registry get "active") isEqualTo [] } && { (_registry get "inactive") isEqualTo [] }, "teardown leaves registry and both rosters empty"] call _assert;

diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2", IVCS_Virtual_TestPassed, IVCS_Virtual_TestFailed];
