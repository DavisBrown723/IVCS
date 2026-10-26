// Integration coverage for the second infantry/vehicle combat increment.
waitUntil {time>0};
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
IVCS_Common_WeaponInfo=createHashMap; IVCS_Common_MagazineInfo=createHashMap; IVCS_Common_AmmoInfo=createHashMap;
IVCS_Common_UnitInfo=createHashMap; IVCS_Common_WeaponAliases=createHashMap; IVCS_Common_VehicleConfigInventories=createHashMap;
IVCS_Common_VehicleTurrets=[] call IVCS_Common_getAllVehicleTurretsFromConfig;
IVCS_Paths_Generator=createHashMapFromArray [["requestQueue",[]],["currentRequest",[]]];
IVCS_VirtualSpace_Controller=[false] call IVCS_VirtualSpace_createController;
removeMissionEventHandler ["EachFrame",IVCS_VirtualSpace_Controller get "onFrameHandlerID"];
west setFriend [east,0];east setFriend [west,0];
private _passed=0;private _failed=0;
private _assert={params ["_ok","_label"];if (_ok) then {_passed=_passed+1} else {_failed=_failed+1};diag_log format ["[IVCS TASK TEST] %1 %2",if (_ok) then {"PASS"} else {"FAIL"},_label]};
private _combat=IVCS_VirtualSpace_Controller get "combat";
private _make={
 params [["_class","B_soldier_LAT_F"],["_side","WEST"],["_position",[14500,16400,0]]];
 private _u=[_class,"u0"] call IVCS_VirtualSpace_Group_createUnit;
 [_side,"BLU_F",+_position,[_u]] call IVCS_VirtualSpace_Group_createEntity
};
private _target={params [["_class","O_MBT_02_cannon_F"],["_position",[14700,16400,0]]];private _v=[_class,+_position] call IVCS_VirtualSpace_Vehicle_createEntity;_v set ["side","EAST"];_v};
private _clean={{if (_x get "active") then {[_x] call (missionNamespace getVariable (_x get "despawn"))};[_x] call IVCS_VirtualSpace_unregisterEntity} forEach _this};
private _run={params ["_eng","_until"];for "_t" from 1 to _until do {if ((_eng get "mode")=="finished") exitWith {};[_eng,_t] call IVCS_Combat_update;while {(_eng get "pending")>=1 && {(_eng get "mode")!="finished"}} do {[_eng,_t] call IVCS_Combat_update}}};
private _equip={params ["_u","_weapon","_mag",["_count",3]];private _m=[];for "_i" from 1 to _count do {_m pushBack [_mag,1,[]]};_u set ["weapons",[[_weapon,_m]]];_u set ["magazineCargo",[]]};
private _soft=["C_Offroad_01_F"] call IVCS_Combat_getVehicleProfile;
private _armor=["O_MBT_02_cannon_F"] call IVCS_Combat_getVehicleProfile;
private _air=["O_Heli_Light_02_unarmed_F"] call IVCS_Combat_getVehicleProfile;
[(_combat get "contactTimeout")==30 && {(_combat get "ammoTimeout")==15},"recovery uses the requested 30s contact and 15s ammunition timers"] call _assert;
private _a=[] call _make;private _u=(_a get "units") select 0;
[_u,"arifle_MX_GL_F","1Rnd_HE_Grenade_shell"] call _equip;
private _shot=[_u,createHashMap,_soft,50] call IVCS_Combat_getVehicleShot;
[_shot isNotEqualTo [] && {(_shot select 9)==2},"compatible grenade-launcher muzzle can attack soft vehicles"] call _assert;
[([_u,createHashMap,_armor,50] call IVCS_Combat_getVehicleShot) isEqualTo [],"HE grenades do not substitute for anti-armor ammunition"] call _assert;
[([_u,createHashMap,_soft,2] call IVCS_Combat_getVehicleShot) isEqualTo [],"grenade launcher observes a minimum safe range"] call _assert;
[_u,"launch_B_Titan_F","Titan_AA"] call _equip;
[([_u,createHashMap,_air,200] call IVCS_Combat_getVehicleShot) isNotEqualTo [] && {([_u,createHashMap,_soft,200] call IVCS_Combat_getVehicleShot) isEqualTo []},"AA missiles are accepted for aircraft and rejected for ground targets"] call _assert;
[_u,"launch_RPG32_F","RPG32_F"] call _equip;
[([_u,createHashMap,_air,200] call IVCS_Combat_getVehicleShot) isEqualTo [],"unguided ground rockets are not used for airborne targets"] call _assert;
_u set ["weapons",[]];_u set ["magazineCargo",[["HandGrenade",1,[]]]];
_shot=[_u,createHashMap,_soft,20] call IVCS_Combat_getVehicleShot;
[_shot isNotEqualTo [] && {(_shot select 9)==3},"hand grenades are selected from compatible utility cargo"] call _assert;
[([_u,createHashMap,_soft,36] call IVCS_Combat_getVehicleShot) isEqualTo [],"hand grenades cannot be thrown beyond their virtual reach"] call _assert;
_u set ["magazineCargo",[["SmokeShell",1,[]],["30Rnd_65x39_caseless_mag",30,[]]]];
[([_u,createHashMap,_soft,20] call IVCS_Combat_getVehicleShot) isEqualTo [],"smoke and incompatible support ammunition cannot cause vehicle damage"] call _assert;
{
 _u set ["magazineCargo",[[_x,1,[]]]];
 _shot=[_u,createHashMap,_armor,4] call IVCS_Combat_getVehicleShot;
 [_shot isNotEqualTo [] && {(_shot select 9)==4},format ["%1 can be placed against armor at close range",_x]] call _assert;
 [([_u,createHashMap,_armor,6] call IVCS_Combat_getVehicleShot) isEqualTo [],format ["%1 cannot be placed remotely at a distant target",_x]] call _assert;
} forEach ["DemoCharge_Remote_Mag","ATMine_Range_Mag"];
[_a] call _clean;
// Native inventory ownership includes secondary muzzles, without treating HE as rifle ammo.
private _gl=["B_Soldier_GL_F","gl"] call IVCS_VirtualSpace_Group_createUnit;
private _rifle=(_gl get "weapons") select {(_x select 0) find "GL" != -1};
[_rifle isNotEqualTo [] && {(_rifle select 0 select 1) findIf {(_x select 0)=="1Rnd_HE_Grenade_shell"} != -1},"GL magazines are owned by their compatible carried weapon"] call _assert;
_gl set ["weapons",[["arifle_MX_GL_F",[["1Rnd_HE_Grenade_shell",1,[]]]]]];_gl set ["magazineCargo",[]];
["arifle_MX_GL_F" in ([_gl] call IVCS_Ammo_getNeededWeapons),"a loaded GL does not conceal a rifle ammunition shortage"] call _assert;
// Whole target categories and vertical range.
{
 private _b=[_x] call _target;
 [[_b] call IVCS_Combat_isVehicleTarget,format ["%1 is eligible as a vehicle target",_x]] call _assert;
 if (getNumber (configFile >> "CfgVehicles" >> _x >> "isUav")>0) then {[(_b get "entityType")=="uav","UAV identity is taken from its configuration flag"] call _assert};
 [_b] call _clean;
} forEach ["O_Heli_Light_02_unarmed_F","O_Boat_Transport_01_F","O_UAV_01_F","O_UGV_01_F"];
_a=[] call _make;private _b=["O_Heli_Light_02_unarmed_F",[14500,16400,(_combat get "helicopterInfantryRange")+1]] call _target;
[isNil {[_a,_b] call IVCS_Combat_start},"aircraft range uses vertical separation, not only map distance"] call _assert;
[_a,_b] call _clean;
// An enclosed mounted soldier dismounts before using a personal launcher.
_a=[] call _make;_u=(_a get "units") select 0;[_u,"launch_NLAW_F","NLAW_F"] call _equip;
private _ride=["B_MRAP_01_F",[14500,16400,0]] call _target;_ride set ["side","WEST"];
[_a,_ride] call IVCS_VirtualSpace_Group_assignVehicle;
_b=[] call _target;
private _eng=[_a,_b,0,42] call IVCS_Combat_start;
[!isNil "_eng","mounted infantry with suitable weaponry can initiate an attack"] call _assert;
_combat set ["accuracyScale",0];[_eng,1] call IVCS_Combat_update;
[(_u get "vehicleAssignment") isEqualTo [] && {(_eng get "shots")==1},"land-mounted infantry actually dismounts before firing its launcher"] call _assert;
[_a,_ride,_b] call _clean;
_a=[] call _make;_ride=["B_Heli_Light_01_F",[14500,16400,80]] call _target;_ride set ["side","WEST"];
[_a,_ride] call IVCS_VirtualSpace_Group_assignVehicle;_b=[] call _target;
[isNil {[_a,_b] call IVCS_Combat_start},"an enclosed airborne soldier cannot dismount in midair to attack"] call _assert;
[_a,_ride,_b] call _clean;
// FFV seats retain mounted personal-weapon fire.
_a=["B_Soldier_F"] call _make;_u=(_a get "units") select 0;
_ride=["B_Boat_Transport_01_F",[14500,16400,0]] call _target;_ride set ["side","WEST"];
private _ffv=([_ride get "class"] call IVCS_Combat_getVehicleProfile) get "personTurrets";
[count _ffv>0,"personal-weapon turret paths are precomputed for FFV vehicles"] call _assert;
if (count _ffv>0) then {
 private _seat=[];
 {if ((_x select 0)=="Turrets") then {{if (_ffv getOrDefault [str (_x select 0),false]) exitWith {_seat=_x}} forEach (_x select 1)}} forEach (_ride get "seats");
 _seat set [1,_u get "id"];_u set ["vehicleAssignment",[_ride get "id",_seat]];
 (_a get "vehiclesInCargoOf") pushBack (_ride get "id");(_ride get "entitiesInCargo") pushBack (_a get "id");
 _b=["C_Offroad_01_F"] call _target;
 _eng=[_a,_b,0,42] call IVCS_Combat_start;
 [_eng,1] call IVCS_Combat_update;
 [(_u get "vehicleAssignment") isNotEqualTo [] && {(_eng get "shots")==1},"a valid FFV rifle seat fires without an unnecessary dismount"] call _assert;
 [_b] call _clean;
};
[_a,_ride] call _clean;
// Close explosives must finish placement before expending the charge.
_a=[] call _make;_u=(_a get "units") select 0;_u set ["weapons",[]];_u set ["magazineCargo",[["DemoCharge_Remote_Mag",1,[]]]];
_b=["O_MBT_02_cannon_F",[14504,16400,0]] call _target;_b set ["damage",0.999];
_eng=[_a,_b,0,42] call IVCS_Combat_start;[_eng,8] call _run;
[(_eng get "shots")==0 && {count (_u get "magazineCargo")==1},"placement delay preserves the charge until the action completes"] call _assert;
[_eng,9] call IVCS_Combat_update;
[(_eng get "shots")==1 && {(_u get "magazineCargo") isEqualTo []} && {(_eng get "mode")=="finished"},"a completed charge consumes its own ammunition and damages the target"] call _assert;
[_a,_b] call _clean;
// Crew injuries/casualties and surviving occupants.
private _nLaw=["NLAW_F"] call IVCS_Combat_getAmmoProfile;
_a=[] call _make;_b=[] call _target;private _crew=["O_crew_F","EAST",[14700,16400,0]] call _make;
[_crew,_b] call IVCS_VirtualSpace_Group_assignVehicle;
_eng=[_a,_b,0,42] call IVCS_Combat_start;
private _occupant=(_crew get "units") select 0;_occupant set ["damage",0.99];
[_b,_nLaw,1,0.5,0] call IVCS_Combat_damageVehicle;
[(_occupant get "damage")==1 && {isNil {[_crew get "id"] call IVCS_VirtualSpace_getEntity}},"a penetrating hit can kill an occupant and remove the corpse from its group"] call _assert;
[(_eng get "mode")=="virtual" && {(_b get "combatID")!=""} && {(_b get "damage")<1},"loss of the final attached crew does not terminate an attack on a surviving vehicle"] call _assert;
[_a,_b,_crew] call _clean;
_a=[] call _make;_b=[] call _target;_crew=["O_crew_F","EAST",[14700,16400,0]] call _make;
[_crew,_b] call IVCS_VirtualSpace_Group_assignVehicle;_occupant=(_crew get "units") select 0;
_eng=[_a,_b,0,42] call IVCS_Combat_start;_b set ["damage",0.999];
[_b,_nLaw,1,0.5,0.012] call IVCS_Combat_damageVehicle;
[(_occupant get "damage")>0 && {(_occupant get "damage")<1} && {(_occupant get "hitpoints") findIf {(_x select 1)>0} != -1},"vehicle destruction can leave an injured survivor with actual hitpoint damage"] call _assert;
[(_occupant get "vehicleAssignment") isEqualTo [] && {(_crew get "combatID")==""},"surviving crew is dismounted and released from the destroyed vehicle"] call _assert;
[_crew] call IVCS_VirtualSpace_Group_spawn;
private _body=_occupant get "object";
[abs (damage _body-(_occupant get "damage"))<0.001,"crew injuries survive native spawning"] call _assert;
[_a,_b,_crew] call _clean;
// Visibility loss and ammunition exhaustion recover without immediate re-engagement.
_a=[] call _make;_b=[] call _target;_eng=[_a,_b,0,42] call IVCS_Combat_start;
private _height=_combat get "eyeHeight";_combat set ["eyeHeight",-10];
[_eng,29] call IVCS_Combat_update;[(_eng get "mode")=="virtual","visibility loss retains contact during its 30-second grace period"] call _assert;
[_eng,30] call IVCS_Combat_update;_combat set ["eyeHeight",_height];
[(_eng get "mode")=="finished" && {(_eng get "reason")=="contact"} && {(_a get "combatID")==""},"30 seconds without visibility ends the engagement and releases movement"] call _assert;
[isNil {[_a,_b,31,42] call IVCS_Combat_start},"target-specific cooldown prevents an immediate contact-loss loop"] call _assert;
[!isNil {[_a,_b,46,42] call IVCS_Combat_start},"the same target becomes eligible after the cooldown"] call _assert;
[_a,_b] call _clean;
_a=[] call _make;_b=[] call _target;_eng=[_a,_b,0,42] call IVCS_Combat_start;
_u=(_a get "units") select 0;_u set ["weapons",[]];_u set ["magazineCargo",[]];
[_eng,14] call _run;[(_eng get "mode")=="virtual","dry ammunition retains the engagement during its 15-second recovery window"] call _assert;
[_eng,15] call IVCS_Combat_update;
[(_eng get "mode")=="finished" && {(_eng get "reason")=="ammunition"},"15 seconds without usable ammunition ends the stalled fight"] call _assert;
[_a,_b] call _clean;
_a=[] call _make;_b=[] call _target;_u=(_a get "units") select 0;[_u,"launch_NLAW_F","NLAW_F",3] call _equip;
_combat set ["cadenceScale",100];_eng=[_a,_b,0,42] call IVCS_Combat_start;[_eng,20] call _run;
[(_eng get "mode")=="virtual","a long weapon cadence is not misclassified as ammunition exhaustion"] call _assert;
_combat set ["cadenceScale",1];[_a,_b] call _clean;
// A squad leaves enclosed land transport together and retains its actual dismount position.
_a=[] call _make; _u=(_a get "units") select 0;
(_a get "units") pushBack (["B_Soldier_F","u1"] call IVCS_VirtualSpace_Group_createUnit);
_ride=["B_MRAP_01_F",[14500,16400,0]] call _target; _ride set ["side","WEST"];
[_a,_ride] call IVCS_VirtualSpace_Group_assignVehicle;
_b=[] call _target; _eng=[_a,_b,0,42] call IVCS_Combat_start;
[_eng,1] call IVCS_Combat_update;
[(_a get "units") findIf {(_x get "vehicleAssignment") isNotEqualTo []} == -1 && {(_a get "vehiclesInCommandOf") isEqualTo []} && {(_a get "vehiclesInCargoOf") isEqualTo []},"all land-capable squadmates dismount together"] call _assert;
[(_a get "position") isEqualTo (_ride get "position"),"the dismounted squad retains the transport position"] call _assert;
[_a,_ride,_b] call _clean;
// Consecutive placements pay one placement delay and one reload, not two placement delays.
_a=[] call _make; _u=(_a get "units") select 0; _u set ["weapons",[]];
_u set ["magazineCargo",[["DemoCharge_Remote_Mag",1,[]],["DemoCharge_Remote_Mag",1,[]]]];
_b=["O_MBT_02_cannon_F",[14504,16400,0]] call _target;
_eng=[_a,_b,0,42] call IVCS_Combat_start; [_eng,19] call _run;
[(_eng get "shots")==1 && {count (_u get "magazineCargo")==1},"the next charge remains in inventory during its placement"] call _assert;
[_eng,20] call IVCS_Combat_update;
[(_eng get "shots")==2 && {(_u get "magazineCargo") isEqualTo []},"the second charge completes after placement plus reload"] call _assert;
[_a,_b] call _clean;
// Crew injury selection follows the same configured anatomical weights as infantry.
private _savedWeights=_combat get "bodyWeights"; _combat set ["bodyWeights",[["arms",1]]];
_b=[] call _target; _crew=["O_crew_F","EAST",[14700,16400,0]] call _make;
[_crew,_b] call IVCS_VirtualSpace_Group_assignVehicle; _occupant=(_crew get "units") select 0;
[_b,_nLaw,0.1,false,0] call IVCS_Combat_damageCrew;
private _arms=([_occupant] call IVCS_Combat_getHitpointLayout) select 2;
[_arms findIf {((_occupant get "hitpoints") select _x select 1)>0} != -1,"crew injuries honor configured body-region weights"] call _assert;
_combat set ["bodyWeights",_savedWeights]; [_b,_crew] call _clean;
// Fully damaged vital anatomy must already be lethal before native restoration.
_combat set ["bodyWeights",[["head",1]]];
_b=[] call _target; _crew=["O_crew_F","EAST",[14700,16400,0]] call _make;
[_crew,_b] call IVCS_VirtualSpace_Group_assignVehicle; _occupant=(_crew get "units") select 0;
{_x set [1,0.95]} forEach (_occupant get "hitpoints");
[_b,_nLaw,0.1,false,0] call IVCS_Combat_damageCrew;
[(_occupant get "damage")==1 && {(_crew get "units") isEqualTo []},"fully damaged crew vital hitpoints are lethal before spawning"] call _assert;
_combat set ["bodyWeights",_savedWeights]; [_b,_crew] call _clean;
// Sea-surface coordinates must not put visibility rays on the seabed.
private _sea=[];
for "_x" from 500 to 30000 step 1000 do {
 if (_sea isNotEqualTo []) exitWith {};
 private _p=[_x,500,0]; if (surfaceIsWater _p && {getTerrainHeightASL _p < -20}) then {_sea=_p};
};
[_sea isNotEqualTo [],"the sea visibility fixture finds deep water"] call _assert;
_a=["B_Soldier_F","WEST",_sea] call _make;
_b=["O_Boat_Transport_01_F",_sea vectorAdd [100,0,0]] call _target;
[[_a,_b] call IVCS_Combat_canSee,"sea-surface combat visibility is above the seabed"] call _assert;
[_a,_b] call _clean;
// Capturing a long native fight starts fresh virtual recovery windows.
_a=[] call _make; _b=[] call _target; _eng=[_a,_b,0,42] call IVCS_Combat_start;
_eng set ["lastContactAt",-100]; _eng set ["lastProgressAt",-100];
[_b] call IVCS_Combat_onDespawn;
[(_eng get "lastContactAt")==IVCS_SimulationTime && {(_eng get "lastProgressAt")==IVCS_SimulationTime},"native combat duration does not exhaust virtual recovery timers"] call _assert;
[_a,_b] call _clean;
// Native UAV objects and implicit AI groups are owned by the virtual entity.
_a=[] call _make;_u=(_a get "units") select 0;[_u,"launch_B_Titan_F","Titan_AA"] call _equip;
_b=["O_UAV_01_F",[14700,16400,30]] call _target;
_eng=[_a,_b,0,42] call IVCS_Combat_start;
[!isNil "_eng","an AA-equipped infantry group can engage a UAV"] call _assert;
private _beforeGroups=count allGroups;
for "_cycle" from 1 to 2 do {
 [_b] call IVCS_VirtualSpace_Vehicle_spawn;
 { _x disableAI "ALL" } forEach units (_a get "group");
 [(_eng get "mode")=="native" && {(_b get "nativeCrew") isNotEqualTo []},"UAV handoff creates its native AI crew and the opposing infantry"] call _assert;
 [_b] call IVCS_VirtualSpace_Vehicle_despawn;
 [(_eng get "mode")=="virtual" && {(_b get "nativeCrew") isEqualTo []},"UAV capture removes its implicit native crew"] call _assert;
};
[count allGroups<=_beforeGroups,"UAV handoff cycles do not leak implicit AI groups"] call _assert;
[_a,_b] call _clean;
_combat set ["accuracyScale",1.1];
[count (_combat get "engagements")==0 && {count (IVCS_VirtualSpace_Controller get "entities" get "ALL")==0},"all expanded-combat fixtures clean up their entities and engagements"] call _assert;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
