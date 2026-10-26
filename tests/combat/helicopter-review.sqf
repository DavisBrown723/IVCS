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
private _make={params [["_class","O_Soldier_F"],["_side","EAST"],["_count",4],["_pos",[14500,16400,0]]];private _units=[];for "_i" from 0 to (_count-1) do {_units pushBack ([_class,format ["u%1",_i]] call IVCS_VirtualSpace_Group_createUnit)};[_side,"OPF_F",+_pos,_units] call IVCS_VirtualSpace_Group_createEntity};
private _heli={params [["_class","B_Heli_Attack_01_dynamicLoadout_F"],["_pos",[15100,16400,100]]];private _v=[_class,+_pos] call IVCS_VirtualSpace_Vehicle_createEntity;private _count=0;{if ((_x select 0)!="Cargo") then {_count=_count+count (_x select 1)}} forEach (_v get "seats");private _crew=["B_helicrew_F","WEST",_count,+_pos] call _make;[_crew,_v] call IVCS_VirtualSpace_Group_assignVehicle;[_v,_crew]};
private _order={params ["_crew",["_role","ATTACK"],["_mode","YELLOW"],["_behavior","AWARE"]];private _wp=[[16000,16400,0],"MOVE",[["airAttackCenter",[14500,16400,0]],["airCombatRole",_role],["combatMode",_mode],["behavior",_behavior]]] call IVCS_VirtualSpace_createEntityWaypoint;[_crew,_wp] call IVCS_VirtualSpace_entityAddWaypoint;_wp};
private _clean={{if (!isNil {[_x get "id"] call IVCS_VirtualSpace_getEntity}) then {if (_x get "active") then {[_x] call (missionNamespace getVariable (_x get "despawn"))};[_x] call IVCS_VirtualSpace_unregisterEntity}} forEach _this};
private _ammo={params ["_v"];private _n=0;{{_n=_n+(_x select 1)} forEach (_x select 2);{_n=_n+(_x select 2)} forEach (_x select 3)} forEach (_v get "turrets");_n};
private _ledger={params ["_v"];private _result=[];{private _path=_x select 0;{_result pushBack [str _path,_x select 0,_x select 1]} forEach (_x select 2);{_result pushBack [_x select 0,_x select 1,_x select 2]} forEach (_x select 3)} forEach (_v get "turrets");_result sort true;_result};

// Live AA eligibility must read current physical weapons and rounds, without mutating virtual inventories.
_combat set ["accuracyScale",0];
private _pair=[] call _heli;_pair params ["_h","_crew"];
private _wp=[_crew] call _order;private _a=[] call _make;
private _e=[_a,_h] call IVCS_Combat_start;
private _aa=["O_Soldier_AA_F","EAST",1,[14600,16400,0]] call _make;
[_aa] call IVCS_VirtualSpace_Group_spawn;
private _soldier=(_aa get "units" select 0) get "object";_soldier disableAI "ALL";
private _loadout=getUnitLoadout _soldier;removeAllWeapons _soldier;
[!([_aa,_h,true] call IVCS_Combat_canShootHelicopter),"native AA eligibility rejects a removed launcher and its stale stored ammunition"] call _assert;
[isNil {[_aa,_h] call IVCS_Combat_start} && {(_aa get "combatID")==""} && {(_e get "mode")=="virtual"},"unarmed native support cannot claim or spawn a virtual engagement"] call _assert;
_soldier setUnitLoadout _loadout;
[[_aa,_h,true] call IVCS_Combat_canShootHelicopter,"native AA eligibility recognizes the restored physical launcher and ammunition"] call _assert;
{_soldier removeMagazines (_x select 0)} forEach (magazinesAmmoFull [_soldier,true]);
_soldier setAmmo [secondaryWeapon _soldier,0];
[secondaryWeapon _soldier!="" && {!([_aa,_h,true] call IVCS_Combat_canShootHelicopter)},"a retained native launcher with no live ammunition cannot contribute AA support"] call _assert;
[_a,_aa,_h,_crew] call _clean;

