// Run with tests/tasks/run.ps1 -TestScript tests/tasks/activation.sqf -Port 2495.
waitUntil { time > 0 };
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
IVCS_Tasks_TestPassed = 0;
IVCS_Tasks_TestFailed = 0;
private _assert = {
    params ["_ok", "_label"];
    if (_ok) then { IVCS_Tasks_TestPassed = IVCS_Tasks_TestPassed + 1; } else { IVCS_Tasks_TestFailed = IVCS_Tasks_TestFailed + 1; };
    diag_log format ["[IVCS TASK TEST] %1 %2", if (_ok) then { "PASS" } else { "FAIL" }, _label];
};
IVCS_Common_WeaponInfo = createHashMap;
IVCS_Common_MagazineInfo = createHashMap;
IVCS_Common_AmmoInfo = createHashMap;
IVCS_Common_UnitInfo = createHashMap;
IVCS_Common_WeaponAliases = createHashMap;
IVCS_Common_VehicleConfigInventories = createHashMap;
IVCS_Common_VehicleTurrets = createHashMap;
IVCS_Paths_Generator = [] call IVCS_Paths_createGenerator;
IVCS_VirtualSpace_Controller = createHashMapFromArray [
    ["combat", [] call IVCS_Combat_createController], ["debug", false], ["nextEntityID", 0], ["nextWaypointId", 100],
    ["entities", createHashMapFromArray [["ALL", createHashMap], ["active", []], ["inactive", []]]],
    ["entitiesSpacialGrid", [[0,0], worldSize, 1000] call IVCS_SpacialGrid_create]
];
private _create = {
    ([["C_man_1"], "WEST", "BLU_F", [14500, 16200, 0]] call IVCS_VirtualSpace_createEntity) get "group"
};
private _clean = {
    params ["_entity"];
    if (_entity get "active") then { [_entity] call IVCS_VirtualSpace_Group_despawn; };
    [_entity] call IVCS_VirtualSpace_unregisterEntity;
};
private _nativeNames = { (waypoints (_this get "group")) apply { waypointName _x } };
[
    "HOLD_TEST", [["hold", [
        ["onEnter", {
            _this set ["enters", (_this get "enters") + 1];
            _this set ["startedAt", IVCS_SimulationTime];
            [_this, _this get "destination"] call IVCS_EntityTasks_addWaypoint;
        }],
        ["onUpdate", { _this set ["updates", (_this get "updates") + 1]; "" }],
        ["onLeaving", { _this set ["leaves", (_this get "leaves") + 1]; }]
    ]]], "hold", [["enters",0], ["updates",0], ["leaves",0]], {},
    { _this set ["activations", (_this getOrDefault ["activations",0]) + 1]; },
    { _this set ["deactivations", (_this getOrDefault ["deactivations",0]) + 1]; }
] call IVCS_EntityTasks_createTaskTemplate;

