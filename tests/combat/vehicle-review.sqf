waitUntil {time>0};
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
IVCS_Common_WeaponInfo=createHashMap;IVCS_Common_MagazineInfo=createHashMap;IVCS_Common_AmmoInfo=createHashMap;IVCS_Common_UnitInfo=createHashMap;IVCS_Common_WeaponAliases=createHashMap;
IVCS_Common_VehicleConfigInventories=createHashMap;IVCS_Common_VehicleTurrets=[] call IVCS_Common_getAllVehicleTurretsFromConfig;
IVCS_Paths_Generator=createHashMapFromArray [["requestQueue",[]],["currentRequest",[]]];
IVCS_VirtualSpace_Controller=[false] call IVCS_VirtualSpace_createController;
removeMissionEventHandler ["EachFrame",IVCS_VirtualSpace_Controller get "onFrameHandlerID"];
west setFriend [east,0];east setFriend [west,0];
private _passed=0;private _failed=0;
private _assert={params ["_ok","_label"];if (_ok) then {_passed=_passed+1} else {_failed=_failed+1};diag_log format ["[IVCS TASK TEST] %1 %2",if (_ok) then {"PASS"} else {"FAIL"},_label]};
private _combat=IVCS_VirtualSpace_Controller get "combat";
private _make={params [["_class","B_soldier_LAT_F"],["_side","WEST"],["_count",4],["_position",[14500,16400,0]]];private _u=[];for "_i" from 0 to (_count-1) do {_u pushBack ([_class,format ["u%1",_i]] call IVCS_VirtualSpace_Group_createUnit)};[_side,"BLU_F",+_position,_u] call IVCS_VirtualSpace_Group_createEntity};
private _vehicle={params [["_class","O_MRAP_02_hmg_F"],["_crewCount",2]];private _v=[_class,[14700,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity;_v set ["side","EAST"];private _crew=["O_crew_F","EAST",_crewCount,[14700,16400,0]] call _make;[_crew,_v] call IVCS_VirtualSpace_Group_assignVehicle;[_v,_crew]};
private _clean={{if (_x get "active") then {[_x] call (missionNamespace getVariable (_x get "despawn"))};[_x] call IVCS_VirtualSpace_unregisterEntity} forEach _this};
private _ammo={params ["_v"];private _n=0;{{_n=_n+(_x select 1)} forEach (_x select 2)} forEach (_v get "turrets");_n};
// Ammo fuse distances are shared by both directions, including warmed selection caches.
private _a=["B_Soldier_F"] call _make;
private _pair=["O_MRAP_02_gmg_F"] call _vehicle;_pair params ["_v","_crew"];
private _station=([_v] call IVCS_Combat_getReturnFireStations) select 0 select 0;
private _shot=[_station,createHashMap,200] call IVCS_Combat_getReturnFireShot;
private _fuse=(_shot select 2) get "fuseDistance";
[_fuse>0,"stock GMG ammunition has a positive arming distance"] call _assert;
private _cache=createHashMap;
private _armed=[_station,_cache,200] call IVCS_Combat_getReturnFireShot;
[([_station,_cache,_fuse/2] call IVCS_Combat_getReturnFireShot) isEqualTo [],"a warmed turret cache cannot bypass the ammo arming distance"] call _assert;
[_armed isNotEqualTo [],"GMG ammunition remains usable beyond its fuse in an allowed AI range"] call _assert;
[_a,_v,_crew] call _clean;
_a=[] call _make;private _u=(_a get "units") select 0;
_u set ["weapons",[["launch_NLAW_F",[["NLAW_F",1,[]]]]]];_u set ["magazineCargo",[]];
_v=["O_MBT_02_cannon_F",[14700,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity;_v set ["side","EAST"];
private _profile=[_v get "class"] call IVCS_Combat_getVehicleProfile;
private _launcherAmmo=["NLAW_F"] call IVCS_Combat_getAmmoProfile;
// A deterministic synthetic fuse also covers mods with longer arming distances.
private _originalFuse=_launcherAmmo get "fuseDistance";_launcherAmmo set ["fuseDistance",100];_cache=createHashMap;
[_u,_cache,_profile,200] call IVCS_Combat_getVehicleShot;
[([_u,_cache,_profile,50] call IVCS_Combat_getVehicleShot) isEqualTo [],"infantry launcher selection respects arming distance with cached ammo"] call _assert;
[([_u,createHashMap,_profile,50] call IVCS_Review_BeforeVehicleShot) isNotEqualTo [],"the regression reproduces the former unarmed-impact bug"] call _assert;
[_v,[14550,16400,0]] call IVCS_VirtualSpace_setEntityPosition;
[!([_a,_v] call IVCS_Combat_canFightVehicle),"shared eligibility rejects a point-blank unarmed launcher against armor"] call _assert;
_launcherAmmo set ["fuseDistance",_originalFuse];[_a,_v] call _clean;
// Secondary-muzzle attacks must not borrow their parent rifle's firing properties.
_a=[] call _make;_u=(_a get "units") select 0;
_u set ["weapons",[["arifle_MX_GL_F",[["1Rnd_HE_Grenade_shell",1,[]]]]]];_u set ["magazineCargo",[]];
private _soft=["C_Offroad_01_F"] call IVCS_Combat_getVehicleProfile;
_shot=[_u,createHashMap,_soft,200] call IVCS_Combat_getVehicleShot;
private _parent=["arifle_MX_GL_F"] call IVCS_Combat_getWeaponProfile;
private _glConfig=configFile >> "CfgWeapons" >> "arifle_MX_GL_F" >> (_shot select 7);
private _glMode=_glConfig >> (getArray (_glConfig >> "modes") select 0);
private _expectedSpread=(getNumber (_glMode >> "dispersion") max 0.0005)*((getNumber (_glConfig >> "aiDispersionCoefX") max 1) max (getNumber (_glConfig >> "aiDispersionCoefY") max 1));
[abs (((_shot select 1) get "dispersion")-_expectedSpread)<0.000001,"GL attacks use the selected muzzle's configured dispersion"] call _assert;
[abs (((_shot select 1) get "dispersion")-(_parent get "dispersion"))>0.000001,"the stock GL regression distinguishes launcher spread from its parent rifle"] call _assert;
private _expectedInterval=(getNumber (_glMode >> "reloadTime") max 0.1)+((getNumber (_glMode >> "aiRateOfFire") max 0.7) min 3);
[abs (((_shot select 1) get "interval")-_expectedInterval)<0.000001 && {((_shot select 1) get "initSpeed")==getNumber (_glConfig >> "initSpeed")},"GL firing metadata uses its own cadence and muzzle speed"] call _assert;
_u set ["weapons",[["arifle_MX_GL_F",[["30Rnd_65x39_caseless_mag",30,[]]]]]];
_shot=[_u,createHashMap,_soft,200] call IVCS_Combat_getVehicleShot;
[(_shot select 1) isEqualRef _parent,"primary rifle attacks retain the original shared weapon profile"] call _assert;
[_a] call _clean;
// Placement must restart after range loss, rather than retaining an old timer.
_a=[] call _make;_u=(_a get "units") select 0;_u set ["weapons",[]];_u set ["magazineCargo",[["DemoCharge_Remote_Mag",1,[]]]];
_v=["O_MBT_02_cannon_F",[14504,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity;_v set ["side","EAST"];
private _e=[_a,_v,0,42] call IVCS_Combat_start;_combat set ["accuracyScale",0];
[_e,1] call IVCS_Combat_update;[_e,2] call IVCS_Combat_update;
[_v,[14506,16400,0]] call IVCS_VirtualSpace_setEntityPosition;[_e,3] call IVCS_Combat_update;
[(_u get "planting") isEqualTo [] && {(_e get "shots")==0},"leaving placement range cancels the incomplete action without consuming a charge"] call _assert;
[_v,[14504,16400,0]] call IVCS_VirtualSpace_setEntityPosition;
for "_t" from 4 to 11 do {[_e,_t] call IVCS_Combat_update};
[(_e get "shots")==0 && {count (_u get "magazineCargo")==1},"returning to placement range pays the entire new placement delay"] call _assert;
[_e,12] call IVCS_Combat_update;
[(_e get "shots")==1 && {(_u get "magazineCargo") isEqualTo []},"a restarted placement consumes exactly one charge on completion"] call _assert;
[_a,_v] call _clean;
_a=[] call _make;_u=(_a get "units") select 0;_u set ["weapons",[]];_u set ["magazineCargo",[["DemoCharge_Remote_Mag",1,[]]]];
_v=["O_MBT_02_cannon_F",[14504,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity;_v set ["side","EAST"];
_e=[_a,_v,0,42] call IVCS_Combat_start;[_e,1] call IVCS_Combat_update;
_u set ["magazineCargo",[["DemoCharge_Remote_Mag",1,[]]]];[_e,2] call IVCS_Combat_update;
for "_t" from 3 to 9 do {[_e,_t] call IVCS_Combat_update};
[(_e get "shots")==0,"replacing the reserved magazine restarts placement instead of inheriting its progress"] call _assert;
[_e,10] call IVCS_Combat_update;
[(_e get "shots")==1,"replacement placement completes after a full delay"] call _assert;
[_a,_v] call _clean;
// An autonomous UGV has an implicit native AI group, not a stored crew group.
_a=["B_Soldier_F"] call _make;
_v=["O_UGV_01_rcws_F",[14700,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity;_v set ["side","EAST"];
_e=[_a,_v,0,42] call IVCS_Combat_start;[_v] call IVCS_VirtualSpace_Vehicle_spawn;
{_x disableAI "ALL"} forEach (_v get "nativeCrew");{(_x get "object") disableAI "ALL"} forEach (_a get "units");
private _body=(_a get "units") select 0 get "object";
[(_v get "nativeCrew") isNotEqualTo [] && {(_v get "nativeCrew") findIf {(group _x) knowsAbout _body<3.9} == -1},"autonomous native UGV crews receive the opposing infantry knowledge"] call _assert;
[_a,_v] call _clean;
// A linked allied UGV also needs the hostile vehicle, rather than friendly infantry.
_a=["B_Soldier_F"] call _make;
private _allied=["B_UGV_01_rcws_F",[14500,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity;
_allied set ["commandingEntity",_a get "id"];(_a get "vehiclesInCommandOf") pushBack (_allied get "id");
_v=["C_Offroad_01_F",[14700,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity;_v set ["side","EAST"];
_e=[_a,_v,0,42] call IVCS_Combat_start;[_v] call IVCS_VirtualSpace_Vehicle_spawn;
{_x disableAI "ALL"} forEach (_allied get "nativeCrew");{(_x get "object") disableAI "ALL"} forEach (_a get "units");
private _enemyObject=_v get "object";
[(_allied get "nativeCrew") isNotEqualTo [] && {(_allied get "nativeCrew") findIf {(group _x) knowsAbout _enemyObject<3.9} == -1},"linked allied UGV crews receive the hostile vehicle knowledge"] call _assert;
[_a,_v,_allied] call _clean;
// Seed-for-seed comparison: caching geometry must preserve all real damage and counters.
_a=["B_Soldier_F","WEST",8] call _make;_pair=["O_MRAP_02_gmg_F"] call _vehicle;_pair params ["_v","_crew"];
_station=([_v] call IVCS_Combat_getReturnFireStations) select 0 select 0;
private _magClass=(_station select 2) select 0 select 0;
_e=[_a,_v,0,42] call IVCS_Combat_start;_combat set ["accuracyScale",100];
private _reset={params ["_seed"];_e set ["seed",_seed];{_e set [_x,0]} forEach ["shots","hits","vehicleShots","vehicleHits"];
 _v set ["turretFireDelays",createHashMap];_station set [2,[[_magClass,10000]]];
 {_x set ["damage",0];{_x set [1,0]} forEach (_x get "hitpoints")} forEach (_a get "units")};
private _snapshot={
 private _values=[_e get "seed",_e get "shots",_e get "hits",_e get "vehicleShots",_e get "vehicleHits",[_v] call _ammo];
 {_values pushBack (_x get "damage");_values append ((_x get "hitpoints") apply {_x select 1})} forEach (_a get "units");_values
};
private _same=true;
for "_seed" from 1 to 32 do {
 [_seed] call _reset;[_e,_a,_v,200,1] call IVCS_Review_BeforeReturn;private _before=call _snapshot;
 [_seed] call _reset;[_e,_a,_v,200,1] call IVCS_Combat_stepReturnFire;private _after=call _snapshot;
  // Damage algebra can differ below engine precision; identity/counter values are also checked.
 for "_i" from 0 to (count _before-1) do {
  if (abs((_before select _i)-(_after select _i))>0.00001) then {_same=false;diag_log format ["[IVCS REVIEW DIFF] %1",[_seed,_i,_before select _i,_after select _i]]};
 };
};
[_same,"cached splash preserves seeds, counters, ammunition and anatomical damage across 32 seeds"] call _assert;
// Hold the count constant while replacing all records: cache entries must not retain old units.
private _savedRoster=_a get "units";private _replacement=[];
for "_i" from 0 to 7 do {_replacement pushBack (["B_Soldier_F",format ["replacement_%1",_i]] call IVCS_VirtualSpace_Group_createUnit)};
_a set ["units",_replacement];private _damageUnit=IVCS_Combat_damageUnit;private _damaged=[];
IVCS_Combat_damageUnit={_damaged pushBack (_this select 0)};
[42] call _reset;[_e,_a,_v,200,1] call IVCS_Combat_stepReturnFire;
[_damaged isNotEqualTo [] && {_damaged findIf {private _victim=_x;_replacement findIf {_x isEqualRef _victim} == -1} == -1},"warm splash caches use current unit records after roster replacement"] call _assert;
_combat set ["blastSpacing",30];_damaged=[];[42] call _reset;[_e,_a,_v,200,1] call IVCS_Combat_stepReturnFire;
[count _damaged==(_e get "vehicleHits"),"changing formation spacing invalidates splash footprints"] call _assert;
_a set ["units",[_replacement select 0]];_damaged=[];[42] call _reset;[_e,_a,_v,200,1] call IVCS_Combat_stepReturnFire;
[count _damaged==(_e get "vehicleHits"),"changing target count invalidates splash footprints without stale indices"] call _assert;
_a set ["units",_savedRoster];_combat set ["blastSpacing",6];IVCS_Combat_damageUnit=_damageUnit;
// A batch microbenchmark measures identical HE work, including identical fixture resets.
private _timings=[];
for "_trial" from 1 to 4 do {
 private _order=if (_trial mod 2==0) then {[true,false]} else {[false,true]};
 {
  private _after=_x;private _code=if (_after) then {IVCS_Combat_stepReturnFire} else {IVCS_Review_BeforeReturn};
  for "_warmup" from 1 to 20 do {[_warmup] call _reset;[_e,_a,_v,200,1] call _code};
  private _elapsed=0;
  isNil {private _start=diag_tickTime;for "_i" from 1 to 300 do {[_i] call _reset;[_e,_a,_v,200,1] call _code};_elapsed=diag_tickTime-_start};
  _timings pushBack [_trial,_after,300,_elapsed*1000];
 } forEach _order;
};
diag_log format ["[IVCS REVIEW HE BATCH] %1",_timings];
[count _timings==8,"HE microbenchmark records four paired trials with reversed order"] call _assert;
[_a,_v,_crew] call _clean;_combat set ["accuracyScale",1.1];
[count (IVCS_VirtualSpace_Controller get "entities" get "ALL")==0,"vehicle review fixtures leave no registered entities"] call _assert;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
