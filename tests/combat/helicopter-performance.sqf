// Twenty total groups: five targets, five helicopter crews and ten AA support/crew groups.
waitUntil { time > 0 };
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
IVCS_Common_WeaponInfo = createHashMap;
IVCS_Common_MagazineInfo = createHashMap;
IVCS_Common_AmmoInfo = createHashMap;
IVCS_Common_UnitInfo = createHashMap;
IVCS_Common_WeaponAliases = createHashMap;
IVCS_Common_VehicleConfigInventories=createHashMap;
IVCS_Common_VehicleTurrets=[] call IVCS_Common_getAllVehicleTurretsFromConfig;
IVCS_Paths_Generator = createHashMapFromArray [["requestQueue",[]],["currentRequest",[]],["props",["man","helicopter","antiair","armored"]],["nextRequestIDNum",0]];
{ _x disableAI "ALL"; } forEach allUnits;
west setFriend [east,0]; east setFriend [west,0];
IVCS_Perf_Enabled = false;
IVCS_Perf_Recording = false;
IVCS_Perf_Rows = [];
IVCS_Perf_LastFrame = diag_tickTime;
IVCS_Perf_Steps = 0;
IVCS_Perf_Durations = [0,0,0,0];
private _profiling = missionNamespace getVariable ["IVCS_Perf_Profiler",false];
private _scopeNames = ["IVCS_PERF_Combat_Frame","IVCS_PERF_AmmoQueue_Frame","IVCS_PERF_Entities_Frame","IVCS_PERF_Spawner_Frame"];
private _functions = ["IVCS_Combat_onFrame","IVCS_Ammo_onFrame","IVCS_VirtualSpace_simulateEntities","IVCS_FSM_execute"];
{
    private _original = missionNamespace getVariable _x;
    missionNamespace setVariable ["IVCS_Perf_Original_" + _x,_original];
    private _prefix = if (_profiling) then { format ["private _profileScope = createProfileScope %1; ",str (_scopeNames select _forEachIndex)] } else { "" };
    missionNamespace setVariable [_x,compile (_prefix + format [
        "private _start = diag_tickTime; private _result = _this call IVCS_Perf_Original_%1; IVCS_Perf_Durations set [%2,1000 * (diag_tickTime - _start)]; _result",
        _x,_forEachIndex
    ])];
} forEach _functions;
if (!isNil "IVCS_Perf_InstallOperationScopes") then { call IVCS_Perf_InstallOperationScopes; };
IVCS_Perf_OriginalStep = IVCS_Combat_step;
IVCS_Combat_step = {
    IVCS_Perf_Steps = IVCS_Perf_Steps + 1;
    _this call IVCS_Perf_OriginalStep;
};
IVCS_Perf_OriginalFrame = IVCS_VirtualSpace_onFrame;
IVCS_VirtualSpace_onFrame = {
    if (!IVCS_Perf_Enabled) exitWith {};
    private _start = diag_tickTime;
    private _interval = 1000 * (_start - IVCS_Perf_LastFrame);
    IVCS_Perf_LastFrame = _start;
    IVCS_Perf_Steps = 0;
    [] call IVCS_Perf_OriginalFrame;
    private _cost = 1000 * (diag_tickTime - _start);
    if (IVCS_Perf_Recording) then {
        IVCS_Perf_Rows pushBack ([_start - IVCS_Perf_WindowStart,diag_frameNo,_cost,_interval,IVCS_Perf_Steps] + IVCS_Perf_Durations);
    };
};
if (_profiling) then {
    IVCS_Perf_FrameBody = IVCS_VirtualSpace_onFrame;
    IVCS_VirtualSpace_onFrame = compile 'if (!IVCS_Perf_Enabled) exitWith {}; private _profileScope = createProfileScope "IVCS_PERF_VirtualSpace_Frame"; [] call IVCS_Perf_FrameBody;';
    if (missionNamespace getVariable ["IVCS_Perf_ContextMode",false]) then {
        IVCS_VirtualSpace_onFrame = {
            if (!IVCS_Perf_Enabled) exitWith {};
            IVCS_Perf_ContextEnabled = IVCS_Perf_Recording;
            IVCS_Perf_ContextRows = [];
            call { private _profileScope = createProfileScope "IVCS_PERF_VirtualSpace_Frame"; [] call IVCS_Perf_FrameBody; };
            if (IVCS_Perf_Recording) then {
                private _cost = (IVCS_Perf_Rows select (count IVCS_Perf_Rows - 1)) select 2;
                // Flush after the measured root closes. Keep every context: the coarse
                // Windows clock can undercount or report nominal 2 ms as 1.9989 ms.
                call {
                    private _flushScope = createProfileScope "IVCS_DIAG_ContextFlush";
                    profilerLog format ["IVCS CTX FRAME %1",[diag_frameNo,_cost]];
                    for "_row" from 0 to (count IVCS_Perf_ContextRows - 1) step 3 do {
                        profilerLog format ["IVCS CTX ROWS %1",[diag_frameNo,IVCS_Perf_ContextRows select [_row,3]]];
                    };
                };
            };
            IVCS_Perf_ContextEnabled = false;
        };
    };
    IVCS_Combat_step = compile 'private _profileScope = createProfileScope "IVCS_PERF_Combat_Step"; IVCS_Perf_Steps = IVCS_Perf_Steps + 1; _this call IVCS_Perf_OriginalStep;';
};
if (_profiling) then {
    {
        private _saved="IVCS_HeliPerf_ScopeOriginal_"+_x;
        missionNamespace setVariable [_saved,missionNamespace getVariable _x];
        missionNamespace setVariable [_x,compile format ["private _scope=createProfileScope %1;_this call %2",str ("IVCS_HELI_"+_x),_saved]];
    } forEach ["IVCS_Combat_stepReturnFire","IVCS_Combat_getReturnFireStations","IVCS_Combat_getReturnFireShot"];
};
IVCS_VirtualSpace_Controller = [false] call IVCS_VirtualSpace_createController;
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _budgetOverride = missionNamespace getVariable ["IVCS_Perf_BudgetMs",-1];
if (_budgetOverride >= 0) then { _combat set ["frameBudgetMs",_budgetOverride]; };
private _duration = missionNamespace getVariable ["IVCS_Perf_Seconds",20];
private _trials = missionNamespace getVariable ["IVCS_Perf_Trials",2];
private _sizes = missionNamespace getVariable ["IVCS_Perf_Sizes",[20,40,80]];
private _warmup = missionNamespace getVariable ["IVCS_Perf_Warmup",2];
private _logPhase = if (missionNamespace getVariable ["IVCS_Perf_Profiler",false]) then { compile "profilerLog _this;" } else { {} };
private _failed = 0; private _passed = 0;
private _assert = {
    params ["_ok","_label"];
    if (_ok) then { _passed = _passed + 1; } else { _failed = _failed + 1; };
    diag_log format ["[IVCS TASK TEST] %1 %2",if (_ok) then {"PASS"} else {"FAIL"},_label];
};

