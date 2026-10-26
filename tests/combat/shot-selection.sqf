waitUntil {time>0};
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
IVCS_Common_WeaponInfo=createHashMap;IVCS_Common_MagazineInfo=createHashMap;IVCS_Common_AmmoInfo=createHashMap;IVCS_Common_UnitInfo=createHashMap;IVCS_Common_WeaponAliases=createHashMap;
IVCS_Common_VehicleConfigInventories=createHashMap;IVCS_Common_VehicleTurrets=[] call IVCS_Common_getAllVehicleTurretsFromConfig;
IVCS_VirtualSpace_Controller=[false] call IVCS_VirtualSpace_createController;
removeMissionEventHandler ["EachFrame",IVCS_VirtualSpace_Controller get "onFrameHandlerID"];
private _passed=0;private _failed=0;
private _assert={params ["_ok","_label"];if (_ok) then {_passed=_passed+1} else {_failed=_failed+1};diag_log format ["[IVCS TASK TEST] %1 %2",if (_ok) then {"PASS"} else {"FAIL"},_label]};
private _targets=["B_Heli_Attack_01_dynamicLoadout_F","B_Heli_Light_01_F","O_MRAP_02_F","O_MBT_02_cannon_F"];
private _combat=IVCS_VirtualSpace_Controller get "combat";
{
    private _u=[_x,"differential"] call IVCS_VirtualSpace_Group_createUnit;
    private _class=_x;
    {
        private _profile=[_x] call IVCS_Combat_getVehicleProfile;
        private _target=_x;
        {
            private _range=_x;
            {
                private _before=[_u,createHashMap,_profile,_range,_x] call IVCS_Review_BeforeVehicleShot;
                private _after=[_u,createHashMap,_profile,_range,_x] call IVCS_Combat_getVehicleShot;
                [_before isEqualTo _after,format ["selection parity %1 vs %2 at %3m AA=%4",_class,_target,_range,_x]] call _assert;
            } forEach [false,true];
        } forEach [0,5,20,49,50,299,300,301,750,751];
    } forEach _targets;
} forEach ["O_Soldier_F","O_Soldier_GL_F","O_Soldier_LAT_F","O_Soldier_AT_F","O_Soldier_AA_F","O_Soldier_A_F","O_Soldier_AR_F","B_Soldier_AA_F","B_Soldier_AT_F","B_Soldier_LAT_F"];
private _u=["O_Soldier_AA_F","mutation"] call IVCS_VirtualSpace_Group_createUnit;
private _air=["B_Heli_Light_01_F"] call IVCS_Combat_getVehicleProfile;
private _launcher=(_u get "weapons") select {getNumber (configFile >> "CfgWeapons" >> (_x select 0) >> "type")==4};
_u set ["weapons",_launcher];
private _cache=createHashMap;
[([_u,_cache,_air,600] call IVCS_Combat_getVehicleShot) isNotEqualTo [],"loaded launcher is selected"] call _assert;
{_x set [1,0]} forEach ((_launcher select 0) select 1);
[([_u,_cache,_air,600] call IVCS_Combat_getVehicleShot) isEqualTo [],"cached eligibility never supplies exhausted rounds"] call _assert;
((_launcher select 0) select 1) pushBack ["Titan_AA",1,["backpack"]];
[([_u,_cache,_air,600] call IVCS_Combat_getVehicleShot) isNotEqualTo [],"resupply is visible immediately through an existing cache"] call _assert;
(_launcher select 0) set [1,[["Titan_AT",1,["backpack"]]]];
[([_u,createHashMap,_air,600] call IVCS_Combat_getVehicleShot) isEqualTo [],"AA-capable class cannot fire incompatible owned ammunition"] call _assert;
_u set ["weapons",[["arifle_Katiba_F",[["30Rnd_65x39_caseless_green",30,["vest"]]]]]];
_combat set ["range",600];
[([_u,createHashMap,_air,600] call IVCS_Combat_getVehicleShot) isNotEqualTo [],"changed rifle range includes its exact boundary"] call _assert;
_combat set ["range",599];
[([_u,createHashMap,_air,600] call IVCS_Combat_getVehicleShot) isEqualTo [],"changed rifle range excludes weapons immediately"] call _assert;
_combat set ["range",300];
// Count actual record visits without Tracy instrumentation or wall-clock assumptions.
private _source=preprocessFileLineNumbers "IVCS\VirtualSpace\functions\combat\getVehicleShot.sqf";
private _needle="private _index = _records findIf {";
private _offset=_source find _needle;
if (_offset<0) then {throw "Record-visit diagnostic anchor changed"};
private _counted=compile ((_source select [0,_offset])+_needle+' IVCS_Review_RecordVisits=IVCS_Review_RecordVisits+1;'+(_source select [_offset+count _needle]));
{
    private _unit=[_x,"scan-count"] call IVCS_VirtualSpace_Group_createUnit;
    IVCS_Review_RecordVisits=0;
    private _actual=[_unit,createHashMap,_air,600] call _counted;
    private _expected=[_unit,createHashMap,_air,600] call IVCS_Review_BeforeVehicleShot;
    [_actual isEqualTo _expected && {IVCS_Review_RecordVisits==0},format ["%1 rejects unreachable/unsuitable weapons before visiting any magazines",_x]] call _assert;
} forEach ["O_Soldier_F","O_Soldier_GL_F","O_Soldier_LAT_F","O_Soldier_A_F","O_Soldier_AR_F"];
private _unit=["O_Soldier_AA_F","scan-count-AA"] call IVCS_VirtualSpace_Group_createUnit;
IVCS_Review_RecordVisits=0;
[([_unit,createHashMap,_air,600] call _counted) isNotEqualTo [] && {IVCS_Review_RecordVisits==1},"usable AA still selects its exact first live magazine"] call _assert;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
