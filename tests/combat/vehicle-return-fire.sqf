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
private _ledger={params ["_v"];private _r=[];{private _path=_x select 0;{_r pushBack [str _path,_x select 0,_x select 1]} forEach (_x select 2)} forEach (_v get "turrets");_r sort true;_r};
private _run={params ["_e","_until"];for "_t" from 1 to _until do {if ((_e get "mode")=="finished") exitWith {};[_e,_t] call IVCS_Combat_update;while {(_e get "mode")!="finished" && {(_e get "pending")>=1}} do {[_e,_t] call IVCS_Combat_update}}};
private _a=["B_Soldier_F"] call _make;
private _pair=[] call _vehicle;_pair params ["_v","_crew"];
diag_log format ["[IVCS RETURN CONFIG] %1",_v get "turrets"];
private _stations=[_v] call IVCS_Combat_getReturnFireStations;
[count _stations==1,"a manned HMG turret has exactly one firing station"] call _assert;
private _station=(_stations select 0) select 0;
private _shot=[_station,createHashMap,200] call IVCS_Combat_getReturnFireShot;
diag_log format ["[IVCS RETURN SHOT] %1",_shot];
[_shot isNotEqualTo [],"stock HMG finds infantry-capable compatible ammunition"] call _assert;
if (_shot isEqualTo []) exitWith {diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed]};
private _near=[_station,createHashMap,50] call IVCS_Combat_getReturnFireShot;
[(_near select 3 select 0)>(_shot select 3 select 0),"return fire accuracy decreases with range"] call _assert;
private _before=[_v] call _ammo;
private _e=[_a,_v,0,42] call IVCS_Combat_start;
[!isNil "_e","armed land vehicles can engage rifle infantry that cannot penetrate their armor"] call _assert;
_combat set ["accuracyScale",0];[_e,1] call IVCS_Combat_update;
[(_e get "vehicleShots")>0 && {([_v] call _ammo)==_before-(_e get "vehicleShots")},"turret shots expend their own exact ammunition counts"] call _assert;
[(_a get "units") findIf {(_x get "damage")>0} == -1,"missed return fire does not injure infantry"] call _assert;
private _savedShots=_e get "vehicleShots";
[_crew,((_stations select 0) select 1)] call IVCS_VirtualSpace_Group_onUnitLeaveVehicle;
[_e,2] call IVCS_Combat_update;
[(_e get "vehicleShots")==_savedShots,"a turret stops firing as soon as its gunner leaves"] call _assert;
[_a,_v,_crew] call _clean;
// Driver-only and unmanned stations.
_a=["B_Soldier_F"] call _make;_pair=["O_MRAP_02_hmg_F",1] call _vehicle;_pair params ["_v","_crew"];
[([_v] call IVCS_Combat_getReturnFireStations) isEqualTo [],"a driver cannot operate an empty gunner seat"] call _assert;
[_a,_v,_crew] call _clean;
_v=["O_UGV_01_rcws_F",[14700,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity;
[count ([_v] call IVCS_Combat_getReturnFireStations)>0,"armed ground UAVs can operate their unmanned turrets"] call _assert;
[_v] call _clean;
// Vehicle discovery also reaches native infantry, which cannot scan for virtual opponents.
_a=["B_Soldier_F"] call _make;
_v=["O_UGV_01_rcws_F",[14700,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity;_v set ["side","EAST"];
[_v,1] call IVCS_VirtualSpace_Vehicle_update;
[(_v get "combatID")!="" && {(_v get "combatID")==(_a get "combatID")},"armed ground UAVs discover rifle infantry without a crew group scan"] call _assert;
[_a,_v] call _clean;
_a=["B_Soldier_F"] call _make;[_a] call IVCS_VirtualSpace_Group_spawn;
{(_x get "object") disableAI "ALL"} forEach (_a get "units");
_pair=[] call _vehicle;_pair params ["_v","_crew"];
[_v,1] call IVCS_VirtualSpace_Vehicle_update;
[(_v get "combatID")!="" && {(_v get "combatID")==(_a get "combatID")},"virtual land vehicles discover infantry that is already native"] call _assert;
private _nativeEngagement=(_combat get "engagements") get (_v get "combatID");
[!isNil "_nativeEngagement" && {(_nativeEngagement get "mode")=="native"} && {_v get "active"} && {_crew get "active"},"discovering native infantry hands the vehicle and crew to Arma"] call _assert;
[_a,_v,_crew] call _clean;
// Fixed-wing and sea return fire remain excluded even with a complete crew.
{
 _pair=[_x,6] call _vehicle;_pair params ["_v","_crew"];
 [([_v] call IVCS_Combat_getReturnFireStations) isEqualTo [],format ["%1 does not return fire virtually",_x]] call _assert;
 [_v,_crew] call _clean;
} forEach ["O_Plane_CAS_02_dynamicLoadout_F","O_Boat_Armed_01_hmg_F"];
// Native weapon policy and compatibility, independent of stored magazine order.
_pair=["O_MBT_02_cannon_F",3] call _vehicle;_pair params ["_v","_crew"];
_stations=[_v] call IVCS_Combat_getReturnFireStations;
{
 private _s=[_x select 0,createHashMap,200] call IVCS_Combat_getReturnFireShot;
 if (_s isNotEqualTo []) then {[(_s select 2) get "infantrySupported", "selected tank ammunition permits infantry attacks"] call _assert;[(_s select 2) get "bullet" && {((_s select 2) get "blast")==0},"tank stations prefer their machine gun to HE when loaded"] call _assert};
} forEach _stations;
private _gun=_stations select 0 select 0;
private _savedMags=(_gun select 2) apply {+_x};
_gun set [2,[["Titan_AA",1],["SmokeShell",1],["30Rnd_65x39_caseless_mag",30]]];
[([_gun,createHashMap,200] call IVCS_Combat_getReturnFireShot) isEqualTo [],"AA, smoke and incompatible rifle magazines cannot supply a tank turret"] call _assert;
_gun set [2,_savedMags];
private _wp=([_v get "class"] call IVCS_Combat_getVehicleProfile) get "weaponDamage";
private _disabled=_wp getOrDefault [str (_gun select 0),[]];
[count _disabled>0,"gun/turret component indices are prepared per station"] call _assert;
{(_v get "hitpoints" select _x) set [1,1]} forEach _disabled;
[([_v] call IVCS_Combat_getReturnFireStations) findIf {((_x select 0) select 0) isEqualTo (_gun select 0)} == -1,"a destroyed gun or turret disables its own firing station"] call _assert;
[_v,_crew] call _clean;
// Injury, anatomical selection and live ammunition conservation.
_a=["B_Soldier_F"] call _make;_pair=[] call _vehicle;_pair params ["_v","_crew"];
_e=[_a,_v,0,42] call IVCS_Combat_start;_combat set ["accuracyScale",100];
[_e,4] call _run;
[(_e get "hits")>0 && {(_e get "casualties")>0 || {(_a get "units") findIf {(_x get "hitpoints") findIf {(_x select 1)>0} != -1} != -1}},"successful vehicle shots damage actual infantry hitpoints or kill units"] call _assert;
[_a,_v,_crew] call _clean;
_a=["B_Soldier_F"] call _make;_pair=[] call _vehicle;_pair params ["_v","_crew"];
_combat set ["accuracyScale",0];_e=[_a,_v,0,42] call IVCS_Combat_start;[_e,1] call IVCS_Combat_update;
private _virtualLedger=[_v] call _ledger;
[_v] call IVCS_VirtualSpace_Vehicle_spawn;
{(_x get "object") disableAI "ALL"} forEach (_a get "units");{(_x get "object") disableAI "ALL"} forEach (_crew get "units");
[(_e get "mode")=="native","return-fire engagements hand off both groups and the vehicle"] call _assert;
private _nativeLedger=(magazinesAllTurrets [_v get "object",true]) apply {[str (_x select 1),_x select 0,_x select 2]};_nativeLedger=_nativeLedger select {(_x select 2)>0};_nativeLedger sort true;
[_nativeLedger isEqualTo _virtualLedger,"native spawning preserves remaining turret ammunition exactly"] call _assert;
_savedShots=_e get "vehicleShots";[_e,100] call IVCS_Combat_update;
[(_e get "vehicleShots")==_savedShots,"native combat receives no duplicate virtual return fire"] call _assert;
[_v] call IVCS_VirtualSpace_Vehicle_despawn;
[([_v] call _ledger) isEqualTo _virtualLedger && {(_e get "mode")=="virtual"},"native capture preserves partial turret magazines and resumes virtual combat"] call _assert;
[_a,_v,_crew] call _clean;
// Empty belts cannot supply free rounds, and recovery considers both sides' weapons.
_a=["B_Soldier_F"] call _make;_pair=[] call _vehicle;_pair params ["_v","_crew"];
_stations=[_v] call IVCS_Combat_getReturnFireStations;_station=_stations select 0 select 0;
_shot=[_station,createHashMap,200] call IVCS_Combat_getReturnFireShot;
{_x set [2,[]]} forEach (_v get "turrets");_station set [2,[[(_shot select 0) select 0,1]]];
_e=[_a,_v,0,42] call IVCS_Combat_start;[_e,16] call _run;
[(_e get "vehicleShots")==1 && {([_v] call _ammo)==0},"the final turret round is consumed exactly once"] call _assert;
[(_e get "mode")=="finished" && {(_e get "reason")=="ammunition"},"exhaustion of both effective sides releases the engagement"] call _assert;
[_a,_v,_crew] call _clean;
_a=["B_Soldier_F"] call _make;_pair=[] call _vehicle;_pair params ["_v","_crew"];
_e=[_a,_v,0,42] call IVCS_Combat_start;
{(_v get "turretFireDelays") set [str (_x select 0),100]} forEach (_v get "turrets");[_e,20] call _run;
[(_e get "mode")=="virtual" && {(_e get "vehicleShots")==0},"a land vehicle with usable ammunition survives a long firing cadence"] call _assert;
[_a,_v,_crew] call _clean;
// Enclosed passengers do not take direct infantry return-fire hits through their transport.
_a=["B_Soldier_F"] call _make;private _ride=["B_MRAP_01_F",[14500,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity;
[_a,_ride] call IVCS_VirtualSpace_Group_assignVehicle;_pair=[] call _vehicle;_pair params ["_v","_crew"];
_combat set ["autoDismount",false];
[([_a] call IVCS_Combat_getReturnFireTargets) isEqualTo [],"closed mounted infantry is excluded from exposed return-fire targets"] call _assert;
[isNil {[_a,_v,0,42] call IVCS_Combat_start},"an armored fight is not invented through a protected transport"] call _assert;
_combat set ["autoDismount",true];[_a,_ride,_v,_crew] call _clean;
{
// HE shell impacts approximate splash across a six-metre virtual formation.
_a=["B_Soldier_F"] call _make;{_x set ["weapons",[]];_x set ["magazineCargo",[]]} forEach (_a get "units");
_pair=[_x,3] call _vehicle;_pair params ["_v","_crew"];
_stations=[_v] call IVCS_Combat_getReturnFireStations;private _heStation=[];private _heMag=[];
private _largestRadius=0;
{
 private _turret=_x select 0;
 {
  private _ammo=[_x select 0] call IVCS_Combat_getAmmoProfile;
  if (_ammo get "infantrySupported" && {(_ammo get "blast")>0} && {(_ammo get "blastRadius")>_largestRadius}) then {
   _largestRadius=_ammo get "blastRadius";_heStation=_turret;_heMag=+_x;
  };
 } forEach (_turret select 2);
} forEach _stations;
diag_log format ["[IVCS RETURN HE] %1",[_heMag,_largestRadius]];
[_heStation isNotEqualTo [],format ["%1 has compatible infantry-capable HE ammunition",_v get "class"]] call _assert;
if (_heStation isNotEqualTo []) then {
 { _x set [2,[]] } forEach (_v get "turrets");_heStation set [2,[_heMag]];
 _shot=[_heStation,createHashMap,200] call IVCS_Combat_getReturnFireShot;
 [_shot isNotEqualTo [] && {((_shot select 2) get "blast")>0},"a station with only HE selects its compatible explosive ammunition"] call _assert;
 _e=[_a,_v,0,42] call IVCS_Combat_start;
 private _sample=IVCS_Combat_sampleHits;IVCS_Combat_sampleHits={1};
 private _victims=(_a get "units") select [0];[_e,1] call IVCS_Combat_update;IVCS_Combat_sampleHits=_sample;
 diag_log format ["[IVCS RETURN HE DAMAGE] %1",[_victims apply {_x get "damage"},_e get "casualties"]];
 [{(_x get "damage")>0} count _victims>1,"one HE impact damages multiple exposed squadmates"] call _assert;
 [(_e get "vehicleHits")==1 && {(_e get "hits")==1},"splash victims do not inflate the projectile hit counter"] call _assert;
};
[_a,_v,_crew] call _clean;
} forEach ["O_MBT_02_cannon_F","O_MRAP_02_gmg_F"];
// Accuracy follows live gunner arm injuries; cached shot factors must not conceal them.
_a=["B_Soldier_F"] call _make;_pair=[] call _vehicle;_pair params ["_v","_crew"];
_e=[_a,_v,0,42] call IVCS_Combat_start;_combat set ["accuracyScale",1.1];
_stations=[_v] call IVCS_Combat_getReturnFireStations;_station=_stations select 0 select 0;
private _gunner=_stations select 0 select 1;private _arms=([_gunner] call IVCS_Combat_getHitpointLayout) select 2;
_shot=[_station,createHashMap,200] call IVCS_Combat_getReturnFireShot;private _magClass=_shot select 0 select 0;
private _damageUnit=IVCS_Combat_damageUnit;IVCS_Combat_damageUnit={};
private _outcomes=[];
for "_injury" from 0 to 1 do {
 {(_gunner get "hitpoints" select _x) set [1,_injury]} forEach _arms;
 private _totalHits=0;private _totalShots=0;
 for "_seed" from 1 to 24 do {
  _station set [2,[[_magClass,1000]]];_v set ["turretFireDelays",createHashMap];
  _e set ["seed",_seed];_e set ["vehicleHits",0];_e set ["vehicleShots",0];_e set ["hits",0];_e set ["shots",0];
  [_e,_a,_v,200,10] call IVCS_Combat_stepReturnFire;
  _totalHits=_totalHits+(_e get "vehicleHits");_totalShots=_totalShots+(_e get "vehicleShots");
 };
 _outcomes pushBack [_totalHits,_totalShots];
};
IVCS_Combat_damageUnit=_damageUnit;
[(_outcomes select 1 select 0)<(_outcomes select 0 select 0) && {(_outcomes select 1 select 1)==(_outcomes select 0 select 1)},"arm injuries lower gunner hit rate without changing ammunition expenditure"] call _assert;
[_a,_v,_crew] call _clean;
// Both sides fire in the same resolution interval even if each destroys the other.
_a=["B_soldier_LAT_F","WEST",1] call _make;_pair=[] call _vehicle;_pair params ["_v","_crew"];
private _fighter=(_a get "units") select 0;_fighter set ["weapons",[["launch_NLAW_F",[["NLAW_F",1,[]]]]]];_fighter set ["magazineCargo",[]];
_v set ["damage",0.999];_fighter set ["damage",0.99];
_e=[_a,_v,0,42] call IVCS_Combat_start;
private _sample=IVCS_Combat_sampleHits;IVCS_Combat_sampleHits={params ["_attempts"];_attempts};
_combat set ["accuracyScale",100];[_e,1] call IVCS_Combat_update;IVCS_Combat_sampleHits=_sample;
[(_v get "damage")==1 && {(_fighter get "damage")==1},"infantry and vehicle lethal shots are simultaneous"] call _assert;
[(_e get "mode")=="finished" && {(_e get "vehicleShots")>0} && {(_e get "shots")>(_e get "vehicleShots")},"mutual destruction cleans up after both sides expend ammunition"] call _assert;
[_a,_v,_crew] call _clean;
_combat set ["accuracyScale",1.1];
[count (IVCS_VirtualSpace_Controller get "entities" get "ALL")==0,"return-fire fixtures leave no entities"] call _assert;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
