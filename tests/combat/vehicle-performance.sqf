// Twenty attacking squads, twenty armed vehicles and twenty crew groups.
// Targets/crews are kept alive only by benchmark wrappers; real damage/crew work still executes.
// Before/after share current metadata/scheduler; ReturnFireComparison isolates turret return fire.
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
IVCS_Paths_Generator = createHashMapFromArray [["requestQueue",[]],["currentRequest",[]]];
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
        private _saved="IVCS_Perf_Return_"+_x;
        missionNamespace setVariable [_saved,missionNamespace getVariable _x];
        missionNamespace setVariable [_x,compile format ["private _scope=createProfileScope %1;_this call %2",str ("IVCS_VEH_"+_x),_saved]];
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
private _hotNames=["IVCS_Combat_update","IVCS_Combat_stepVehicle","IVCS_Combat_getVehicleShot","IVCS_Combat_damageVehicle"];
private _after=createHashMapFromArray (_hotNames apply {[_x,missionNamespace getVariable _x]});
private _before=createHashMap;
{_before set [_x,compile preprocessFileLineNumbers format ["IVCS\tests\combat\vehicle-baseline\%1.sqf",["update","stepVehicle","getVehicleShot","damageVehicle"] select _forEachIndex]]} forEach _hotNames;
private _oldUnregister=IVCS_VirtualSpace_unregisterEntity;
IVCS_Perf_RealUnregister=_oldUnregister;
IVCS_VirtualSpace_unregisterEntity={
 params ["_entity"];
 if (IVCS_Perf_Enabled && {_entity getOrDefault ["IVCS_Perf_Target",false]}) exitWith {
  _entity set ["damage",0];{_x set [1,0]} forEach (_entity get "hitpoints");
 };
 _this call IVCS_Perf_RealUnregister
};
IVCS_Perf_RealRemoveUnit=IVCS_VirtualSpace_Group_RemoveUnit;
IVCS_VirtualSpace_Group_RemoveUnit={
 params ["_entity","_unit"];
 if (IVCS_Perf_Enabled && {_entity getOrDefault ["IVCS_Perf_Immortal",false]}) exitWith {
  _unit set ["damage",0];{_x set [1,0]} forEach (_unit get "hitpoints");
 };
 _this call IVCS_Perf_RealRemoveUnit
};
private _plan=[];
{_plan append [["vehicle-before",_x,true],["vehicle-after",_x,true],["vehicle-shortage-before",_x,true],["vehicle-shortage-after",_x,true]]} forEach _sizes;
diag_log format ["[IVCS PERF] ORIGINAL %1",(str IVCS_Perf_OriginalFrame) select [0,250]];
diag_log format ["[IVCS PERF] COMBAT_ORIGINAL %1",(str IVCS_Perf_Original_IVCS_Combat_onFrame) select [0,250]];
diag_log format ["[IVCS PERF] RETURN_FIRE_COMPARISON %1",missionNamespace getVariable ["IVCS_Perf_ReturnFireComparison",false]];
diag_log format ["[IVCS PERF] CONFIG %1",[_duration,_warmup,_trials,_sizes,productVersion,accTime,_combat get "frameBudgetMs",_combat get "engagementsPerFrame",(_combat get "ammoSharing") get "searchBudgetMs",(_combat get "ammoSharing") get "donorsPerSlice"]];
sleep (missionNamespace getVariable ["IVCS_Perf_StartupDelay",0]);
for "_trial" from 1 to _trials do {
    // Reverse size order on alternate trials to expose time/order effects.
    private _phases = +_plan;
    if (_trial mod 2 == 0) then { reverse _phases; };
    {
        _x params ["_mode","_size","_fighting"];
        private _pressure = _mode find "shortage" != -1;
        private _selected=if (_mode find "before" != -1) then {_before} else {_after};
        {
            private _fn=_selected get _x;
            if (_profiling) then {
                private _saved="IVCS_Perf_Selected_"+_x;missionNamespace setVariable [_saved,_fn];
                _fn=compile format ["private _scope=createProfileScope %1;_this call %2",str ("IVCS_VEH_"+_x),_saved];
            };
            missionNamespace setVariable [_x,_fn];
        } forEach _hotNames;
        private _entities = [];
        private _engagements = [];
        for "_i" from 0 to (_size - 1) do {
            private _blueConfig=configFile >> "CfgGroups" >> "West" >> "BLU_F" >> "Infantry" >> "BUS_InfSquad";
            private _blue=([_blueConfig,"WEST","BLU_F",[14500,16400,0]] call IVCS_VirtualSpace_createEntity) get "group";
            _blue set ["IVCS_Perf_Immortal",true];
            private _red=["O_APC_Wheeled_02_rcws_v2_F",[14700,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity;
            _red set ["IVCS_Perf_Target",true];
            private _crewUnits=[];
            for "_c" from 0 to 1 do {_crewUnits pushBack (["O_crew_F",format ["u_%1",_c]] call IVCS_VirtualSpace_Group_createUnit)};
            private _crew=["EAST","OPF_F",[14700,16400,0],_crewUnits] call IVCS_VirtualSpace_Group_createEntity;
            _crew set ["IVCS_Perf_Crew",true];_crew set ["IVCS_Perf_Immortal",true];[_crew,_red] call IVCS_VirtualSpace_Group_assignVehicle;
            // Sustain normal reload cadence without depleting this synthetic workload.
            {
                {if (getNumber (configFile >> "CfgWeapons" >> (_x select 0) >> "type")==4) then {
                    private _records=_x select 1;
                    if (_records isNotEqualTo []) then {private _mag=(_records select 0) select 0;_records resize 0;for "_m" from 1 to 30 do {_records pushBack [_mag,1,["armor"]]}};
                }} forEach (_x get "weapons");
            } forEach (_blue get "units");
            _entities append [_blue,_red,_crew];
            private _engagement=[_blue,_red,IVCS_SimulationTime,1000*_trial+_i+1] call IVCS_Combat_start;
            if (isNil "_engagement") then {_failed=_failed+1} else {_engagements pushBack _engagement};
        };
        private _actors=_entities select {(_x get "entityType")=="group"};
        private _attackers=_actors select {!(_x getOrDefault ["IVCS_Perf_Crew",false])};
        private _now = IVCS_SimulationTime;
        { _x set ["lastUpdate",_now]; _x set ["pending",0]; } forEach _engagements;
        { _x set ["timeLastUpdate",_now]; } forEach _entities;
        IVCS_Perf_Enabled = true;
        sleep _warmup;
        private _startUnits = 0;
        { _startUnits = _startUnits + count (_x get "units"); } forEach _actors;
        private _progressAtStart = _engagements apply { _x get "elapsed" };
        private _returnAtStart = 0; { _returnAtStart=_returnAtStart+(_x get "vehicleShots"); } forEach _engagements;
        private _shots = 0; private _hits = 0;
        { _shots = _shots + (_x get "shots"); _hits = _hits + (_x get "hits"); } forEach _engagements;
        private _forcedRecipients = [];
        if (_pressure) then {
            // Force one rifle recipient per group after warmup so donor selection
            // and delivery/reload costs are inside the measurement window.
            {
                private _roster=_x get "units";
                private _unitIndex=_roster findIf {(_x get "weapons") findIf {getNumber (configFile >> "CfgWeapons" >> (_x select 0) >> "type")==4} != -1};
                private _recipient=_roster select _unitIndex;
                private _weapons=_recipient get "weapons";
                private _index=_weapons findIf {getNumber (configFile >> "CfgWeapons" >> (_x select 0) >> "type")==4};
                private _weapon=_weapons select _index;
                private _donor=_roster select (if (_unitIndex==0) then {1} else {0});
                for "_m" from 1 to 3 do {(_donor get "magazineCargo") pushBack ["NLAW_F",1,["armor"]]};
                _forcedRecipients pushBack [_x,_recipient,_weapon select 0,_x get "ammoTransfers"];
                private _compatible = ([_weapon select 0] call IVCS_Common_getWeaponInfo) select 2;
                _weapon set [1,(_weapon select 1) select { !((_x select 0) in _compatible) }];
                _recipient set ["magazineCargo",(_recipient get "magazineCargo") select { !((_x select 0) in _compatible) }];
                _recipient set ["ammoRetryAt",0];
                _x set ["ammoNextScan",0];
            } forEach _attackers;
        };
        IVCS_Perf_Rows = [];
        IVCS_Perf_WindowStart = diag_tickTime;
        private _simulationAtStart = IVCS_SimulationTime;
        IVCS_Perf_Recording = true;
        format ["IVCS PERF BEGIN trial=%1 mode=%2 groups=%3",_trial,_mode,_size] call _logPhase;
        diag_log format ["[IVCS PERF] START %1",[_trial,_mode,_size,_startUnits,count _engagements]];
        sleep _duration;
        IVCS_Perf_Recording = false;
        format ["IVCS PERF END trial=%1 mode=%2 groups=%3",_trial,_mode,_size] call _logPhase;
        IVCS_Perf_Enabled = false;
        private _elapsed = diag_tickTime - IVCS_Perf_WindowStart;
        private _simulationElapsed = IVCS_SimulationTime - _simulationAtStart;
        diag_log format ["[IVCS PERF] STATE %1",[IVCS_SimulationPaused,time,IVCS_SimulationTime,IVCS_SimulationTime_LastTick,(_actors apply { _x get "timeLastUpdate" }) select [0,2]]];
        private _endUnits = 0; private _endShots = 0; private _endHits = 0; private _transfers = 0;
        { _endUnits = _endUnits + count (_x get "units"); _transfers = _transfers + (_x get "ammoTransfers"); } forEach _actors;
        { _endShots = _endShots + (_x get "shots"); _endHits = _endHits + (_x get "hits"); } forEach _engagements;
        private _registry = IVCS_VirtualSpace_Controller get "entities";
        [count (_registry get "active") == 0,"benchmark stays entirely virtual"] call _assert;
        [count IVCS_Perf_Rows >= 100,"measurement records at least 100 real frames"] call _assert;
        private _returnShots=0;{_returnShots=_returnShots+(_x get "vehicleShots")} forEach _engagements;_returnShots=_returnShots-_returnAtStart;
        diag_log format ["[IVCS PERF] RETURN_FIRE %1",[_trial,_mode,_size,_returnShots]];
        [if (_mode find "after"!=-1) then {_returnShots>0} else {_returnShots==0},"expanded land vehicles return fire while the frozen baseline remains passive"] call _assert;
        [!_fighting || { count (_combat get "engagements") == _size && { _endShots > _shots } },"combat load remains active and fires"] call _assert;
        if (_fighting) then {
            private _progress = [];
            {
                _progress pushBack ((_x get "elapsed") - (_progressAtStart select _forEachIndex));
            } forEach _engagements;
            diag_log format ["[IVCS PERF] PROGRESS %1",[_trial,_mode,_size,selectMin _progress,selectMax _progress,_simulationElapsed,_combat get "step",_elapsed]];
            [selectMin _progress >= _simulationElapsed - ((_combat get "step") + 0.5),"frame budget keeps combat within one resolution interval plus scheduling slack"] call _assert;
        };
        if (_pressure) then {
            private _searches = { (_x get "ammoSearch") isNotEqualTo [] } count _attackers;
            private _requests = 0;
            { _requests = _requests + count (_x get "ammoRequests"); } forEach _attackers;
            // A delivered rocket can be fired again before the window ends.
            // Judge delivery, not whether the recipient happens to be loaded now.
            private _unresolved={
                _x params ["_entity","_recipient","_weapon","_beforeTransfers"];
                (_entity get "ammoTransfers") <= _beforeTransfers
            } count _forcedRecipients;
            diag_log format ["[IVCS PERF] SHARING_WORK %1",[_trial,_mode,_size,_searches,_requests,_transfers,_unresolved]];
            [_unresolved <= floor (0.1 * _size) && { _transfers >= floor (0.9 * _size) },"at least 90 percent of forced transfers complete within the window"] call _assert;
        };
        diag_log format ["[IVCS PERF] PHASE %1",[_trial,_mode,_size,count IVCS_Perf_Rows,_elapsed,_startUnits,_endUnits,_endShots - _shots,_endHits - _hits,_transfers]];
        for "_row" from 0 to (count IVCS_Perf_Rows - 1) step 5 do {
            diag_log format ["[IVCS PERF] ROWS %1",IVCS_Perf_Rows select [_row,5]];
        };
        { [_x] call IVCS_VirtualSpace_unregisterEntity; } forEach _entities;
        [count (_registry get "ALL") == 0,"phase cleanup removes all virtual groups"] call _assert;
        IVCS_Perf_Rows = [];
    } forEach _phases;
};
removeMissionEventHandler ["EachFrame",IVCS_VirtualSpace_Controller get "onFrameHandlerID"];
// Optional delay lets a timed profiler recorder finish saving before server exit.
sleep (missionNamespace getVariable ["IVCS_Perf_PostDelay",0]);
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
