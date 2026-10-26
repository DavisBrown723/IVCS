// Run: powershell -File tests/tasks/run.ps1 -TestScript tests/combat/run.sqf -Port 2494 -TimeoutSeconds 240
waitUntil { time > 0 };
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
IVCS_Combat_TestPassed = 0;
IVCS_Combat_TestFailed = 0;
private _assert = {
    params ["_ok", "_label"];
    if (_ok) then { IVCS_Combat_TestPassed = IVCS_Combat_TestPassed + 1; } else { IVCS_Combat_TestFailed = IVCS_Combat_TestFailed + 1; };
    diag_log format ["[IVCS TASK TEST] %1 %2", if (_ok) then { "PASS" } else { "FAIL" }, _label];
};
IVCS_Common_WeaponInfo = createHashMap;
IVCS_Common_MagazineInfo = createHashMap;
IVCS_Common_AmmoInfo = createHashMap;
IVCS_Common_UnitInfo = createHashMap;
IVCS_Common_WeaponAliases = createHashMap;
IVCS_Paths_Generator = createHashMapFromArray [["requestQueue", []], ["currentRequest", []]];
IVCS_VirtualSpace_Controller = [false] call IVCS_VirtualSpace_createController;
removeMissionEventHandler ["EachFrame", IVCS_VirtualSpace_Controller get "onFrameHandlerID"];
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _create = {
    params ["_side", "_position", ["_count", 1], ["_class", "B_Soldier_F"]];
    private _units = [];
    for "_i" from 0 to (_count - 1) do { _units pushBack ([_class, format ["u_%1", _i]] call IVCS_VirtualSpace_Group_createUnit); };
    [_side, "BLU_F", +_position, _units] call IVCS_VirtualSpace_Group_createEntity
};
private _clean = {
    params ["_a", "_b"];
    {
        if (_x get "active") then { [_x] call IVCS_VirtualSpace_Group_despawn; };
        [_x] call IVCS_VirtualSpace_unregisterEntity;
    } forEach [_a, _b];
};
private _ammoCount = {
    params ["_entity"];
    private _total = 0;
    { { { _total = _total + (_x select 1); } forEach (_x select 1); } forEach (_x get "weapons"); } forEach (_entity get "units");
    _total
};
west setFriend [east, 0]; east setFriend [west, 0];
private _profile = ["B_Soldier_F"] call IVCS_Combat_getUnitProfile;
diag_log format ["[IVCS TASK TEST] PROFILE %1", _profile];
diag_log format ["[IVCS TASK TEST] WEAPON %1 AMMO %2 PROTECTION %3", ["arifle_MX_F"] call IVCS_Combat_getWeaponProfile, ["30Rnd_65x39_caseless_mag"] call IVCS_Combat_getAmmoProfile, [_profile get "equipment"] call IVCS_Combat_getProtection];
private _a = ["WEST", [14500,16400,0], 2] call _create;
private _b = ["EAST", [14700,16400,0], 2] call _create;
[[_a,_b] call IVCS_Combat_canSee, "reference positions are terrain visible"] call _assert;
private _u = (_a get "units") select 0;
private _v = (_a get "units") select 1;
private _shot = [_u] call IVCS_Combat_getShot;
[count _shot == 3, "rifle resolves a supported shot"] call _assert;
if (_shot isEqualTo []) exitWith { diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2", IVCS_Combat_TestPassed, IVCS_Combat_TestFailed]; };
private _originalAmmo = ((_v get "weapons") select 0 select 1 select 0 select 1);
(_shot select 0) set [1, (_shot select 0 select 1) - 1];
[((_v get "weapons") select 0 select 1 select 0 select 1) == _originalAmmo, "unit ammunition is independent"] call _assert;
private _accuracy = [_u,_shot select 1,_shot select 2,200] call IVCS_Combat_accuracy;
private _arms = _profile get "regions" get "arms";
private _armName = _arms select 0;
((_u get "hitpoints") select ((_u get "hitpoints") findIf { (_x select 0) == _armName })) set [1,0.8];
private _injuredAccuracy = [_u,_shot select 1,_shot select 2,200] call IVCS_Combat_accuracy;
[_injuredAccuracy < _accuracy, "arm damage reduces accuracy"] call _assert;
private _engagement = [_a,_b,0,1234] call IVCS_Combat_start;
[!isNil "_engagement", "hostile rifle groups start an engagement"] call _assert;
private _before = [_a] call _ammoCount;
[_engagement, 1] call IVCS_Combat_update;
[([_a] call _ammoCount) < _before && { (_engagement get "shots") >= 4 }, "virtual exchange consumes individual ammo"] call _assert;
private _waypoint = [[14900,16400,0]] call IVCS_VirtualSpace_createEntityWaypoint;
[_a,_waypoint] call IVCS_VirtualSpace_entityAddWaypoint;
_waypoint set ["initialized",true]; _waypoint set ["pathGenerationRequestID","COMPLETE"]; _waypoint set ["movePoints",[[14900,16400,0]]];
private _position = +(_a get "position");
[_a,10] call IVCS_VirtualSpace_Group_update;
[(_a get "position") isEqualTo _position && { (_a get "waypoints") isNotEqualTo [] }, "combat pauses movement and preserves orders"] call _assert;
[_a] call IVCS_VirtualSpace_Group_spawn;
[_a get "active" && { _b get "active" } && { (_engagement get "mode") == "native" }, "spawning a participant spawns its target once"] call _assert;
{ { _x disableAI "ALL"; } forEach units (_x get "group"); } forEach [_a,_b];
[(leader (_a get "group")) knowsAbout (leader (_b get "group")) >= 3, "handoff reveals native enemy objects"] call _assert;
private _shotsBefore = _engagement get "shots";
[_engagement,100] call IVCS_Combat_update;
[(_engagement get "shots") == _shotsBefore, "native engagement receives no virtual shots"] call _assert;
private _object = ((_a get "units") select 0) get "object";
_object setDamage 0;
_object setHitPointDamage ["HitHands",0.4,false];
_object setHitPointDamage ["HitLegs",0.6,false];
removeVest _object; _object addVest "V_TacVest_blk";
removeHeadgear _object; _object addHeadgear "H_Cap_blk";
private _damageBefore = getAllHitPointsDamage _object;
private _overallBefore = damage _object;
[_a] call IVCS_VirtualSpace_Group_despawn;
[!(_a get "active") && { !(_b get "active") } && { (_engagement get "mode") == "virtual" }, "despawn coordinates both combatants"] call _assert;
diag_log format ["[IVCS TASK TEST] STORED INJURIES %1",((_a get "units") select 0) get "hitpoints"];
[_a] call IVCS_VirtualSpace_Group_spawn;
private _restored = ((_a get "units") select 0) get "object";
diag_log format ["[IVCS TASK TEST] RESTORE before=%1 total=%2 after=%3 total=%4",_damageBefore,_overallBefore,getAllHitPointsDamage _restored,damage _restored];
[getAllHitPointsDamage _restored isEqualTo _damageBefore, "round trip preserves individual injuries"] call _assert;
[abs (damage _restored - _overallBefore) < 0.001, "round trip preserves overall damage"] call _assert;
[vest _restored == "V_TacVest_blk" && { headgear _restored == "H_Cap_blk" }, "round trip preserves protective equipment"] call _assert;
[_a,_b] call _clean;
[count (_combat get "engagements") == 0 && { (_combat get "queue") isEqualTo [] }, "teardown releases engagement registry and queue"] call _assert;


// Hostility, range, terrain, boarding, and pairing boundaries.
_a = ["WEST", [14500,16400,0]] call _create;
_b = ["WEST", [14700,16400,0]] call _create;
[isNil { [_a,_b] call IVCS_Combat_start }, "friendly groups cannot engage"] call _assert;
_b set ["side","EAST"];
[_b,[14801,16400,0]] call IVCS_VirtualSpace_setEntityPosition;
[isNil { [_a,_b] call IVCS_Combat_start }, "combat range is limited to 300 metres"] call _assert;
[_b,[14800,16400,0]] call IVCS_VirtualSpace_setEntityPosition;
[!isNil { [_a,_b,0,1] call IVCS_Combat_start }, "300 metre boundary is inclusive"] call _assert;
[_a get "combatID"] call IVCS_Combat_finish;
private _savedHeight = _combat get "eyeHeight";
_combat set ["eyeHeight",-10];
[!([_a,_b] call IVCS_Combat_canSee), "terrain blocks rays below the ground"] call _assert;
_combat set ["eyeHeight",_savedHeight];
((_a get "units") select 0) set ["vehicleAssignment",["vehicle",[-1]]];
[isNil { [_a,_b] call IVCS_Combat_start }, "vehicle-assigned groups are excluded"] call _assert;
((_a get "units") select 0) set ["vehicleAssignment",[]];
[_b,[14700,16400,0]] call IVCS_VirtualSpace_setEntityPosition;
[_a] call IVCS_Combat_findTarget;
[(_a get "combatID") != "" && { (_a get "combatID") == (_b get "combatID") }, "spatial discovery creates reciprocal engagement"] call _assert;
private _third = ["EAST",[14600,16400,0]] call _create;
[isNil { [_a,_third] call IVCS_Combat_start }, "third group cannot claim an occupied participant"] call _assert;
[_third] call IVCS_VirtualSpace_unregisterEntity;
_engagement = (_combat get "engagements") get (_a get "combatID");
_engagement set ["lastUpdate",0];
private _nativeShots = _engagement get "shots";
_combat set ["eyeHeight",-10];
[_engagement,10] call IVCS_Combat_update;
[(_engagement get "shots") == _nativeShots && { (_a get "combatID") != "" }, "terrain contact loss pauses fire without disengaging"] call _assert;
_combat set ["eyeHeight",_savedHeight];
[_engagement,11] call IVCS_Combat_update;
[(_engagement get "pending") == 0, "contact recovery does not replay obstructed firing time"] call _assert;
[_a] call IVCS_VirtualSpace_unregisterEntity;
[(_b get "combatID") == "" && { count (_combat get "engagements") == 0 }, "removed target releases surviving group's combat state"] call _assert;
[_b] call IVCS_VirtualSpace_unregisterEntity;

// Damage properties and local-region selection.
private _newUnit = { ["B_Soldier_F","test"] call IVCS_VirtualSpace_Group_createUnit };
private _weapon = ["arifle_MX_F"] call IVCS_Combat_getWeaponProfile;
private _ammo = ["30Rnd_65x39_caseless_mag"] call IVCS_Combat_getAmmoProfile;
private _torso = _profile get "regions" get "torso";
private _chestIndex = _torso find "hitchest";
private _chestRoll = (_chestIndex + 0.1) / count _torso;
private _protected = call _newUnit;
private _unprotected = call _newUnit;
_unprotected set ["equipment",["",""]];
[_protected,_weapon,_ammo,200,"torso",_chestRoll] call IVCS_Combat_damageUnit;
[_unprotected,_weapon,_ammo,200,"torso",_chestRoll] call IVCS_Combat_damageUnit;
private _chestDamage = { params ["_unit"]; ((_unit get "hitpoints") select ((_unit get "hitpoints") findIf { (_x select 0) == "hitchest" })) select 1 };
[([_protected] call _chestDamage) < ([_unprotected] call _chestDamage), "vest reduces local chest damage"] call _assert;
[count ((_protected get "hitpoints") select { (_x select 1) > 0 }) == 1, "one hit damages one anatomical hitpoint"] call _assert;
private _weak = call _newUnit;
[_weak,_weapon,["16Rnd_9x21_Mag"] call IVCS_Combat_getAmmoProfile,200,"torso",_chestRoll] call IVCS_Combat_damageUnit;
[([_weak] call _chestDamage) < ([_protected] call _chestDamage), "ammunition damage differs by ammunition class"] call _assert;
private _near = call _newUnit;
[_near,_weapon,_ammo,25,"torso",_chestRoll] call IVCS_Combat_damageUnit;
[([_near] call _chestDamage) > ([_protected] call _chestDamage), "range reduces projectile damage"] call _assert;
[([_near,_weapon,_ammo,25] call IVCS_Combat_accuracy) > ([_near,_weapon,_ammo,300] call IVCS_Combat_accuracy), "range reduces hit probability"] call _assert;
private _poorWeapon = +_weapon; _poorWeapon set ["dispersion",(_weapon get "dispersion") * 2];
[([_near,_poorWeapon,_ammo,200] call IVCS_Combat_accuracy) < ([_near,_weapon,_ammo,200] call IVCS_Combat_accuracy), "weapon dispersion affects accuracy"] call _assert;
[(_profile get "regions" get "arms") isNotEqualTo [] && { (_profile get "regions" get "legs") isNotEqualTo [] }, "default dependency values retain limb hitpoints"] call _assert;

// Native bullet observations anchor the approximation to the engine.
private _nativeGroup = createGroup west;
private _native = _nativeGroup createUnit ["B_Soldier_F",[14400,16300,0],[],0,"NONE"];
_native disableAI "ALL"; _native setDir 0;
{
    _x params ["_ammoClass","_velocity","_magClass","_weaponClass"];
    _native setDamage 0;
    private _bullet = createVehicle [_ammoClass,[14400,16310,1.25],[],0,"CAN_COLLIDE"];
    _bullet setVelocity [0,-_velocity,0];
    sleep 0.2;
    diag_log format ["[IVCS TASK TEST] NATIVE DAMAGE %1 total=%2 hitpoints=%3",_ammoClass,damage _native,getAllHitPointsDamage _native];
    private _approximation = call _newUnit;
    [_approximation,[_weaponClass] call IVCS_Combat_getWeaponProfile,[_magClass] call IVCS_Combat_getAmmoProfile,10,"torso",_chestRoll] call IVCS_Combat_damageUnit;
    private _nativeChest = _native getHitPointDamage "HitChest";
    [abs (([_approximation] call _chestDamage) - _nativeChest) < 0.15,format ["%1 local damage approximation agrees with native bullet observation",_ammoClass]] call _assert;
} forEach [["B_9x21_Ball",400,"16Rnd_9x21_Mag","hgun_P07_F"],["B_65x39_Caseless",800,"30Rnd_65x39_caseless_mag","arifle_MX_F"]];

private _probeDamage = getAllHitPointsDamage _native;
private _probeOverall = damage _native;
private _probeUnit = ["B_Soldier_F","native_probe"] call IVCS_VirtualSpace_Group_createUnit;
_probeUnit set ["object",_native];
private _probeEntity = ["WEST","BLU_F",getPos _native,[_probeUnit]] call IVCS_VirtualSpace_Group_createEntity;
_probeEntity set ["group",_nativeGroup];
[_probeEntity,true] call IVCS_VirtualSpace_setEntityActive;
[_probeEntity] call IVCS_VirtualSpace_Group_despawn;
[_probeEntity] call IVCS_VirtualSpace_Group_spawn;
private _probeRestored = ((_probeEntity get "units") select 0) get "object";
diag_log format ["[IVCS TASK TEST] NATIVE RESTORE before=%1 after=%2 totalBefore=%3 totalAfter=%4",_probeDamage,getAllHitPointsDamage _probeRestored,_probeOverall,damage _probeRestored];
[getAllHitPointsDamage _probeRestored isEqualTo _probeDamage && { abs (damage _probeRestored - _probeOverall) < 0.001 }, "real bullet injuries including aggregate damage round trip exactly"] call _assert;
[_probeEntity] call IVCS_VirtualSpace_Group_despawn;
[_probeEntity] call IVCS_VirtualSpace_unregisterEntity;



// Helmet coverage includes HitHead even though it has an engine dependency.
private _headNames = _profile get "regions" get "head";
private _headRoll = ((_headNames find "hithead") + 0.1) / count _headNames;
private _helmeted = call _newUnit;
private _bare = call _newUnit; _bare set ["equipment",["",""]];
private _pistol = ["hgun_P07_F"] call IVCS_Combat_getWeaponProfile;
private _pistolAmmo = ["16Rnd_9x21_Mag"] call IVCS_Combat_getAmmoProfile;
[_helmeted,_pistol,_pistolAmmo,200,"head",_headRoll] call IVCS_Combat_damageUnit;
[_bare,_pistol,_pistolAmmo,200,"head",_headRoll] call IVCS_Combat_damageUnit;
private _headDamage = { params ["_unit"]; ((_unit get "hitpoints") select ((_unit get "hitpoints") findIf { (_x select 0) == "hithead" })) select 1 };
[([_helmeted] call _headDamage) < ([_bare] call _headDamage), "helmet protection affects actual head hits"] call _assert;
[([_near,_weapon,_ammo,200] call IVCS_Combat_accuracy) > ([_near,_weapon,_pistolAmmo,200] call IVCS_Combat_accuracy), "ammunition flight speed affects accuracy"] call _assert;


private _partial = call _newUnit;
_partial set ["hitpoints",[["hitlegs",0]]];
[_partial,_weapon,_ammo,200,"head",0.2] call IVCS_Combat_damageUnit;
[(_partial get "hitpoints" select 0 select 0) == "hitlegs" && { (_partial get "damage") < 1 }, "missing anatomical regions fall back to an actual supported hitpoint"] call _assert;
private _noHitpoints = call _newUnit; _noHitpoints set ["hitpoints",[]];
[_noHitpoints,_weapon,_ammo,200,"torso",0.1] call IVCS_Combat_damageUnit;
[(_noHitpoints get "damage") > 0, "custom empty hitpoint snapshots still receive overall damage"] call _assert;

// Exact ammunition exhaustion and reload delay.
_a = ["WEST",[14500,16400,0]] call _create;
_b = ["EAST",[14700,16400,0]] call _create;
_u = (_a get "units") select 0;
_u set ["weapons",[["arifle_MX_F",[["30Rnd_65x39_caseless_mag",1,["infantry"]],["30Rnd_65x39_caseless_mag",1,["infantry"]]]]]];
private _otherUnit = (_b get "units") select 0; _otherUnit set ["weapons",[]];
_engagement = [_a,_b,0,42] call IVCS_Combat_start;
private _savedAccuracy = _combat get "accuracyScale"; _combat set ["accuracyScale",0];
[_engagement,1] call IVCS_Combat_update;
[([_a] call _ammoCount) == 1, "one shot consumes exactly one round"] call _assert;
[_engagement,2] call IVCS_Combat_update;
[([_a] call _ammoCount) == 1, "empty magazine applies reload delay before the next magazine"] call _assert;
[_engagement,7] call IVCS_Combat_update;
[_engagement,7] call IVCS_Combat_update;
[([_a] call _ammoCount) == 0, "all individual ammunition can be depleted"] call _assert;
private _spentShots = _engagement get "shots";
[_engagement,30] call IVCS_Combat_update;
while {(_engagement get "mode")!="finished" && {(_engagement get "pending")>=(_combat get "step")}} do {[_engagement,30] call IVCS_Combat_update};
[(_engagement get "shots") == _spentShots && { (_a get "combatID") == "" } && {(_engagement get "reason")=="ammunition"}, "empty ammunition stops firing and releases the stalled engagement"] call _assert;
_combat set ["accuracyScale",_savedAccuracy];
[_a,_b] call _clean;

// A paused task and native waypoint completion survive combat intact.
_a = ["WEST",[14500,16400,0]] call _create;
_b = ["EAST",[14700,16400,0]] call _create;
private _move = [_a,[14900,16400,0]] call IVCS_EntityTasks_createMoveTask;
private _moveID = [_a,_move] call IVCS_VirtualSpace_entityAddTask;
[_a,_move] call IVCS_EntityTasks_processTask;
private _owned = (_a get "waypoints") select 0;
_engagement = [_a,_b,0,18] call IVCS_Combat_start;
[_a get "id",_owned get "name"] call IVCS_VirtualSpace_onWaypointCompleted;
[(_a get "waypoints") isNotEqualTo [] && { !((_move get "context") get "waypointComplete") }, "combat defers native waypoint completion"] call _assert;
[_b] call IVCS_VirtualSpace_unregisterEntity;
[(_a get "combatID") == "" && { (_move get "context") get "waypointComplete" }, "ending combat releases deferred completion"] call _assert;
[_a,0.1] call IVCS_VirtualSpace_Group_update;
[_a,0.1] call IVCS_VirtualSpace_Group_update;
[(_a get "tasks") isEqualTo [], "movement task resumes and completes after combat"] call _assert;
[_a] call IVCS_VirtualSpace_unregisterEntity;

// Mutual lethality still permits both sides' shots during the same exchange.
_a = ["WEST",[14500,16400,0]] call _create;
_b = ["EAST",[14700,16400,0]] call _create;
_engagement = [_a,_b,0,200] call IVCS_Combat_start;
{ ((_x get "units") select 0) set ["damage",0.999]; } forEach [_a,_b];
_combat set ["accuracyScale",10000];
[_engagement,1] call IVCS_Combat_update;
[(_engagement get "shots") == 2, "both sides fire before resolving lethal hits"] call _assert;
_combat set ["accuracyScale",_savedAccuracy];
[_a,_b] call _clean;

// Live handoff actually produces native firing, not just knowledge metadata.
_a = ["WEST",[14500,16400,0],2] call _create;
_b = ["EAST",[14600,16400,0],2] call _create;
_engagement = [_a,_b,diag_tickTime,51] call IVCS_Combat_start;
[_a] call IVCS_VirtualSpace_Group_spawn;
IVCS_Combat_NativeShots = 0;
{
    {
        _x setUnitPos "UP";
        _x addEventHandler ["Fired",{ IVCS_Combat_NativeShots = IVCS_Combat_NativeShots + 1; }];
    } forEach units (_x get "group");
} forEach [_a,_b];
private _nativeDeadline = diag_tickTime + 15;
waitUntil { sleep 0.1; IVCS_Combat_NativeShots > 0 || { diag_tickTime >= _nativeDeadline } };
[IVCS_Combat_NativeShots > 0, "revealed native combatants resume firing in the engine"] call _assert;
private _virtualBefore = _engagement get "shots";
[_engagement,diag_tickTime+100] call IVCS_Combat_update;
[(_engagement get "shots") == _virtualBefore, "live native fire never also resolves virtual fire"] call _assert;
// Both groups should be retained if only one lies in player spawn range.
private _fsm = IVCS_VirtualSpace_Controller get "spawnerFSM";
private _fsmData = _fsm get "variables";
_fsmData set ["entitiesInSpawnRange",[_a get "id"]];
_fsmData call (((_fsm get "nodes") get "FillSpawnSources") select 1);
[(_fsmData get "despawnQueue") isEqualTo [], "FSM spawn retention includes the directly engaged opponent"] call _assert;
// Both are outside every source on the headless server, so one queue entry must
// virtualize the pair without leaving stale active records.
_fsmData set ["despawnQueue",[_b get "id"]];
_fsmData call (((_fsm get "nodes") get "ProcessQueues") select 1);
[!(_a get "active") && { !(_b get "active") }, "FSM despawn coordinates an out-of-range engagement"] call _assert;
[_a] call IVCS_VirtualSpace_Group_spawn;
[_a] call IVCS_VirtualSpace_Group_despawn;
[_a get "active" == false && { _b get "active" == false }, "live native combat despawns as one pair"] call _assert;
[_a] call IVCS_VirtualSpace_Group_spawn;
{ { _x disableAI "ALL"; } forEach units (_x get "group"); } forEach [_a,_b];
private _killed = ((_b get "units") select 0) get "object";
_killed setDamage 1;
sleep 0.1;
diag_log format ["[IVCS TASK TEST] CASUALTY alive=%1 damage=%2 roster=%3 entityID=%4 unitID=%5",alive _killed,damage _killed,count (_b get "units"),_killed getVariable "entityID",_killed getVariable "unitID"];
[count (_b get "units") == 1, "native casualty updates the profiled roster"] call _assert;
(((_b get "units") select 0) get "object") setDamage 1;
sleep 0.1;
[(_a get "combatID") == "" && { (_b get "combatID") == "" } && { count (_combat get "engagements") == 0 }, "last native casualty clears both combat references"] call _assert;
[_a,_b] call _clean;


_a = ["WEST",[14500,16400,0]] call _create;
_b = ["EAST",[14700,16400,0]] call _create;
_engagement = [_a,_b] call IVCS_Combat_start;
_combat set ["accuracyScale",0];
private _clockBefore = IVCS_SimulationTime;
private _wallBefore = diag_tickTime;
sleep 1.1;
[] call IVCS_Combat_onFrame;
[abs (((IVCS_SimulationTime) - _clockBefore) - (diag_tickTime - _wallBefore) * accTime) < 0.1 && { (_engagement get "shots") == 2 }, "frame clock advances combat using shared simulation time"] call _assert;
[_a,_b] call _clean;
_combat set ["accuracyScale",_savedAccuracy];
private _launcher = call _newUnit;
_launcher set ["weapons",[["launch_NLAW_F",[["NLAW_F",1,["armor"]]]]]];
[([_launcher] call IVCS_Combat_getShot) isEqualTo [], "launchers are outside the small-arms combat scope"] call _assert;
_launcher set ["weapons",[["arifle_MX_GL_F",[["1Rnd_HE_Grenade_shell",1,["infantry"]]]]]];
[([_launcher] call IVCS_Combat_getShot) isEqualTo [], "explosive ammunition is not resolved as a rifle bullet"] call _assert;


_a = ["WEST",[14500,16400,0]] call _create;
_b = ["EAST",[14700,16400,0]] call _create;
_b set ["simulationTransition",true];
[_a] call IVCS_Combat_findTarget;
[(_a get "combatID") == "", "discovery excludes a group with incomplete native state"] call _assert;
_b set ["simulationTransition",false];
_engagement = [_a,_b,0,1] call IVCS_Combat_start;
_b set ["simulationTransition",true];
[_a] call IVCS_VirtualSpace_Group_spawn;
[_a get "active" && { !(_b get "active") } && { (_engagement get "mode") == "spawning" }, "handoff waits for a separately scheduled peer spawn"] call _assert;
[_engagement,10] call IVCS_Combat_update;
[(_engagement get "shots") == 0 && { (_a get "combatID") != "" }, "partial spawn does not resolve virtual damage or terminate engagement"] call _assert;
_b set ["simulationTransition",false];
[_b] call IVCS_VirtualSpace_Group_spawn;
[(_engagement get "mode") == "native", "last completed peer finalizes the native handoff"] call _assert;
_b set ["simulationTransition",true];
[_a] call IVCS_VirtualSpace_Group_despawn;
[(_engagement get "mode") == "despawning" && { _b get "active" }, "paired despawn waits for a separately scheduled peer capture"] call _assert;
[_engagement,20] call IVCS_Combat_update;
[(_engagement get "shots") == 0, "partial despawn cannot resolve virtual damage"] call _assert;
_b set ["simulationTransition",false];
[_b] call IVCS_VirtualSpace_Group_despawn;
[(_engagement get "mode") == "virtual" && { !(_a get "active") }, "last captured peer resumes virtual authority"] call _assert;
[_a,_b] call _clean;
private _mg = ["B_Soldier_AR_F","mg"] call IVCS_VirtualSpace_Group_createUnit;
[([_mg] call IVCS_Combat_getShot) isNotEqualTo [], "machine-gun loadouts support infantry combat"] call _assert;


_a = ["WEST",[14500,16400,0]] call _create;
_b = ["EAST",[14700,16400,0],2] call _create;
_engagement = [_a,_b] call IVCS_Combat_start;
[_a] call IVCS_VirtualSpace_Group_spawn;
{ { _x disableAI "ALL"; } forEach units (_x get "group"); } forEach [_a,_b];
(((_b get "units") select 0) get "object") setDamage 1;
[_b] call IVCS_VirtualSpace_Group_despawn;
[count (_b get "units") == 1 && { (_b get "units") findIf { (_x get "damage") >= 1 } == -1 }, "immediate despawn filters casualties whose native death callback is pending"] call _assert;
[_engagement,(IVCS_SimulationTime) + 1] call IVCS_Combat_update;
[(_engagement get "shots") == 2, "captured corpse cannot fire in a virtual exchange"] call _assert;
[_a,_b] call _clean;

// Calibration and frame-cadence consistency. Synthetic wall clock avoids waiting
// three minutes per trial; the resolver is the same one used in the mission.
private _trial = {
    params ["_seed",["_interval",0.5],["_reverse",false]];
    private _a = ["WEST",[14500,16400,0],8] call _create;
    private _b = ["EAST",[14700,16400,0],8] call _create;
    private _eng = if (_reverse) then { [_b,_a,0,_seed] call IVCS_Combat_start } else { [_a,_b,0,_seed] call IVCS_Combat_start };
    private _now = 0;
    while { (_eng get "mode") != "finished" && { _now < 1800 } } do {
        _now = _now + _interval;
        [_eng,_now] call IVCS_Combat_update;
        while { (_eng get "pending") >= (_combat get "step") && { (_eng get "mode") != "finished" } } do { [_eng,_now] call IVCS_Combat_update; };
    };
    private _result = [_eng get "elapsed",_eng get "shots",_eng get "hits",_eng get "casualties",count (_a get "units"),count (_b get "units"),_eng get "mode"];
    [_a,_b] call _clean;
    _result
};
private _fast = [4321,0.5] call _trial;
private _slow = [4321,4] call _trial;
[_fast isEqualTo _slow, "bounded catchup matches fine-grained update outcomes"] call _assert;
private _reversed = [4321,0.5,true] call _trial;
[_fast select [0,4] isEqualTo (_reversed select [0,4]) && { (_fast select 4) == (_reversed select 5) }, "reversing sides has no first-side casualty advantage"] call _assert;
private _results = [];
for "_seed" from 1 to 20 do {
    private _result = [1000 + _seed * 71] call _trial;
    _results pushBack _result;
    diag_log format ["[IVCS TASK TEST] TRIAL seed=%1 result=%2",_seed,_result];
};
private _sum = 0; private _min = 1e9; private _max = 0; private _complete = 0;
{
    _sum = _sum + (_x select 0); _min = _min min (_x select 0); _max = _max max (_x select 0);
    if ((_x select 6) == "finished") then { _complete = _complete + 1; };
} forEach _results;
private _mean = _sum / count _results;
diag_log format ["[IVCS TASK TEST] CALIBRATION n=%1 meanSimulationSeconds=%2 min=%3 max=%4 completed=%5 accuracy=%6",count _results,_mean,_min,_max,_complete,_combat get "accuracyScale"];
[_complete == count _results, "reference fights finish without a forced duration timer"] call _assert;
[_mean >= 150 && { _mean <= 210 }, "reference mean duration is approximately three simulation minutes"] call _assert;

diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2", IVCS_Combat_TestPassed, IVCS_Combat_TestFailed];