// Exercise detach/restore in both simulations and across spawn/despawn while suspended.
{
    _x params ["_native", "_transition"];
    private _label = format ["native=%1 transition=%2", _native, _transition];
    private _entity = call _create;
    if (_native) then { [_entity] call IVCS_VirtualSpace_Group_spawn; };
    private _a = ["HOLD_TEST", [["destination",[14800,16200,0]]]] call IVCS_EntityTasks_createTaskInstance;
    private _aID = [_entity,_a] call IVCS_VirtualSpace_entityAddTask;
    [_entity,_a] call IVCS_EntityTasks_processTask;
    private _wp = (_a get "waypoints") select 0;
    private _generation = _wp get "pathGeneration";
    private _nativeGeneration = _wp get "nativeGeneration";
    private _request = ["man","SAFE",_entity get "position",_wp get "position",[],{}] call IVCS_Paths_createPathRequest;
    _wp set ["pathGenerationRequestID",_request];
    _wp set ["movePoints",[[14520,16200,0]]];
    private _b = ["MOVE", [["destination",[14500,16230,0]]]] call IVCS_EntityTasks_createTaskInstance;
    private _bID = [_entity,_b,false] call IVCS_VirtualSpace_entityAddTask;
    [(_entity get "waypoints") isEqualTo [] && { isNil { _wp get "entity" } }, _label+" immediately detaches A"] call _assert;
    [(_a get "waypoints") isEqualTo [_wp] && { (_wp get "movePoints") isEqualTo [] }, _label+" preserves order and resets path"] call _assert;
    [(IVCS_Paths_Generator get "requestQueue") findIf { (_x select 0) == _request } == -1, _label+" cancels old path request"] call _assert;
    [_entity,_a] call IVCS_EntityTasks_processTask;
    [(_a get "context" get "updates") == 1, _label+" cannot process suspended A"] call _assert;
    [_entity,_b] call IVCS_EntityTasks_processTask;
    private _bwp = (_b get "waypoints") select 0;
    [(_entity get "waypoints") isEqualTo [_bwp], _label+" only B owns attached movement"] call _assert;
    if (_entity get "active") then { [(_entity call _nativeNames) isEqualTo [_bwp get "name"], _label+" only B has native waypoints"] call _assert; };
    if (_transition) then {
        if (_entity get "active") then { [_entity] call IVCS_VirtualSpace_Group_despawn; } else { [_entity] call IVCS_VirtualSpace_Group_spawn; };
        [(_entity get "waypoints") isEqualTo [_bwp] && { isNil { _wp get "entity" } }, _label+" transition keeps A suspended"] call _assert;
    };
    // Pending cancellation must not remove B's movement.
    private _pending = ["MOVE",[["destination",[14900,16200,0]]]] call IVCS_EntityTasks_createTaskInstance;
    private _pendingID = [_entity,_pending] call IVCS_VirtualSpace_entityAddTask;
    [_entity,_pendingID] call IVCS_EntityTasks_cancelTask;
    [(_entity get "waypoints") isEqualTo [_bwp], _label+" pending cancellation preserves B"] call _assert;
    private _clock = _a get "context" get "startedAt";
    sleep 0.2;
    [_entity get "id",_bwp get "name"] call IVCS_VirtualSpace_onWaypointCompleted;
    [(_b get "waypoints") isEqualTo [], _label+" consumes completed B waypoint"] call _assert;
    [_entity,_b] call IVCS_EntityTasks_processTask;
    [_entity,_b] call IVCS_EntityTasks_processTask;
    [(_b get "status") == "completed" && { (_entity get "waypoints") isEqualTo [_wp] }, _label+" completion restores A"] call _assert;
    [(_a get "context" get "startedAt") >= _clock+0.15, _label+" excludes interruption from timeout"] call _assert;
    [(_a get "context" get "enters") == 1 && { (_a get "context" get "leaves") == 0 }, _label+" resume preserves state entry"] call _assert;
    [_entity get "id",_wp get "name",_nativeGeneration] call IVCS_VirtualSpace_onWaypointCompleted;
    [!(_a get "context" get "waypointComplete") && { (_entity get "waypoints") isEqualTo [_wp] }, _label+" ignores stale native completion after reattachment"] call _assert;
    if (_entity get "active") then {
        [(_entity call _nativeNames) isEqualTo [_wp get "name"], _label+" restores only A native waypoint"] call _assert;
        [_entity] call IVCS_VirtualSpace_Group_despawn;
    };
    [_entity get "id",_wp get "name",_generation,[[1,1,0]]] call IVCS_VirtualSpace_Group_onWaypointPathGenerated;
    [(_wp get "movePoints") isEqualTo [], _label+" ignores stale path after reattachment"] call _assert;
    [_entity,_aID] call IVCS_EntityTasks_cancelTask;
    [(_entity get "waypoints") isEqualTo [] && { (_a get "waypoints") isEqualTo [] }, _label+" cancellation discards saved orders"] call _assert;
    [_entity] call _clean;
} forEach [[false,false],[true,false],[false,true],[true,true]];

// Adding to a sequence that already reached its end state creates fresh work.
private _entity = call _create;
private _oldWP = [[14800,16200,0]] call IVCS_VirtualSpace_createEntityWaypoint;
[_entity,_oldWP] call IVCS_VirtualSpace_entityAddWaypoint;
private _oldSequence = [_entity] call IVCS_VirtualSpace_getCurrentEntityTask;
[_entity get "id",_oldWP get "name"] call IVCS_VirtualSpace_onWaypointCompleted;
[_entity,_oldSequence] call IVCS_EntityTasks_processTask;
private _newWP = [[14800,16300,0]] call IVCS_VirtualSpace_createEntityWaypoint;
[_entity,_newWP] call IVCS_VirtualSpace_entityAddWaypoint;
[_entity,_oldSequence] call IVCS_EntityTasks_processTask;
[(_oldSequence get "status") == "completed" && { (_entity get "waypoints") isEqualTo [_newWP] }, "new standalone order survives previous sequence termination"] call _assert;
[_entity] call _clean;