// Sustain the requested roster. Real damage/crew calculations run before test-only restoration.
IVCS_HeliPerf_RealRemove=IVCS_VirtualSpace_Group_RemoveUnit;
IVCS_VirtualSpace_Group_RemoveUnit={
    params ["_group","_unit"];
    if (IVCS_Perf_Enabled && {_group getOrDefault ["perfImmortal",false]}) exitWith {
        _unit set ["damage",0];{_x set [1,0]} forEach (_unit get "hitpoints");
    };
    _this call IVCS_HeliPerf_RealRemove
};
IVCS_HeliPerf_RealUnregister=IVCS_VirtualSpace_unregisterEntity;
IVCS_VirtualSpace_unregisterEntity={
    params ["_entity"];
    if (IVCS_Perf_Enabled && {_entity getOrDefault ["perfImmortal",false]}) exitWith {
        _entity set ["damage",0];{_x set [1,0]} forEach (_entity get "hitpoints");
        [_entity] call IVCS_Combat_updateVehicleMobility;
    };
    _this call IVCS_HeliPerf_RealUnregister
};
IVCS_HeliPerf_RealDamage=IVCS_Combat_damageVehicle;
IVCS_Combat_damageVehicle={
    _this call IVCS_HeliPerf_RealDamage;
    private _vehicle=_this select 0;
    if (IVCS_Perf_Enabled && {_vehicle getOrDefault ["perfImmortal",false]}) then {
        _vehicle set ["damage",0];{_x set [1,0]} forEach (_vehicle get "hitpoints");
        if ((_vehicle get "speedPerSecond")!=(_vehicle get "baseSpeedPerSecond")) then {[_vehicle] call IVCS_Combat_updateVehicleMobility};
    };
};
IVCS_HeliPerf_Shots=[0,0,0,0]; // helicopter, infantry AA support, vehicle AA support, primary ground vehicle
IVCS_HeliPerf_Return=IVCS_Combat_stepReturnFire;
IVCS_Combat_stepReturnFire={
    private _e=_this select 0;private _before=_e get "vehicleShots";
    _this call IVCS_HeliPerf_Return;
    IVCS_HeliPerf_Shots set [0,(IVCS_HeliPerf_Shots select 0)+(_e get "vehicleShots")-_before];
};
IVCS_HeliPerf_Mounted=IVCS_Combat_stepMountedVehicle;
IVCS_Combat_stepMountedVehicle={
    private _e=_this select 0;private _before=_e get "shots";
    private _result=_this call IVCS_HeliPerf_Mounted;
    private _role=(_this select 1) get "perfRole";
    private _index=switch (_role) do {case "helicopter":{0};case "aa":{2};default{3}};
    IVCS_HeliPerf_Shots set [_index,(IVCS_HeliPerf_Shots select _index)+(_e get "shots")-_before];
    _result
};
IVCS_HeliPerf_Infantry=IVCS_Combat_stepVehicle;
IVCS_Combat_stepVehicle={
    private _e=_this select 0;private _before=_e get "shots";
    private _result=_this call IVCS_HeliPerf_Infantry;
    if (_this param [3,false]) then {IVCS_HeliPerf_Shots set [1,(IVCS_HeliPerf_Shots select 1)+(_e get "shots")-_before]};
    _result
};
if (_profiling) then {
    {
        private _saved="IVCS_HeliPerf_ScopeOriginal_"+_x;
        missionNamespace setVariable [_saved,missionNamespace getVariable _x];
        missionNamespace setVariable [_x,compile format ["private _scope=createProfileScope %1;_this call %2",str ("IVCS_HELI_"+_x),_saved]];
    } forEach ["IVCS_Combat_canHelicopterFire","IVCS_Combat_update","IVCS_Combat_damageCrew","IVCS_Combat_getHelicopterPolicy","IVCS_Combat_getHelicopterAttackArea","IVCS_Combat_findTarget","IVCS_Combat_stepHelicopter","IVCS_Combat_stepVehicle","IVCS_Combat_stepMountedVehicle","IVCS_Combat_updateHelicopter","IVCS_Combat_updateAirDefense","IVCS_Combat_getHelicopterPass","IVCS_Combat_canSee","IVCS_Combat_canShootHelicopter","IVCS_Combat_joinHelicopterSupport","IVCS_Combat_getVehicleShot","IVCS_Combat_damageVehicle"];
};
private _make={
    params ["_classes","_side","_pos"];
    private _units=[];{_units pushBack ([_x,format ["u%1",_forEachIndex]] call IVCS_VirtualSpace_Group_createUnit)} forEach _classes;
    private _g=[_side,if (_side=="WEST") then {"BLU_F"} else {"OPF_F"},+_pos,_units] call IVCS_VirtualSpace_Group_createEntity;
    _g set ["perfImmortal",true];_g
};
private _prepareAmmo={
    params ["_group"];
    {
        {
            if (getNumber (configFile >> "CfgWeapons" >> (_x select 0) >> "type")==4) then {
                private _records=_x select 1;
                if (_records isNotEqualTo []) then {
                    private _template=+(_records select 0);_records resize 0;
                    for "_m" from 1 to 12 do {_records pushBack +_template};
                };
            };
        } forEach (_x get "weapons");
    } forEach (_group get "units");
};
private _modes=missionNamespace getVariable ["IVCS_HeliPerf_Modes",["heli-idle","heli-infantry","heli-infantry-aa","heli-vehicle-aa"]];
private _size=20;private _cells=5;
diag_log format ["[IVCS PERF] CONFIG %1",[_duration,_warmup,_trials,[_size],productVersion,accTime,_combat get "frameBudgetMs",_combat get "engagementsPerFrame",(_combat get "ammoSharing") get "searchBudgetMs",(_combat get "ammoSharing") get "donorsPerSlice"]];
sleep (missionNamespace getVariable ["IVCS_Perf_StartupDelay",0]);
// Swap the complete function bundle outside measured frames, including scoped originals.
private _baselines=missionNamespace getVariable ["IVCS_HeliPerf_Baselines",[]];
private _compare=_baselines isNotEqualTo [];
private _versions=_baselines apply {
    _x params ["_function","_baseline"];
    private _scoped="IVCS_HeliPerf_ScopeOriginal_"+_function;
    // Preserve identical test-only restoration and shot accounting around both versions.
    private _destination=switch (_function) do {
        case "IVCS_Combat_damageVehicle":{"IVCS_HeliPerf_RealDamage"};
        case "IVCS_Combat_stepVehicle":{"IVCS_HeliPerf_Infantry"};
        default {if (_profiling && {!isNil {missionNamespace getVariable _scoped}}) then {_scoped} else {_function}};
    };
    [_destination,_baseline,missionNamespace getVariable _destination]
};
for "_trial" from 1 to _trials do {
    private _before=_compare && {_trial in [1,4]};
    private _seedTrial=if (_compare) then {ceil (_trial/2)} else {_trial};
    if (_compare) then {{missionNamespace setVariable [_x select 0,_x select (if (_before) then {1} else {2})]} forEach _versions};
    private _phases=+_modes;if (_trial mod 2==0) then {reverse _phases};
    {
        private _mode=_x;private _fighting=_mode!="heli-idle";private _supporting=_mode find "-aa"!=-1;private _vehicleTarget=_mode=="heli-vehicle-aa";
        private _entities=[];private _actors=[];private _engagements=[];
        for "_i" from 0 to (_cells-1) do {
            private _h=["B_Heli_Attack_01_dynamicLoadout_F",[15100,16400,100]] call IVCS_VirtualSpace_Vehicle_createEntity;
            _h set ["perfRole","helicopter"];_h set ["perfImmortal",true];
            private _hc=[["B_helicrew_F","B_helicrew_F"],"WEST",[15100,16400,100]] call _make;
            [_hc,_h] call IVCS_VirtualSpace_Group_assignVehicle;
            private _wp=[[14500,16400,0],"MOVE",[["airCombatRole","ATTACK"],["airAttackCenter",[14500,16400,0]],["airAttackRadius",600],["combatMode","YELLOW"]]] call IVCS_VirtualSpace_createEntityWaypoint;
            [_hc,_wp] call IVCS_VirtualSpace_entityAddWaypoint;
            private _primary=nil;private _target=nil;
            if (_vehicleTarget) then {
                _target=["O_APC_Wheeled_02_rcws_v2_F",[14500,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity;
                _target set ["perfImmortal",true];_target set ["perfRole","target"];
                _primary=[["O_crew_F","O_crew_F","O_crew_F"],"EAST",[14500,16400,0]] call _make;
                [_primary,_target] call IVCS_VirtualSpace_Group_assignVehicle;
            } else {
                private _cfg=configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad";
                _primary=([_cfg,"EAST","OPF_F",[14500,16400,0]] call IVCS_VirtualSpace_createEntity) get "group";
                _primary set ["perfImmortal",true];
                // One organic AA rifleman keeps a sustained target from withdrawing when support is disabled.
                (_primary get "units") set [7,["O_Soldier_AA_F","organic-aa"] call IVCS_VirtualSpace_Group_createUnit];
                _target=_primary;
            };
            private _aaCfg=configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfTeam_AA";
            private _aa=([_aaCfg,"EAST","OPF_F",[14600,16400,0]] call IVCS_VirtualSpace_createEntity) get "group";
            _aa set ["perfImmortal",true];
            private _av=["O_APC_Tracked_02_AA_F",[14650,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity;
            _av set ["perfImmortal",true];_av set ["perfRole","aa"];
            private _ac=[["O_crew_F","O_crew_F","O_crew_F"],"EAST",[14650,16400,0]] call _make;
            [_ac,_av] call IVCS_VirtualSpace_Group_assignVehicle;
            [_primary] call _prepareAmmo;[_aa] call _prepareAmmo;
            _entities append [_h,_hc,_primary,_aa,_av,_ac];if (_vehicleTarget) then {_entities pushBack _target};
            _actors append [_hc,_primary,_aa,_ac];
            if (_fighting) then {
                private _e=[_target,_h,IVCS_SimulationTime,1000*_seedTrial+_i+1] call IVCS_Combat_start;
                if (isNil "_e") then {_failed=_failed+1;diag_log "[IVCS TASK TEST] FAIL primary engagement starts"} else {
                    _engagements pushBack _e;
                    if (_supporting) then {
                        {if (isNil {[_x,_h] call IVCS_Combat_start}) then {_failed=_failed+1;diag_log "[IVCS TASK TEST] FAIL AA support joins"}} forEach [_aa,_av];
                    };
                };
            };
            if (!_supporting) then {{_x set ["nextCombatScan",IVCS_SimulationTime+600]} forEach [_aa,_av,_ac]};
        };
        if (!_fighting) then {{_x set ["nextCombatScan",IVCS_SimulationTime+600]} forEach _entities};
        private _now=IVCS_SimulationTime;
        {_x set ["lastUpdate",_now];_x set ["pending",0]} forEach _engagements;
        {_x set ["timeLastUpdate",_now]} forEach _entities;
        [count _actors==20,"workload contains exactly 20 groups including crews and supporting AA"] call _assert;
        IVCS_Perf_Enabled=true;sleep _warmup;
        private _units=0;{_units=_units+count (_x get "units")} forEach _actors;
        private _progressAtStart=_engagements apply {_x get "elapsed"};
        private _shots=0;private _hits=0;{_shots=_shots+(_x get "shots");_hits=_hits+(_x get "hits")} forEach _engagements;
        IVCS_Perf_Rows=[];IVCS_Perf_WindowStart=diag_tickTime;IVCS_HeliPerf_Shots=[0,0,0,0];
        private _simStart=IVCS_SimulationTime;
        if (_compare) then {_mode=(if (_before) then {"before-"} else {"after-"})+_mode};
        IVCS_Perf_Recording=true;
        format ["IVCS PERF BEGIN trial=%1 mode=%2 groups=%3",_trial,_mode,_size] call _logPhase;
        diag_log format ["[IVCS PERF] START %1",[_trial,_mode,_size,_units,count _engagements]];
        sleep _duration;
        IVCS_Perf_Recording=false;
        format ["IVCS PERF END trial=%1 mode=%2 groups=%3",_trial,_mode,_size] call _logPhase;
        IVCS_Perf_Enabled=false;
        private _elapsed=diag_tickTime-IVCS_Perf_WindowStart;private _simElapsed=IVCS_SimulationTime-_simStart;
        private _endShots=0;private _endHits=0;{_endShots=_endShots+(_x get "shots");_endHits=_endHits+(_x get "hits")} forEach _engagements;
        private _endUnits=0;private _transfers=0;{_endUnits=_endUnits+count (_x get "units");_transfers=_transfers+(_x get "ammoTransfers")} forEach _actors;
        private _supports=0;{_supports=_supports+count (_x get "supporters")} forEach _engagements;
        private _registry=IVCS_VirtualSpace_Controller get "entities";
        [count (_registry get "active")==0,"benchmark stays entirely virtual"] call _assert;
        [count IVCS_Perf_Rows>=100,"measurement records at least 100 real frames"] call _assert;
        [_units==_endUnits,"test-only immortality retains the entire roster"] call _assert;
        [count (_combat get "engagements")==count _engagements,"all expected engagements survive the window"] call _assert;
        if (_fighting) then {
            [_endShots>_shots && {(IVCS_HeliPerf_Shots select 0)>0},"helicopters fire during the measurement window"] call _assert;
            private _progress=[];{_progress pushBack ((_x get "elapsed")-(_progressAtStart select _forEachIndex))} forEach _engagements;
            diag_log format ["[IVCS PERF] PROGRESS %1",[_trial,_mode,_size,selectMin _progress,selectMax _progress,_simElapsed,_combat get "step",_elapsed]];
            [selectMin _progress>=_simElapsed-((_combat get "step")+0.5),"frame budget keeps combat within one resolution interval plus scheduling slack"] call _assert;
        };
        if (_supporting) then {
            [_supports==10 && {(IVCS_HeliPerf_Shots select 1)>0} && {(IVCS_HeliPerf_Shots select 2)>0},"all ten AA supporters remain reserved and both support categories fire"] call _assert;
        };
        diag_log format ["[IVCS HELI PERF] WORK %1",[_trial,_mode,_size,count _engagements,_supports,IVCS_HeliPerf_Shots,count _entities,_units]];
        diag_log format ["[IVCS PERF] PHASE %1",[_trial,_mode,_size,count IVCS_Perf_Rows,_elapsed,_units,_endUnits,_endShots-_shots,_endHits-_hits,_transfers]];
        for "_row" from 0 to (count IVCS_Perf_Rows-1) step 5 do {diag_log format ["[IVCS PERF] ROWS %1",IVCS_Perf_Rows select [_row,5]]};
        {[_x get "id"] call IVCS_Combat_finish} forEach _engagements;
        {[_x] call IVCS_VirtualSpace_unregisterEntity} forEach (_actors+(_entities select {(_x get "entityType")!="group"}));
        [count (_registry get "ALL")==0,"phase cleanup removes every group and vehicle"] call _assert;
    } forEach _phases;
};
removeMissionEventHandler ["EachFrame",IVCS_VirtualSpace_Controller get "onFrameHandlerID"];
sleep (missionNamespace getVariable ["IVCS_Perf_PostDelay",0]);
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
