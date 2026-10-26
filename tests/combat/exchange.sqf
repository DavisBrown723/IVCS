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


IVCS_Exchange_Probes=0;
IVCS_Exchange_RealCanFire=IVCS_Combat_canHelicopterFire;
IVCS_Combat_canHelicopterFire={IVCS_Exchange_Probes=IVCS_Exchange_Probes+1;_this call IVCS_Exchange_RealCanFire};
private _cases=[
    [1,1,"ATTACK","YELLOW","AWARE","normal"],
    [8,1,"ATTACK","YELLOW","AWARE","normal"],
    [9,1,"ATTACK","YELLOW","AWARE","normal"],
    [10,1,"ATTACK","YELLOW","AWARE","normal"],
    [32,2,"ATTACK","YELLOW","AWARE","normal"],
    [33,1,"ATTACK","YELLOW","AWARE","normal"],
    [34,2,"ATTACK","YELLOW","AWARE","normal"],
    [70,40,"ATTACK","YELLOW","AWARE","normal"],
    [9,1,"TRANSPORT","YELLOW","AWARE","normal"],
    [9,1,"TRANSPORT","YELLOW","AWARE","threat"],
    [9,1,"ATTACK","BLUE","AWARE","normal"],
    [9,1,"ATTACK","RED","CARELESS","normal"],
    [9,1,"ATTACK","YELLOW","AWARE","outside"],
    [1,1,"ATTACK","YELLOW","AWARE","empty"],
    [10,1,"ATTACK","YELLOW","AWARE","empty"],
    [1,1,"ATTACK","YELLOW","AWARE","reload"],
    [10,1,"ATTACK","YELLOW","AWARE","reload"],
    [1,1,"ATTACK","YELLOW","AWARE","gunner"],
    [10,1,"ATTACK","YELLOW","AWARE","gunner"],
    [1,1,"ATTACK","YELLOW","AWARE","aa"],
    [10,1,"ATTACK","YELLOW","AWARE","aa"],
    [8.5,1,"ATTACK","YELLOW","AWARE","normal"],
    [33.5,1,"ATTACK","YELLOW","AWARE","normal"]
];
{
    private _case=_x;private _snapshots=[];private _probes=[];
    {
        private _before=_x;
        private _pair=[] call _heli;_pair params ["_h","_crew"];
        private _wp=[_crew] call _order;
        private _a=["O_Soldier_F","EAST",4] call _make;
        private _e=[_a,_h,IVCS_SimulationTime,12345] call IVCS_Combat_start;
        [!isNil "_e","differential fixture admits helicopter combat"] call _assert;
        _case params ["_phase","_dt","_role","_mode","_behavior","_variant"];
        _wp set ["airCombatRole",_role];_wp set ["combatMode",_mode];_wp set ["behavior",_behavior];
        if (_variant=="outside") then {_wp set ["airAttackCenter",[10000,10000,0]];_wp set ["airAttackRadius",100]};
        if (_variant=="threat") then {_h set ["airThreat",[_a get "position",IVCS_SimulationTime+60,_a get "id"]]};
        if (_variant=="empty") then {{(_x select 2) resize 0;{_x set [2,0]} forEach (_x select 3)} forEach (_h get "turrets")};
        if (_variant=="reload") then {{(_h get "turretFireDelays") set [str (_x select 0),100]} forEach (_h get "turrets")};
        if (_variant=="gunner") then {{_x set ["damage",1]} forEach (_crew get "units")};
        if (_variant=="aa") then {(_a get "units") set [0,["O_Soldier_AA_F","aa"] call IVCS_VirtualSpace_Group_createUnit]};
        _e set ["startedAt",IVCS_SimulationTime-_phase];_e set ["stepTime",IVCS_SimulationTime];
        private _actors=(_a get "units")+(_crew get "units");
        IVCS_Exchange_Probes=0;
        if (_before) then {[_e,[_a,_h],_dt] call IVCS_Exchange_Before} else {[_e,[_a,_h],_dt] call IVCS_Combat_stepVehicle};
        _probes pushBack IVCS_Exchange_Probes;
        private _keys=keys (_h get "turretFireDelays");_keys sort true;
        _snapshots pushBack str [
            ["seed","shots","hits","vehicleShots","vehicleHits","casualties","elapsed","mode"] apply {_e get _x},
            _h get "damage",_h get "hitpoints",[_h] call _ledger,_keys apply {[_x,(_h get "turretFireDelays") get _x]},
            _actors apply {[_x get "class",_x get "damage",_x get "hitpoints",_x get "fireDelay",_x get "weapons"]},
            count (_a get "units"),(_a get "airDefense") isEqualTo []
        ];
        [_a,_crew,_h] call _clean;
    } forEach [true,false];
    [(_snapshots select 0)==(_snapshots select 1),format ["seeded full state matches baseline %1",_case]] call _assert;
    [_probes select 1 <= _probes select 0,"firing eligibility is never checked more often"] call _assert;
    if ((_case select 0)==10 && {(_case select 2)=="ATTACK"} && {(_case select 5) in ["normal","empty","reload","gunner","aa"]}) then {
        [_probes isEqualTo [1,0],"reposition-only tick skips preflight even with live ammo, injury or reload changes"] call _assert;
    };
} forEach _cases;
IVCS_Combat_canHelicopterFire=IVCS_Exchange_RealCanFire;
[count (_combat get "engagements")==0,"differential fixtures clean all engagements"] call _assert;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