// A priority order may finish at A's destination; no empty path should fail A.
private _entity = call _create;
private _a = ["MOVE",[["destination",[14500,16300,0]]]] call IVCS_EntityTasks_createTaskInstance;
[_entity,_a] call IVCS_VirtualSpace_entityAddTask;
[_entity,_a] call IVCS_EntityTasks_processTask;
private _b = ["MOVE",[["destination",[14500,16300,0]]]] call IVCS_EntityTasks_createTaskInstance;
[_entity,_b,false] call IVCS_VirtualSpace_entityAddTask;
[_entity,_b] call IVCS_EntityTasks_processTask;
[_entity,[14500,16300,0]] call IVCS_VirtualSpace_setEntityPosition;
private _wp = (_b get "waypoints") select 0;
[_entity get "id",_wp get "name"] call IVCS_VirtualSpace_onWaypointCompleted;
[_entity,_b] call IVCS_EntityTasks_processTask;
[_entity,_b] call IVCS_EntityTasks_processTask;
[(_a get "context" get "waypointComplete") && { (_entity get "waypoints") isEqualTo [] }, "resume at destination completes order without a new path"] call _assert;
[_entity,_a] call IVCS_EntityTasks_processTask;
[_entity,_a] call IVCS_EntityTasks_processTask;
[(_a get "status") == "completed", "resume at destination completes MOVE successfully"] call _assert;
[_entity] call _clean;

// Cancelling suspended work and replacing active work must not restore discarded orders.
private _entity = call _create;
private _a = ["MOVE",[["destination",[14800,16200,0]]]] call IVCS_EntityTasks_createTaskInstance;
private _aID = [_entity,_a] call IVCS_VirtualSpace_entityAddTask;
[_entity,_a] call IVCS_EntityTasks_processTask;
private _b = ["MOVE",[["destination",[14500,16300,0]]]] call IVCS_EntityTasks_createTaskInstance;
private _bID = [_entity,_b,false] call IVCS_VirtualSpace_entityAddTask;
[_entity,_b] call IVCS_EntityTasks_processTask;
private _bwp = (_b get "waypoints") select 0;
[_entity,_aID] call IVCS_EntityTasks_cancelTask;
[(_a get "waypoints") isEqualTo [] && { (_entity get "waypoints") isEqualTo [_bwp] }, "suspended cancellation preserves current movement"] call _assert;
private _replacement = ["MOVE",[["destination",[14400,16200,0]]]] call IVCS_EntityTasks_createTaskInstance;
private _newID = [_entity,_bID,_replacement] call IVCS_EntityTasks_replaceTask;
[(_entity get "waypoints") isEqualTo [] && { (_b get "waypoints") isEqualTo [] } && { (_entity get "activeTask") isEqualRef _replacement }, "replacement detaches old movement immediately"] call _assert;
[_entity,_replacement] call IVCS_EntityTasks_processTask;
[(_entity get "waypoints") isEqualTo (_replacement get "waypoints"), "replacement creates only its own movement"] call _assert;
[_entity,_newID] call IVCS_EntityTasks_cancelTask;
[(_entity get "tasks") isEqualTo [] && { (_entity get "waypoints") isEqualTo [] }, "discarded suspended task never resumes"] call _assert;
[_entity] call _clean;