_pair=[] call _heli;_pair params ["_h","_crew"];_wp=[_crew] call _order;_a=[] call _make;_e=[_a,_h] call IVCS_Combat_start;
private _v=["O_APC_Tracked_02_AA_F",[14650,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity;
private _vc=["O_crew_F","EAST",3,[14650,16400,0]] call _make;[_vc,_v] call IVCS_VirtualSpace_Group_assignVehicle;
[_v] call IVCS_VirtualSpace_Vehicle_spawn;
{(_x get "object") disableAI "ALL"} forEach (_vc get "units");
private _ledgerBefore=[_v] call _ledger;
(_v get "object") setVehicleAmmo 0;
[!([_v,_h,true] call IVCS_Combat_canShootHelicopter),"native AA vehicle eligibility rejects physically exhausted turret ammunition"] call _assert;
[([_v] call _ledger) isEqualTo _ledgerBefore,"native eligibility probes do not overwrite the stored virtual ammunition ledger"] call _assert;
(_v get "object") setVehicleAmmo 1;
[[ _v,_h,true] call IVCS_Combat_canShootHelicopter,"native AA vehicle eligibility recognizes physical rearmament"] call _assert;
[_a,_v,_vc,_h,_crew] call _clean;

// Disabling an aircraft during a native reposition must release temporary ownership immediately.
_pair=[] call _heli;_pair params ["_h","_crew"];_wp=[_crew] call _order;_a=[] call _make;_e=[_a,_h] call IVCS_Combat_start;
_e set ["startedAt",IVCS_SimulationTime-9];[_h] call IVCS_VirtualSpace_Vehicle_spawn;
{(_x get "object") disableAI "ALL"} forEach ((_a get "units")+(_crew get "units"));
[_crew,_h,1] call IVCS_Combat_updateHelicopter;
[(_h get "airMovementOverride") && {(_h get "airPassModes") isNotEqualTo []},"native reposition initially owns movement and firing holds"] call _assert;
(_crew get "group") setCombatMode "RED";
[_h,true] call IVCS_Combat_setHelicopterPassHold;
[(_crew get "units") findIf {unitCombatMode (_x get "object")!="BLUE"} == -1,"a native group-mode change cannot cancel a reposition hold"] call _assert;
[_h,false] call IVCS_Combat_setHelicopterPassHold;
[(_crew get "units") findIf {unitCombatMode (_x get "object")!="RED"} == -1,"releasing a hold respects the group's newer combat mode"] call _assert;
(_crew get "group") setCombatMode "YELLOW";
{(_x get "object") setUnitCombatMode "YELLOW"} forEach (_crew get "units");
[_crew,_h,1] call IVCS_Combat_updateHelicopter;
_h set ["speedPerSecond",0];[_crew,_h,1] call IVCS_Combat_updateHelicopter;
[!(_h get "airMovementOverride") && {(_h get "nativeAirDestination") isEqualTo []} && {isNull (_h get "nativeAirTarget")},"disabled helicopter releases combat movement and target ownership"] call _assert;
[(_h get "airPassModes") isEqualTo [] && {(_crew get "units") findIf {unitCombatMode (_x get "object")!="YELLOW"} == -1},"disabled helicopter restores crew fire modes instead of leaving them BLUE"] call _assert;
[_a,_h,_crew] call _clean;

// Area disengagement must clear the assigned native attack target even while defensive evasion continues.
_pair=[] call _heli;_pair params ["_h","_crew"];_wp=[_crew] call _order;_a=[] call _make;_e=[_a,_h] call IVCS_Combat_start;
[_h] call IVCS_VirtualSpace_Vehicle_spawn;
{(_x get "object") disableAI "ALL"} forEach ((_a get "units")+(_crew get "units"));
[_crew,_h,1] call IVCS_Combat_updateHelicopter;
[_a,[13749,16400,0]] call IVCS_VirtualSpace_setEntityPosition;[_h,_a] call IVCS_Combat_markAirThreat;
[_crew,_h,1] call IVCS_Combat_updateHelicopter;
[(_e get "mode")=="finished" && {isNull (_h get "nativeAirTarget")} && {_h get "airMovementOverride"},"area exit releases the native attack target while retaining temporary defensive evasion"] call _assert;
[_a,_h,_crew] call _clean;

// The normal vehicle update must retain forced-descent velocity for a subsequent native handoff.
_pair=[] call _heli;_pair params ["_h","_crew"];_wp=[_crew] call _order;_a=[] call _make;_e=[_a,_h] call IVCS_Combat_start;
_h set ["speedPerSecond",0];[_crew] call IVCS_VirtualSpace_Group_calculateSpeed;
[_crew,_h,1] call IVCS_Combat_updateHelicopter;[_h,1] call IVCS_VirtualSpace_Vehicle_update;
[(_h get "airMovementOverride") && {((_h get "flightVelocity") select 2)<0},"vehicle updates preserve forced-descent flight velocity for native handoff"] call _assert;
[_a,_h,_crew] call _clean;

// Clamping a flight destination must not put the aircraft outside its own attack area through float rounding.
_pair=[] call _heli;_pair params ["_h","_crew"];_wp=[_crew] call _order;_a=[] call _make;_e=[_a,_h] call IVCS_Combat_start;
private _outside=0;
for "_angle" from 0 to 355 step 5 do {
    private _hp=[14500,16400,0] getPos [740,_angle];_hp set [2,100];
    private _ip=[14500,16400,0] getPos [700,_angle];
    [_h,_hp] call IVCS_VirtualSpace_setEntityPosition;[_crew,+_hp] call IVCS_VirtualSpace_setEntityPosition;[_a,_ip] call IVCS_VirtualSpace_setEntityPosition;
    _e set ["startedAt",IVCS_SimulationTime];_e deleteAt "passBearing";
    [_crew,_h,100] call IVCS_Combat_updateHelicopter;
    if (!([_h,_a] call IVCS_Combat_inHelicopterAttackArea)) then {_outside=_outside+1};
    [_crew,_h,0] call IVCS_Combat_updateHelicopter;
};
[_outside==0 && {(_e get "mode")=="virtual"},"clamped flight destinations remain inside the attack area at every tested bearing"] call _assert;
[_a,_h,_crew] call _clean;

// Exposure scales the final hit probability, including weapons already at the accuracy cap.
_pair=[] call _heli;_pair params ["_h","_crew"];_wp=[_crew] call _order;_a=[] call _make;_e=[_a,_h] call IVCS_Combat_start;
_combat set ["accuracyScale",100];
[_a,_h,IVCS_SimulationTime-13] call IVCS_Combat_markInfantryAirThreat;
_e set ["stepTime",IVCS_SimulationTime];
private _sample=IVCS_Combat_sampleHits;private _probability=0;
IVCS_Combat_sampleHits={_probability=_probability max (_this select 1);0};
[_e,_a,_h,100,1] call IVCS_Combat_stepReturnFire;
IVCS_Combat_sampleHits=_sample;
[abs (_probability-0.28)<0.0001,"full cover reduces capped helicopter hit probability from 0.8 to 0.28"] call _assert;
[_a,_h,_crew] call _clean;
_combat set ["accuracyScale",0];

// AA supporters receive the same in-progress sharing grace as primary combatants.
_pair=[] call _heli;_pair params ["_h","_crew"];_wp=[_crew] call _order;_a=[] call _make;
private _start=IVCS_SimulationTime;_e=[_a,_h,_start] call IVCS_Combat_start;
_aa=["O_Soldier_AA_F","EAST",1,[14600,16400,0]] call _make;[_aa,_h,_start] call IVCS_Combat_start;
{{(_x select 1) resize 0} forEach (_x get "weapons")} forEach (_aa get "units");
{(_x select 2) resize 0;{_x set [2,0]} forEach (_x select 3)} forEach (_h get "turrets");
(_aa get "ammoRequests") pushBack (createHashMapFromArray [["native",false]]);
// Freeze an in-flight collection while exercising the combat timeout decision alone.
private _updateAmmo=IVCS_Ammo_updateGroup;IVCS_Ammo_updateGroup={};
_e set ["lastUpdate",_start+15];[_e,_start+16] call IVCS_Combat_update;
[(_e get "mode")=="virtual","supporter ammunition collection retains the engagement during sharing grace"] call _assert;
private _sharing=_combat get "ammoSharing";
private _deadline=_start+(_combat get "ammoTimeout")+(_sharing get "virtualApproachDelay")+(_sharing get "collectionDelay")+(_combat get "reloadDelay")+1;
_e set ["lastUpdate",_deadline-1];[_e,_deadline] call IVCS_Combat_update;
IVCS_Ammo_updateGroup=_updateAmmo;
[(_e get "mode")=="finished" && {(_e get "reason")=="ammunition"},"dry support eventually disengages when sharing grace expires"] call _assert;
[_a,_aa,_h,_crew] call _clean;

// Phase-only queries and boundary integration keep the same clock semantics.
private _phaseEng=createHashMapFromArray [["startedAt",0]];
private _phase=[_phaseEng,0,33] call IVCS_Combat_getHelicopterPass;
[(_phase select 0)==0 && {_phase select 1} && {(_phase select 2)==1} && {(_phase select 3) isEqualTo []},"phase-only queries begin the next pass without constructing firing segments"] call _assert;
private _window=[_phaseEng,35,34] call IVCS_Combat_getHelicopterPass;
[abs ((_window select 0)-9)<0.0001 && {count (_window select 3)==3},"integration clips before engagement start and spans multiple pass boundaries"] call _assert;
[count (_combat get "engagements")==0 && {(_combat get "queue") isEqualTo []},"review fixtures release every combat reservation"] call _assert;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
