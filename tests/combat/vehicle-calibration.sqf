// Independent replay checks against the retained native sample table.
waitUntil {time>0};
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
IVCS_Common_WeaponInfo=createHashMap;IVCS_Common_MagazineInfo=createHashMap;IVCS_Common_AmmoInfo=createHashMap;IVCS_Common_UnitInfo=createHashMap;IVCS_Common_WeaponAliases=createHashMap;
IVCS_Common_VehicleConfigInventories=createHashMap;IVCS_Common_VehicleTurrets=[] call IVCS_Common_getAllVehicleTurretsFromConfig;
IVCS_Paths_Generator=createHashMapFromArray [["requestQueue",[]],["currentRequest",[]]];
IVCS_VirtualSpace_Controller=[false] call IVCS_VirtualSpace_createController;
removeMissionEventHandler ["EachFrame",IVCS_VirtualSpace_Controller get "onFrameHandlerID"];
private _passed=0;private _failed=0;
private _assert={params ["_ok","_label"];if (_ok) then {_passed=_passed+1} else {_failed=_failed+1};diag_log format ["[IVCS TASK TEST] %1 %2",if (_ok) then {"PASS"} else {"FAIL"},_label]};
{
 private _class=_x;
 private _profile=[_class] call IVCS_Combat_getVehicleProfile;
 private _raw=IVCS_Combat_VehicleCalibration get _class;
 {
  _x params ["_magazine","_data"];
  private _ammo=[_magazine] call IVCS_Combat_getAmmoProfile;
  private _cal=(_profile get "calibration") get _magazine;
  [!isNil "_cal",format ["%1 / %2 has a matching native calibration",_class,_magazine]] call _assert;
  {
   private _v=[_class,[14700,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity;
   private _sample=_x;private _fraction=(_forEachIndex+0.1)/count (_data select 2);
   [_v,_ammo,_cal select 0,_fraction,0.5] call IVCS_Combat_damageVehicle;
   [abs ((_v get "damage")-(_sample select 0))<0.0001,format ["%1 / %2 reproduces native overall damage sample %3",_class,_magazine,_forEachIndex]] call _assert;
   private _correct=true;
   {
    private _index=(_profile get "indices") get (_x select 0);
    if (!isNil "_index") then {if (abs ((_v get "hitpoints" select _index select 1)-(_x select 1))>0.0001) then {_correct=false}};
   } forEach (_sample select 1);
   [_correct,format ["%1 / %2 reproduces recorded component damage",_class,_magazine]] call _assert;
   [_v] call IVCS_VirtualSpace_unregisterEntity;
  } forEach (_data select 2);
 } forEach (_raw select 2);
} forEach keys IVCS_Combat_VehicleCalibration;
private _v=["B_MRAP_01_F",[14700,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity;
private _ammo=["NLAW_F"] call IVCS_Combat_getAmmoProfile;
[_v,_ammo,1,0.5] call IVCS_Combat_damageVehicle;
[(_v get "damage")>0,"uncalibrated classes retain a configuration-based damage fallback"] call _assert;
[_v] call IVCS_VirtualSpace_unregisterEntity;
_v=["C_Offroad_01_F",[14700,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity;
private _index=([_v get "class"] call IVCS_Combat_getVehicleProfile) get "indices" get "hitengine";
(_v get "hitpoints" select _index) set [1,1];[_v] call IVCS_Combat_updateVehicleMobility;
[(_v get "speedPerSecond")==0,"destroyed engines disable virtual mobility"] call _assert;
(_v get "hitpoints" select _index) set [1,0];[_v] call IVCS_Combat_updateVehicleMobility;
[(_v get "speedPerSecond")==(_v get "baseSpeedPerSecond"),"captured native engine repair restores virtual mobility"] call _assert;
[_v] call IVCS_VirtualSpace_unregisterEntity;
[count (IVCS_VirtualSpace_Controller get "entities" get "ALL")==0,"calibration fixtures leave no registered entities"] call _assert;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