// Standalone cycles become tasks and resume at the same leg, including native selection.
{
    private _native = _x;
    private _entity = call _create;
    if (_native) then { [_entity] call IVCS_VirtualSpace_Group_spawn; };
    private _wps = [];
    {
        private _wp = [_x] call IVCS_VirtualSpace_createEntityWaypoint;
        [_entity,_wp] call IVCS_VirtualSpace_entityAddWaypoint;
        _wps pushBack _wp;
    } forEach [[14800,16200,0],[14800,16300,0]];
    private _cycle = [[14800,16200,0],"CYCLE"] call IVCS_VirtualSpace_createEntityWaypoint;
    [_entity,_cycle] call IVCS_VirtualSpace_entityAddWaypoint;
    _wps pushBack _cycle;
    private _patrol = [_entity] call IVCS_VirtualSpace_getCurrentEntityTask;
    [(_patrol get "name") == "WAYPOINTS" && { (_patrol get "waypoints") isEqualTo _wps }, "standalone cycle has task ownership"] call _assert;
    _entity set ["currentWaypointIndex",1];
    private _priority = ["MOVE",[["destination",[14500,16300,0]]]] call IVCS_EntityTasks_createTaskInstance;
    private _id = [_entity,_priority,false] call IVCS_VirtualSpace_entityAddTask;
    [_entity,_priority] call IVCS_EntityTasks_processTask;
    [count (_entity get "waypoints") == 1 && { (_patrol get "waypoints") isEqualTo _wps }, "priority movement is not blocked by patrol cycle"] call _assert;
    [_entity,_id] call IVCS_EntityTasks_cancelTask;
    [(_entity get "waypoints") isEqualTo _wps && { (_entity get "currentWaypointIndex") == 1 } && { (_entity get "maxWaypointIndex") == 1 }, "patrol resumes its current cycle leg"] call _assert;
    if (_native) then {
        [waypointName [_entity get "group",currentWaypoint (_entity get "group")] == ((_wps select 1) get "name"), "native cycle resumes same leg"] call _assert;
    };
    [_entity] call _clean;
} forEach [false,true];

// A state may prepend work during onEnter without updating or re-entering itself.
[
    "SELF_INTERRUPT", [["start", [
        ["onEnter", {
            _this set ["enters",(_this get "enters")+1];
            private _entity = [_this get "entityID"] call IVCS_VirtualSpace_getEntity;
            private _priority = ["MOVE",[["destination",_entity get "position"]]] call IVCS_EntityTasks_createTaskInstance;
            [_entity,_priority,false] call IVCS_VirtualSpace_entityAddTask;
            [_this,[14800,16200,0]] call IVCS_EntityTasks_addWaypoint;
        }],
        ["onUpdate", { _this set ["updates",(_this get "updates")+1]; "" }]
    ]]], "start", [["enters",0],["updates",0]]
] call IVCS_EntityTasks_createTaskTemplate;
private _entity = call _create;
private _self = ["SELF_INTERRUPT"] call IVCS_EntityTasks_createTaskInstance;
[_entity,_self] call IVCS_VirtualSpace_entityAddTask;
[_entity,_self] call IVCS_EntityTasks_processTask;
[(_self get "context" get "updates") == 0 && { (_entity get "waypoints") isEqualTo [] }, "onEnter interruption skips update and holds new orders detached"] call _assert;
private _priority = [_entity] call IVCS_VirtualSpace_getCurrentEntityTask;
[_entity,_priority] call IVCS_EntityTasks_processTask;
[_entity,_priority] call IVCS_EntityTasks_processTask;
[_entity,_self] call IVCS_EntityTasks_processTask;
[(_self get "context" get "enters") == 1 && { (_self get "context" get "updates") == 1 } && { count (_entity get "waypoints") == 1 }, "self-interrupted task resumes without duplicate entry"] call _assert;
[_entity] call _clean;

// Completion can prepend priority work; the consumed order must never replay.
private _entity = call _create;
private _first = [[14800,16200,0]] call IVCS_VirtualSpace_createEntityWaypoint;
private _second = [[14800,16300,0]] call IVCS_VirtualSpace_createEntityWaypoint;
[_entity,_first] call IVCS_VirtualSpace_entityAddWaypoint;
[_entity,_second] call IVCS_VirtualSpace_entityAddWaypoint;
private _sequence = [_entity] call IVCS_VirtualSpace_getCurrentEntityTask;
[_first,[],{
    params ["_entity"];
    private _priority = ["MOVE",[["destination",[14500,16400,0]]]] call IVCS_EntityTasks_createTaskInstance;
    [_entity,_priority,false] call IVCS_VirtualSpace_entityAddTask;
}] call IVCS_VirtualSpace_addWaypointCallback;
[_entity get "id",_first get "name"] call IVCS_VirtualSpace_onWaypointCompleted;
[(_sequence get "waypoints") isEqualTo [_second], "completion-triggered interruption forgets completed order"] call _assert;
private _priority = [_entity] call IVCS_VirtualSpace_getCurrentEntityTask;
[_entity,_priority get "id"] call IVCS_EntityTasks_cancelTask;
[(_entity get "waypoints") isEqualTo [_second], "completion-triggered interruption resumes next order"] call _assert;
[_entity] call _clean;

// A cycle completion that interrupts itself must save the next leg.
private _entity = call _create;
private _first = [[14800,16200,0]] call IVCS_VirtualSpace_createEntityWaypoint;
private _second = [[14800,16300,0]] call IVCS_VirtualSpace_createEntityWaypoint;
private _cycle = [[14800,16200,0],"CYCLE"] call IVCS_VirtualSpace_createEntityWaypoint;
{ [_entity,_x] call IVCS_VirtualSpace_entityAddWaypoint; } forEach [_first,_second,_cycle];
[_first,[],{
    params ["_entity"];
    private _priority = ["MOVE",[["destination",[14500,16400,0]]]] call IVCS_EntityTasks_createTaskInstance;
    [_entity,_priority,false] call IVCS_VirtualSpace_entityAddTask;
}] call IVCS_VirtualSpace_addWaypointCallback;
[_entity get "id",_first get "name"] call IVCS_VirtualSpace_onWaypointCompleted;
private _priority = [_entity] call IVCS_VirtualSpace_getCurrentEntityTask;
[_entity,_priority get "id"] call IVCS_EntityTasks_cancelTask;
[(_entity get "currentWaypointIndex") == 1 && { count (_entity get "waypoints") == 3 }, "completion-triggered cycle interruption resumes next leg"] call _assert;
[_entity] call _clean;

// Overlapping combat and priority pauses must be counted exactly once.
private _entity = call _create;
private _a = ["HOLD_TEST",[["destination",[14800,16200,0]]]] call IVCS_EntityTasks_createTaskInstance;
[_entity,_a] call IVCS_VirtualSpace_entityAddTask;
[_entity,_a] call IVCS_EntityTasks_processTask;
private _clock = _a get "context" get "startedAt";
_entity set ["combatID","activation_clock_test"];
_entity set ["combatStartedAt",IVCS_SimulationTime];
private _combat = IVCS_VirtualSpace_Controller get "combat";
(_combat get "engagements") set ["activation_clock_test",createHashMapFromArray [
    ["groups",[_entity get "id"]],["nativeSettings",createHashMap]
]];
sleep 0.1;
private _b = ["MOVE",[["destination",[14500,16400,0]]]] call IVCS_EntityTasks_createTaskInstance;
private _id = [_entity,_b,false] call IVCS_VirtualSpace_entityAddTask;
sleep 0.1;
["activation_clock_test"] call IVCS_Combat_finish;
sleep 0.1;
[_entity,_id] call IVCS_EntityTasks_cancelTask;
private _adjustment = (_a get "context" get "startedAt")-_clock;
[_adjustment >= 0.25 && { _adjustment <= 0.6 }, "overlapping pauses counted once"] call _assert;
[_entity] call _clean;

// A second cancellation of an already removed path must preserve other requests.
private _one = ["man","SAFE",[14500,16200,0],[14800,16200,0],[],{}] call IVCS_Paths_createPathRequest;
private _two = ["man","SAFE",[14500,16200,0],[14800,16300,0],[],{}] call IVCS_Paths_createPathRequest;
[_one] call IVCS_Paths_removePathRequest;
[_one] call IVCS_Paths_removePathRequest;
[(IVCS_Paths_Generator get "requestQueue") findIf { (_x select 0) == _two } != -1, "repeated path removal preserves unrelated queued requests"] call _assert;
[_two] call IVCS_Paths_removePathRequest;

// Stop in-flight native boarding, free its owned seats, and reapproach on resume.
private _entity = call _create;
private _vehicle = ["C_Van_01_transport_F",[14503,16200,0]] call IVCS_VirtualSpace_Vehicle_createEntity;
[_entity] call IVCS_VirtualSpace_Group_spawn;
[_vehicle] call IVCS_VirtualSpace_Vehicle_spawn;
private _object = ((_entity get "units") select 0) get "object";
_object disableAI "MOVE";
private _board = [_entity,_vehicle] call IVCS_EntityTasks_createGetinTask;
[_entity,_board] call IVCS_VirtualSpace_entityAddTask;
for "_i" from 0 to 2 do { [_entity,_board] call IVCS_EntityTasks_processTask; };
[(_board get "context" get "reservedUnits") isNotEqualTo [], "boarding suspension fixture owns a reservation"] call _assert;
private _priority = ["MOVE",[["destination",[14500,16300,0]]]] call IVCS_EntityTasks_createTaskInstance;
private _id = [_entity,_priority,false] call IVCS_VirtualSpace_entityAddTask;
[(((_entity get "units") select 0) get "vehicleAssignment") isEqualTo [] && { (_entity get "vehiclesInCargoOf") isEqualTo [] }, "boarding suspension releases seats and cargo movement link"] call _assert;
[_entity,_priority] call IVCS_EntityTasks_processTask;
[_entity,_id] call IVCS_EntityTasks_cancelTask;
[(_board get "currentState") == "approaching", "boarding resumes by approaching from current position"] call _assert;
[_entity,_board] call IVCS_EntityTasks_processTask;
[_entity,_board] call IVCS_EntityTasks_processTask;
[(_board get "context" get "reservedUnits") isNotEqualTo [], "resumed boarding reserves seats again"] call _assert;
_object enableAI "MOVE";
[_entity] call _clean;
[_vehicle] call IVCS_VirtualSpace_Vehicle_despawn;
[_vehicle] call IVCS_VirtualSpace_unregisterEntity;

// LAND suspension removes its pad and native commands, then recreates them on resume.
private _entity = call _create;
((_entity get "units") select 0) set ["class","B_Helipilot_F"];
private _heli = ["B_Heli_Light_01_F",[14500,16200,50]] call IVCS_VirtualSpace_Vehicle_createEntity;
_heli set ["engineOn",true];
[_entity,_heli] call IVCS_VirtualSpace_Group_assignVehicle;
[_entity] call IVCS_VirtualSpace_Group_spawn;
(_heli get "object") allowDamage false;
private _land = [_entity,[15000,16200,0]] call IVCS_EntityTasks_createLandTask;
[_entity,_land] call IVCS_VirtualSpace_entityAddTask;
[_entity,_land] call IVCS_EntityTasks_processTask;
private _pad = _land get "context" get "helipad";
[!isNull _pad, "landing suspension fixture owns a pad"] call _assert;
private _priority = ["MOVE",[["destination",[14500,16400,0]]]] call IVCS_EntityTasks_createTaskInstance;
private _id = [_entity,_priority,false] call IVCS_VirtualSpace_entityAddTask;
sleep 0.1;
[isNull _pad && { isNull (_land get "context" get "approachObject") }, "landing suspension releases pad and approach command"] call _assert;
[_entity,_priority] call IVCS_EntityTasks_processTask;
[_entity,_id] call IVCS_EntityTasks_cancelTask;
[_entity,_land] call IVCS_EntityTasks_processTask;
[!isNull (_land get "context" get "helipad") && { (_land get "context" get "approachObject") isEqualTo (_heli get "object") }, "landing resume rebuilds native landing resources"] call _assert;
[_entity] call _clean;
[_heli] call IVCS_VirtualSpace_Vehicle_despawn;
[_heli] call IVCS_VirtualSpace_unregisterEntity;

// Complete actual MOVE A -> MOVE B -> MOVE A in native and virtual simulation.
{
    private _native = _x;
    private _entity = call _create;
    if (_native) then {
        [_entity] call IVCS_VirtualSpace_Group_spawn;
        (_entity get "group") setBehaviourStrong "CARELESS";
    };
    private _a = ["MOVE",[["destination",[14530,16200,0]]]] call IVCS_EntityTasks_createTaskInstance;
    [_entity,_a] call IVCS_VirtualSpace_entityAddTask;
    [_entity,0.1] call IVCS_VirtualSpace_Group_update;
    private _b = ["MOVE",[["destination",[14500,16225,0]]]] call IVCS_EntityTasks_createTaskInstance;
    [_entity,_b,false] call IVCS_VirtualSpace_entityAddTask;
    private _deadline = diag_tickTime+60;
    while { (_a get "status") in ["pending","running"] && { diag_tickTime < _deadline } } do {
        [_entity,0.1] call IVCS_VirtualSpace_Group_update;
        sleep 0.1;
    };
    [(_a get "status") == "completed" && { (_b get "status") == "completed" } &&
        { (_entity get "position") distance2D [14530,16200,0] <= 10 } &&
        { (_entity get "waypoints") isEqualTo [] }, format ["actual MOVE A-B-A completes native=%1",_native]] call _assert;
    [_entity] call _clean;
} forEach [false,true];

removeMissionEventHandler ["EachFrame", IVCS_Paths_Generator get "onFrameHandlerID"];
{ if (!isNull _y) then { deleteVehicle _y; }; } forEach (IVCS_Paths_Generator get "props");
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2", IVCS_Tasks_TestPassed, IVCS_Tasks_TestFailed];
