waitUntil { time > 0 };
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
IVCS_Tasks_TestPassed = 0;
IVCS_Tasks_TestFailed = 0;
private _assert = {
    params ["_ok", "_label"];
    if (_ok) then {
        IVCS_Tasks_TestPassed = IVCS_Tasks_TestPassed + 1;
        diag_log format ["[IVCS TASK TEST] PASS %1", _label];
    } else {
        IVCS_Tasks_TestFailed = IVCS_Tasks_TestFailed + 1;
        diag_log format ["[IVCS TASK TEST] FAIL %1", _label];
    };
};
[
    "STATE_TEST",
    [
        ["start", [
            ["onEnter", { _this set ["entered", (_this get "entered") + 1]; }],
            ["onUpdate", { "end" }],
            ["onLeaving", { _this set ["left", (_this get "left") + 1]; }]
        ]],
        ["end", [["isEndState", true]]]
    ],
    "start",
    [["entered", 0], ["left", 0], ["nested", [[0], createHashMapFromArray [["value", [0]]]]]]
] call IVCS_EntityTasks_createTaskTemplate;
private _first = ["STATE_TEST"] call IVCS_EntityTasks_createTaskInstance;
private _second = ["STATE_TEST"] call IVCS_EntityTasks_createTaskInstance;
private _nested = (_first get "context") get "nested";
(_nested select 0) set [0, 99];
((_nested select 1) get "value") set [0, 99];
[(((_second get "context") get "nested") select 0) isEqualTo [0], "array defaults isolated"] call _assert;
[((((_second get "context") get "nested") select 1) get "value") isEqualTo [0], "nested HashMap defaults isolated"] call _assert;
(_first get "template") set ["sharedTest", true];
[(_second get "template") get "sharedTest", "shared template definitions"] call _assert;
private _overrides = createHashMapFromArray [["nested", [[7]]]];
private _third = ["STATE_TEST", _overrides] call IVCS_EntityTasks_createTaskInstance;
(((_third get "context") get "nested") select 0) set [0, 8];
[((_overrides get "nested") select 0) isEqualTo [7], "override context isolated"] call _assert;
private _unknown = ["NOT_REGISTERED"] call IVCS_EntityTasks_createTaskInstance;
[isNil "_unknown", "unknown template rejected"] call _assert;
private _invalid = ["INVALID", [], "missing"] call IVCS_EntityTasks_createTaskTemplate;
[isNil "_invalid", "invalid initial state rejected"] call _assert;

private _grid = [[0, 0], worldSize, 1000] call IVCS_SpacialGrid_create;
IVCS_VirtualSpace_Controller = createHashMapFromArray [
    ["combat", [] call IVCS_Combat_createController],
    ["debug", false], ["nextEntityID", 0], ["nextWaypointId", 0],
    ["entities", createHashMapFromArray [["ALL", createHashMap], ["active", []], ["inactive", []]]],
    ["entitiesSpacialGrid", _grid]
];
IVCS_Common_WeaponInfo = createHashMap;
IVCS_Common_MagazineInfo = createHashMap;
IVCS_Common_AmmoInfo = createHashMap;
IVCS_Common_UnitInfo = createHashMap;
IVCS_Common_WeaponAliases = createHashMap;
IVCS_Paths_Generator = [] call IVCS_Paths_createGenerator;
private _createGroup = {
    params ["_position"];
    private _unit = ["C_man_1", "u_0"] call IVCS_VirtualSpace_Group_createUnit;
    ["WEST", "BLU_F", _position, [_unit]] call IVCS_VirtualSpace_Group_createEntity
};
private _cleanGroup = {
    params ["_entity"];
    if (_entity get "active") then { [_entity] call IVCS_VirtualSpace_Group_despawn; };
    [_entity] call IVCS_VirtualSpace_unregisterEntity;
};
// Waypoint options and owner links must work through public attach/remove calls.
private _position = [14500, 16400, 0];
private _options = [
    ["speed", "limited"], ["completionRadius", 3], ["behavior", "careless"],
    ["formation", "wedge"], ["combatMode", "blue"], ["description", "named"]
];
private _named = [_position, "move", _options] call IVCS_VirtualSpace_createEntityWaypoint;
[(_named get "speed") == "LIMITED" && { (_named get "completionRadius") == 3 } &&
    { (_named get "behavior") == "CARELESS" } && { (_named get "formation") == "WEDGE" } &&
    { (_named get "combatMode") == "BLUE" } && { (_named get "description") == "named" },
    "named options preserve values and normalize enums"] call _assert;
(_named get "position") set [0, 1];
[(_position select 0) == 14500, "waypoint position is independent of caller position"] call _assert;
[_options select 0 isEqualTo ["speed", "limited"], "creation does not mutate caller options"] call _assert;
private _defaultWaypoint = [_position] call IVCS_VirtualSpace_createEntityWaypoint;
[(_defaultWaypoint get "speed") == "UNCHANGED" && { (_defaultWaypoint get "completionRadius") == -1 } &&
    { (_defaultWaypoint get "callbacks") isEqualTo [] } && { (_defaultWaypoint get "movePoints") isEqualTo [] },
    "waypoint defaults include complete runtime state"] call _assert;
private _entity = [_position] call _createGroup;
[isNil { _defaultWaypoint get "entity" }, "new waypoint is detached"] call _assert;
[_entity, _defaultWaypoint] call IVCS_VirtualSpace_entityAddWaypoint;
(_defaultWaypoint get "entity") set ["ownerProbe", 17];
[(_entity get "ownerProbe") == 17, "attached waypoint references the live owner"] call _assert;
[_entity, _defaultWaypoint] call IVCS_VirtualSpace_entityRemoveWaypoint;
[isNil { _defaultWaypoint get "entity" }, "removal clears waypoint owner"] call _assert;
private _remaining = [_position] call IVCS_VirtualSpace_createEntityWaypoint;
[_entity, _remaining] call IVCS_VirtualSpace_entityAddWaypoint;
private _secondOwned = [_position] call IVCS_VirtualSpace_createEntityWaypoint;
[_entity, _secondOwned] call IVCS_VirtualSpace_entityAddWaypoint;
[_entity, _secondOwned] call IVCS_VirtualSpace_entityRemoveWaypoint;
[isNil { _secondOwned get "entity" } && { !isNil { _remaining get "entity" } },
    "removing a later waypoint preserves the earlier owner link"] call _assert;
[_entity, _defaultWaypoint] call IVCS_VirtualSpace_entityRemoveWaypoint;
[(_entity get "waypoints") isEqualTo [_remaining] && { !isNil { _remaining get "entity" } },
    "repeated removal preserves other ownership"] call _assert;
[_entity] call IVCS_VirtualSpace_unregisterEntity;
[isNil { _remaining get "entity" }, "owner teardown detaches remaining waypoints"] call _assert;

// Filter only the generated statement, preserving strings, blocks, and comments.
private _bridge = "['e_0', 'wp_0'] call IVCS_VirtualSpace_onWaypointCompleted";
private _user = "private _importedIncrement = 1; IVCS_Tasks_ImportedStatementCount = IVCS_Tasks_ImportedStatementCount + _importedIncrement";
private _quoted = "diag_log 'text; IVCS_VirtualSpace_onWaypointCompleted'";
private _nested = "if (true) then { private _value = ';'; diag_log _value; }";
[([_bridge] call IVCS_VirtualSpace_filterWaypointStatements) isEqualTo [],
    "standalone internal completion callback filtered"] call _assert;
[(["['old_owner','old_wp'] CALL IVCS_VirtualSpace_onWaypointCompleted"] call IVCS_VirtualSpace_filterWaypointStatements) isEqualTo [],
    "callback filtering is independent of the recorded owner"] call _assert;
[([_user] call IVCS_VirtualSpace_filterWaypointStatements) isEqualTo [_user],
    "absent internal callback preserves the last user statement"] call _assert;
private _mixed = [_user, _bridge, _quoted, _nested] joinString ";";
[([_mixed] call IVCS_VirtualSpace_filterWaypointStatements) isEqualTo [[_user, _quoted, _nested] joinString ";"],
    "mixed import preserves quoted semicolons and nested code"] call _assert;
private _escaped = "diag_log 'a'';b'";
[([_escaped + ";" + _bridge] call IVCS_VirtualSpace_filterWaypointStatements) isEqualTo [_escaped],
    "filter preserves escaped quotes"] call _assert;
private _comment = "/* ; } */ diag_log 'ok'";
[([_comment + ";" + _bridge] call IVCS_VirtualSpace_filterWaypointStatements) isEqualTo [_comment],
    "filter preserves block comments"] call _assert;
private _line = "// ; }" + toString [10] + "diag_log 'ok'";
[([_line + ";" + _bridge] call IVCS_VirtualSpace_filterWaypointStatements) isEqualTo [_line],
    "filter preserves line comments"] call _assert;
[([""] call IVCS_VirtualSpace_filterWaypointStatements) isEqualTo [],
    "empty native statements import cleanly"] call _assert;
[(["/* framework */ " + _bridge + " // end"] call IVCS_VirtualSpace_filterWaypointStatements) isEqualTo [],
    "filter handles comments surrounding the internal callback"] call _assert;
[(["// framework" + toString [10] + _bridge] call IVCS_VirtualSpace_filterWaypointStatements) isEqualTo [],
    "filter handles a leading line comment before the callback"] call _assert;

// Native import must be attachable and complete user code once without recursion.
private _entity = [[14500, 16400, 0]] call _createGroup;
[_entity] call IVCS_VirtualSpace_Group_spawn;
private _source = [[14600, 16400, 0], "MOVE", [["speed", "NORMAL"], ["completionRadius", 3]]] call IVCS_VirtualSpace_createEntityWaypoint;
[_entity, _source] call IVCS_VirtualSpace_entityAddWaypoint;
private _nativeWaypoint = [_entity get "group", 0];
private _bridge = (waypointStatements _nativeWaypoint) select 1;
_nativeWaypoint setWaypointStatements ["true", [_user, _bridge, _quoted, _nested] joinString ";"];
private _imported = [_entity, _nativeWaypoint] call IVCS_VirtualSpace_waypointToEntityWaypoint;
[(_imported get "statements") isEqualTo [[_user, _quoted, _nested] joinString ";"],
    "native converter removes its bridge and preserves user statements"] call _assert;
[(_imported get "name") == (_source get "name") && { (_imported get "pathGenerationRequestID") == "" } &&
    { (_imported get "callbacks") isEqualTo [] } && { isNil { _imported get "entity" } },
    "native import preserves its name and starts detached with complete defaults"] call _assert;
[_entity, _source] call IVCS_VirtualSpace_entityRemoveWaypoint;
[isNil { _source get "entity" }, "native removal detaches the source waypoint"] call _assert;
[_entity, _imported] call IVCS_VirtualSpace_entityAddWaypoint;
IVCS_Tasks_ImportedStatementCount = 0;
IVCS_Tasks_ImportedCallbackCount = 0;
[_imported, [29], {
    params ["_entity", "_waypoint", "_arguments"];
    (_waypoint get "entity") set ["callbackOwnerProbe", _arguments select 0];
    IVCS_Tasks_ImportedCallbackCount = IVCS_Tasks_ImportedCallbackCount + 1;
}] call IVCS_VirtualSpace_addWaypointCallback;
[_entity get "id", _imported get "name"] call IVCS_VirtualSpace_onWaypointCompleted;
[IVCS_Tasks_ImportedStatementCount == 1 && { IVCS_Tasks_ImportedCallbackCount == 1 },
    "imported completion preserves private scope and runs callbacks once"] call _assert;
[(_entity get "callbackOwnerProbe") == 29, "completion callbacks can read live waypoint ownership"] call _assert;
[isNil { _imported get "entity" } && { (_entity get "waypoints") isEqualTo [] },
    "completion detaches the imported waypoint"] call _assert;
[_entity] call _cleanGroup;

private _entity = [[14500, 16200, 0]] call _createGroup;
[_entity, _first] call IVCS_VirtualSpace_entityAddTask;
IVCS_Tasks_CallbackCount = 0;
[_first, {
    params ["_task", "_argument"];
    if (_argument == "callbackArgs") then {
        IVCS_Tasks_CallbackCount = IVCS_Tasks_CallbackCount + 1;
    };
}, ["callbackArgs"]] call IVCS_EntityTasks_setCallback;
[_entity, _first] call IVCS_EntityTasks_processTask;
[_entity, _first] call IVCS_EntityTasks_processTask;
[_entity, _first] call IVCS_EntityTasks_processTask;
[(_first get "status") == "completed", "terminal state completes"] call _assert;
[(_first get "context" get "entered") == 1 && { (_first get "context" get "left") == 1 }, "enter/leave callbacks once"] call _assert;
[IVCS_Tasks_CallbackCount == 1, "completion callback once"] call _assert;
[(_entity get "tasks") isEqualTo [], "finished task dequeues"] call _assert;
private _defaultMove = [_entity, [14600, 16200, 0]] call IVCS_EntityTasks_createMoveTask;
[(_defaultMove get "name") == "MOVE" && {
    (_defaultMove get "context" get "completionRadius") == 50 &&
    { (_defaultMove get "context" get "speed") == "UNCHANGED" }
}, "MOVE creator preserves optional defaults"] call _assert;
[_entity] call _cleanGroup;

{
    _x params ["_mode", "_startActive", "_transition", "_position"];
    private _entity = [_position] call _createGroup;
    private _destination = _position vectorAdd [30, 0, 0];
    private _task = [_entity, _destination, 7, "NORMAL"] call IVCS_EntityTasks_createMoveTask;
    [(_task get "name") == "MOVE" && {
        (_task get "context" get "destination") isEqualTo _destination &&
        { (_task get "context" get "completionRadius") == 7 } &&
        { (_task get "context" get "speed") == "NORMAL" }
    }, _mode + " MOVE creator forwards supplied arguments"] call _assert;
    [_entity, _task] call IVCS_VirtualSpace_entityAddTask;
    _task set ["callback", { IVCS_Tasks_CallbackCount = IVCS_Tasks_CallbackCount + 1; }];
    IVCS_Tasks_CallbackCount = 0;
    if (_startActive) then {
        [_entity] call IVCS_VirtualSpace_Group_spawn;
        (_entity get "group") setBehaviourStrong "CARELESS";
    };
    diag_log format ["[IVCS TASK TEST] BEGIN movement %1", _mode];
    private _deadline = diag_tickTime + 90;
    private _transitionAt = diag_tickTime + 1;
    private _transitioned = !_transition;
    while { (_task get "status") in ["pending", "running"] && { diag_tickTime < _deadline } } do {
        [_entity, 0.1] call IVCS_VirtualSpace_Group_update;
        if (!_transitioned && { diag_tickTime >= _transitionAt }) then {
            if (_entity get "active") then {
                [_entity] call IVCS_VirtualSpace_Group_despawn;
            } else {
                [_entity] call IVCS_VirtualSpace_Group_spawn;
                (_entity get "group") setBehaviourStrong "CARELESS";
            };
            _transitioned = true;
        };
        sleep 0.1;
    };
    [(_task get "status") == "completed", _mode + " MOVE completes"] call _assert;
    [(_entity get "position") distance2D _destination <= 10, _mode + " reaches destination"] call _assert;
    [(_entity get "tasks") isEqualTo [] && { (_entity get "waypoints") isEqualTo [] }, _mode + " queue/waypoint cleanup"] call _assert;
    [IVCS_Tasks_CallbackCount == 1, _mode + " callback once"] call _assert;
    [_entity, _task] call IVCS_EntityTasks_processTask;
    [IVCS_Tasks_CallbackCount == 1, _mode + " completion idempotent"] call _assert;
    [_entity] call _cleanGroup;
} forEach [
    ["virtual", false, false, [14500, 16200, 0]],
    ["spawned", true, false, [14500, 16210, 0]],
    ["spawned to virtual", true, true, [14500, 16220, 0]],
    ["virtual to spawned", false, true, [14500, 16230, 0]]
];

private _entity = [[14500, 16240, 0]] call _createGroup;
private _alreadyThere = ["MOVE", [["destination", [14500, 16240, 0]]]] call IVCS_EntityTasks_createTaskInstance;
[_entity, _alreadyThere] call IVCS_VirtualSpace_entityAddTask;
private _following = ["STATE_TEST"] call IVCS_EntityTasks_createTaskInstance;
[_entity, _following] call IVCS_VirtualSpace_entityAddTask;
private _unrelated = [[14550, 16240, 0]] call IVCS_VirtualSpace_createEntityWaypoint;
[_entity, _unrelated] call IVCS_VirtualSpace_entityAddWaypoint;
[_entity, _alreadyThere] call IVCS_EntityTasks_processTask;
[_entity, _alreadyThere] call IVCS_EntityTasks_processTask;
[([_entity] call IVCS_VirtualSpace_getCurrentEntityTask) isEqualTo _following, "following task preserved"] call _assert;
[!(_unrelated in (_entity get "waypoints")) && { isNil { _unrelated get "entity" } }, "standalone waypoints wait in their own task"] call _assert;
[_entity, _following] call IVCS_EntityTasks_processTask;
[_entity, _following] call IVCS_EntityTasks_processTask;
[(_following get "status") == "completed" && { _unrelated in (_entity get "waypoints") }, "following task completes and activates standalone sequence"] call _assert;
[_entity, _unrelated] call IVCS_VirtualSpace_entityRemoveWaypoint;
[_entity, _unrelated] call IVCS_VirtualSpace_entityRemoveWaypoint;
[(_entity get "waypoints") isEqualTo [], "waypoint removal idempotent"] call _assert;
private _sequence = [_entity] call IVCS_VirtualSpace_getCurrentEntityTask;
[_entity, _sequence] call IVCS_EntityTasks_processTask;
[_entity, _sequence] call IVCS_EntityTasks_processTask;
[(_entity get "tasks") isEqualTo [], "empty standalone sequence completes"] call _assert;
[_entity] call _cleanGroup;

private _entity = [[14500, 16250, 0]] call _createGroup;
private _failure = ["MOVE", [["destination", [14530, 16250, 0]]]] call IVCS_EntityTasks_createTaskInstance;
[_entity, _failure] call IVCS_VirtualSpace_entityAddTask;
[_entity, _failure] call IVCS_EntityTasks_processTask;
private _waypoint = (_failure get "waypoints") select 0;
[_entity get "id", _waypoint get "name", []] call IVCS_VirtualSpace_Group_onWaypointPathGenerated;
[_entity, _failure] call IVCS_EntityTasks_processTask;
[_entity, _failure] call IVCS_EntityTasks_processTask;
[(_failure get "status") == "failed", "empty path fails MOVE"] call _assert;
[(_entity get "tasks") isEqualTo [] && { (_entity get "waypoints") isEqualTo [] }, "failed MOVE cleanup"] call _assert;
[_entity] call _cleanGroup;
// Cancellation cleans pending/running instances exactly once; IDs are never reused.
private _entity = [[14500, 16255, 0]] call _createGroup;
private _pending = ["STATE_TEST"] call IVCS_EntityTasks_createTaskInstance;
private _pendingID = [_entity, _pending] call IVCS_VirtualSpace_entityAddTask;
IVCS_Tasks_CancelCallbacks = 0;
_pending set ["callback", { IVCS_Tasks_CancelCallbacks = IVCS_Tasks_CancelCallbacks + 1; }];
[[_entity, _pendingID] call IVCS_EntityTasks_cancelTask, "pending cancellation succeeds"] call _assert;
[(_pending get "status") == "cancelled" && { (_pending get "context" get "entered") == 0 }, "pending cancellation does not enter state"] call _assert;
[!([_entity, _pendingID] call IVCS_EntityTasks_cancelTask) && { IVCS_Tasks_CancelCallbacks == 1 }, "cancellation is idempotent"] call _assert;
private _reused = [_entity, _pending] call IVCS_VirtualSpace_entityAddTask;
[isNil "_reused", "cancelled instances cannot be requeued"] call _assert;
private _old = ["MOVE", [["destination", [14540, 16255, 0]]]] call IVCS_EntityTasks_createTaskInstance;
private _oldID = [_entity, _old] call IVCS_VirtualSpace_entityAddTask;
[_entity, _old] call IVCS_EntityTasks_processTask;
private _oldWaypoint = (_old get "waypoints") select 0;
private _following = ["STATE_TEST"] call IVCS_EntityTasks_createTaskInstance;
private _followingID = [_entity, _following] call IVCS_VirtualSpace_entityAddTask;
private _replacement = ["STATE_TEST"] call IVCS_EntityTasks_createTaskInstance;
private _replacementID = [_entity, _oldID, _replacement] call IVCS_EntityTasks_replaceTask;
[!isNil "_replacementID" && { _replacementID != _oldID && { _replacementID != _followingID } }, "replacement receives unique ID"] call _assert;
[(_old get "status") == "cancelled" && { (_old get "waypoints") isEqualTo [] }, "replacement cancels old work and waypoints"] call _assert;
[isNil { _oldWaypoint get "entity" }, "replacement detaches old task waypoints"] call _assert;
[(_entity get "tasks") isEqualTo [_replacement, _following], "replacement preserves queue slot and following task"] call _assert;
[_entity, _replacement] call IVCS_EntityTasks_processTask;
[_entity, _replacement] call IVCS_EntityTasks_processTask;
[(_replacement get "status") == "completed", "replacement completes normally"] call _assert;
[[_entity, _followingID] call IVCS_EntityTasks_cancelTask, "following pending task can be cancelled"] call _assert;
[_entity] call _cleanGroup;

// Cancelling from onEnter must not continue processing or execute onLeaving twice.
[
    "SELF_CANCEL",
    [["start", [
        ["onEnter", {
            private _entity = [_this get "entityID"] call IVCS_VirtualSpace_getEntity;
            [_entity, _this get "taskID"] call IVCS_EntityTasks_cancelTask;
        }],
        ["onUpdate", { _this set ["updates", (_this get "updates") + 1]; }],
        ["onLeaving", { _this set ["exits", (_this get "exits") + 1]; }]
    ]]],
    "start", [["updates", 0], ["exits", 0], ["cleanups", 0]],
    { _this set ["cleanups", (_this get "cleanups") + 1]; }
] call IVCS_EntityTasks_createTaskTemplate;
private _entity = [[14500, 16255, 0]] call _createGroup;
private _selfCancel = ["SELF_CANCEL"] call IVCS_EntityTasks_createTaskInstance;
[_entity, _selfCancel] call IVCS_VirtualSpace_entityAddTask;
[_entity, _selfCancel] call IVCS_EntityTasks_processTask;
[(_selfCancel get "status") == "cancelled" && { (_selfCancel get "context" get "updates") == 0 }, "self-cancel skips subsequent update"] call _assert;
[(_selfCancel get "context" get "exits") == 1 && { (_selfCancel get "context" get "cleanups") == 1 }, "self-cancel exit and cleanup run once"] call _assert;
[_entity] call _cleanGroup;

// A spawned MOVE must stop advancing after cancellation, then accept replacement movement.
private _entity = [[14500, 16255, 0]] call _createGroup;
[_entity] call IVCS_VirtualSpace_Group_spawn;
(_entity get "group") setBehaviourStrong "CARELESS";
private _native = ["MOVE", [["destination", [14600, 16255, 0]]]] call IVCS_EntityTasks_createTaskInstance;
private _nativeID = [_entity, _native] call IVCS_VirtualSpace_entityAddTask;
[_entity, 0.1] call IVCS_VirtualSpace_Group_update;
sleep 1;
[_entity, 0.1] call IVCS_VirtualSpace_Group_update;
[_entity, _nativeID] call IVCS_EntityTasks_cancelTask;
sleep 1;
private _stoppedAt = getPos leader (_entity get "group");
sleep 3;
private _after = getPos leader (_entity get "group");
[_after distance2D _stoppedAt < 3, "spawned cancellation stops old movement"] call _assert;
[(_entity get "tasks") isEqualTo [] && { (_entity get "waypoints") isEqualTo [] }, "spawned cancellation releases queue and waypoints"] call _assert;
// A new MOVE after cancellation must release the native hold.
private _resumeDestination = _after vectorAdd [0, 25, 0];
private _resume = ["MOVE", [["destination", _resumeDestination]]] call IVCS_EntityTasks_createTaskInstance;
[_entity, _resume] call IVCS_VirtualSpace_entityAddTask;
private _resumeDeadline = diag_tickTime + 30;
while { (_resume get "status") in ["pending", "running"] && { diag_tickTime < _resumeDeadline } } do {
    [_entity, 0.1] call IVCS_VirtualSpace_Group_update;
    sleep 0.1;
};
[(_resume get "status") == "completed", "new MOVE resumes after native cancellation"] call _assert;
[_entity] call _cleanGroup;

// Owner teardown must terminate running and pending work without starting it.
{
    private _spawned = _x;
    private _mode = if (_spawned) then { "spawned owner" } else { "virtual owner" };
    private _entity = [[14500, 16260, 0]] call _createGroup;
    if (_spawned) then { [_entity] call IVCS_VirtualSpace_Group_spawn; };
    private _running = ["MOVE", [["destination", [14540, 16260, 0]]]] call IVCS_EntityTasks_createTaskInstance;
    [_entity, _running] call IVCS_VirtualSpace_entityAddTask;
    [_entity, _running] call IVCS_EntityTasks_processTask;
    private _pending = ["STATE_TEST"] call IVCS_EntityTasks_createTaskInstance;
    [_entity, _pending] call IVCS_VirtualSpace_entityAddTask;
    private _following = ["STATE_TEST"] call IVCS_EntityTasks_createTaskInstance;
    [_entity, _following] call IVCS_VirtualSpace_entityAddTask;
    IVCS_Tasks_RemovedCallbacks = [];
    {
        _x set ["callback", {
            params ["_task"];
            IVCS_Tasks_RemovedCallbacks pushBack (_task get "status");
        }];
    } forEach [_running, _pending, _following];

    private _waypoint = (_running get "waypoints") select 0;
    private _requestID = [
        "man", "SAFE", _entity get "position", _waypoint get "position",
        [_entity get "id", _waypoint get "name"], IVCS_VirtualSpace_Group_onWaypointPathGenerated
    ] call IVCS_Paths_createPathRequest;
    _waypoint set ["pathGenerationRequestID", _requestID];
    private _unrelated = [[14560, 16260, 0]] call IVCS_VirtualSpace_createEntityWaypoint;
    [_entity, _unrelated] call IVCS_VirtualSpace_entityAddWaypoint;

    [_entity] call IVCS_VirtualSpace_unregisterEntity;
    [isNil { [_entity get "id"] call IVCS_VirtualSpace_getEntity }, _mode + " leaves registry"] call _assert;
    [(_running get "status") == "failed" && { (_pending get "status") == "failed" }, _mode + " fails running and pending tasks"] call _assert;
    [(_pending get "context" get "entered") == 0 && { (_pending get "context" get "left") == 0 }, _mode + " does not enter/leave pending states"] call _assert;
    [IVCS_Tasks_RemovedCallbacks isEqualTo ["failed", "failed", "failed"], _mode + " queued task callbacks run once"] call _assert;
    [(_entity get "tasks") isEqualTo [] && { (_entity get "waypoints") isEqualTo [] }, _mode + " releases queue and waypoints"] call _assert;
    [(_running get "waypoints") isEqualTo [], _mode + " clears task-owned waypoint references"] call _assert;
    [isNil { _waypoint get "entity" }, _mode + " detaches task waypoints"] call _assert;
    [(IVCS_Paths_Generator get "requestQueue") findIf { (_x select 0) == _requestID } == -1, _mode + " cancels pending path request"] call _assert;
    [_entity, _running, "failed"] call IVCS_EntityTasks_finishTask;
    [_entity, _pending, "failed"] call IVCS_EntityTasks_finishTask;
    [count IVCS_Tasks_RemovedCallbacks == 3, _mode + " repeated finish does not repeat callbacks"] call _assert;

    private _rejected = [_entity, ["STATE_TEST"] call IVCS_EntityTasks_createTaskInstance] call IVCS_VirtualSpace_entityAddTask;
    [isNil "_rejected" && { (_entity get "tasks") isEqualTo [] }, _mode + " rejects new work on removed owner"] call _assert;
    // Late path results for a removed owner must be harmless.
    [_entity get "id", _waypoint get "name", []] call IVCS_VirtualSpace_Group_onWaypointPathGenerated;
    if (_spawned) then { [_entity] call IVCS_VirtualSpace_Group_despawn; };
} forEach [false, true];

// Exercise the real final-unit death event, not just direct registry removal.
private _entity = [[14500, 16270, 0]] call _createGroup;
[_entity] call IVCS_VirtualSpace_Group_spawn;
private _unitObject = ((_entity get "units") select 0) get "object";
private _deathTask = ["MOVE", [["destination", [14540, 16270, 0]]]] call IVCS_EntityTasks_createTaskInstance;
[_entity, _deathTask] call IVCS_VirtualSpace_entityAddTask;
[_entity, _deathTask] call IVCS_EntityTasks_processTask;
IVCS_Tasks_DeathCallbackCount = 0;
_deathTask set ["callback", { IVCS_Tasks_DeathCallbackCount = IVCS_Tasks_DeathCallbackCount + 1; }];
_unitObject setDamage 1;
sleep 0.1;
[isNil { [_entity get "id"] call IVCS_VirtualSpace_getEntity }, "last-unit death unregisters owner"] call _assert;
[(_deathTask get "status") == "failed" && { IVCS_Tasks_DeathCallbackCount == 1 }, "last-unit death fails MOVE with one callback"] call _assert;
[(_entity get "tasks") isEqualTo [] && { (_entity get "waypoints") isEqualTo [] }, "last-unit death releases tasks and waypoints"] call _assert;
deleteVehicle _unitObject;
deleteGroup (_entity get "group");

// Production vehicle creation uses config inventories; weapon persistence is not
// under test here, so keep the vehicle turret cache empty for these fixtures.
IVCS_Common_VehicleConfigInventories = createHashMap;
IVCS_Common_VehicleTurrets = createHashMap;
private _createVehicle = {
    params ["_class", "_position"];
    [_class, _position] call IVCS_VirtualSpace_Vehicle_createEntity
};
private _cleanVehicle = {
    params ["_vehicle"];
    if (_vehicle get "active") then { [_vehicle] call IVCS_VirtualSpace_Vehicle_despawn; };
    [_vehicle] call IVCS_VirtualSpace_unregisterEntity;
};

// LAND: production helicopter/pilot links and native/virtual movement.
{
    _x params ["_native", "_transition", "_landingType"];
    private _mode = if (_native) then { "spawned LAND" } else { "virtual LAND" };
    if (_transition) then { _mode = _mode + " transition"; };
    if (_landingType != "LAND") then { _mode = _mode + " " + _landingType; };
    private _start = [14500, 16300, 50];
    private _destination = [14550, 16300, 0];
    private _crew = [_start] call _createGroup;
    ((_crew get "units") select 0) set ["class", "B_Helipilot_F"];
    private _heli = ["B_Heli_Light_01_F", _start] call _createVehicle;
    _heli set ["engineOn", true];
    [_crew, _heli] call IVCS_VirtualSpace_Group_assignVehicle;
    if (_native) then {
        [_crew] call IVCS_VirtualSpace_Group_spawn;
        (_crew get "group") setBehaviourStrong "CARELESS";
        (_heli get "object") allowDamage false;
    };
    private _land = [_crew, _destination, _landingType] call IVCS_EntityTasks_createLandTask;
    [(_land get "name") == "LAND", _mode + " creator returns named task"] call _assert;
    [_crew, _land] call IVCS_VirtualSpace_entityAddTask;
    IVCS_Tasks_LandCallbacks = 0;
    _land set ["callback", { IVCS_Tasks_LandCallbacks = IVCS_Tasks_LandCallbacks + 1; }];
    private _deadline = diag_tickTime + 150;
    private _lastPad = objNull;
    private _transitioned = !_transition;
    private _transitionAt = diag_tickTime + 0.2;
    diag_log format ["[IVCS TASK TEST] BEGIN %1", _mode];
    while { (_land get "status") in ["pending", "running"] && { diag_tickTime < _deadline } } do {
        [_heli, 0.1] call IVCS_VirtualSpace_Vehicle_update;
        [_crew, 0.1] call IVCS_VirtualSpace_Group_update;
        if (!isNull (_land get "context" get "helipad")) then { _lastPad = _land get "context" get "helipad"; };
        if (!_transitioned && { diag_tickTime >= _transitionAt } && {
            !_native || { _land get "context" get "waypointComplete" }
        }) then {
            if (_crew get "active") then {
                [_crew] call IVCS_VirtualSpace_Group_despawn;
            } else {
                [_crew] call IVCS_VirtualSpace_Group_spawn;
                (_crew get "group") setBehaviourStrong "CARELESS";
                (_heli get "object") allowDamage false;
            };
            _transitioned = true;
        };
        sleep 0.1;
    };
    diag_log format ["[IVCS TASK TEST] OBSERVED %1 status=%2 crew=%3 vehicle=%4", _mode, _land get "status", _crew get "position", _heli get "position"];
    [(_land get "status") == "completed", _mode + " completes"] call _assert;
    [(_heli get "position") distance2D _destination <= 25 && { ((_heli get "position") select 2) < 4 }, _mode + " reaches landing position"] call _assert;
    [(_crew get "tasks") isEqualTo [] && { (_crew get "waypoints") isEqualTo [] }, _mode + " releases queue and waypoints"] call _assert;
    [isNull _lastPad && { isNull (_land get "context" get "helipad") }, _mode + " releases helipad"] call _assert;
    [IVCS_Tasks_LandCallbacks == 1, _mode + " callback once"] call _assert;
    if (_transition) then { [_transitioned, _mode + " changed simulation mode"] call _assert; };
    if (_crew get "active" && { _landingType == "LAND" }) then {
        sleep 3;
        [isTouchingGround (_heli get "object"), "completed native LAND remains grounded after pad cleanup"] call _assert;
        private _takeoffDestination = _destination vectorAdd [200, 0, 0];
        private _move = ["MOVE", [["destination", _takeoffDestination]]] call IVCS_EntityTasks_createTaskInstance;
        [_crew, _move] call IVCS_VirtualSpace_entityAddTask;
        private _takeoffDeadline = diag_tickTime + 60;
        while { (_move get "status") in ["pending", "running"] && { diag_tickTime < _takeoffDeadline } } do {
            [_heli, 0.1] call IVCS_VirtualSpace_Vehicle_update;
            [_crew, 0.1] call IVCS_VirtualSpace_Group_update;
            sleep 0.1;
        };
        diag_log format ["[IVCS TASK TEST] OBSERVED takeoff status=%1 vehicle=%2", _move get "status", _heli get "position"];
        [(_move get "status") == "completed" && {
            (_heli get "position") distance2D _destination > 50
        }, "MOVE takes off after completed LAND"] call _assert;
    };
    [_crew] call _cleanGroup;
    [_heli] call _cleanVehicle;
} forEach [
    [false, false, "LAND"], [true, false, "LAND"],
    [true, true, "LAND"], [false, true, "LAND"],
    [false, false, "GET IN"], [true, false, "GET IN"],
    [false, false, "GET OUT"], [true, false, "GET OUT"]
];

// Landing cancellation must stop native orders and delete task-owned pads.
{
    private _removeOwner = _x;
    private _start = [14500, 16300, 50];
    private _crew = [_start] call _createGroup;
    ((_crew get "units") select 0) set ["class", "B_Helipilot_F"];
    private _heli = ["B_Heli_Light_01_F", _start] call _createVehicle;
    _heli set ["engineOn", true];
    [_crew, _heli] call IVCS_VirtualSpace_Group_assignVehicle;
    [_crew] call IVCS_VirtualSpace_Group_spawn;
    (_crew get "group") setBehaviourStrong "CARELESS";
    (_heli get "object") allowDamage false;
    private _land = [_crew, [15000, 16300, 0]] call IVCS_EntityTasks_createLandTask;
    private _id = [_crew, _land] call IVCS_VirtualSpace_entityAddTask;
    [_crew, 0.1] call IVCS_VirtualSpace_Group_update;
    sleep 2;
    [_heli, 0.1] call IVCS_VirtualSpace_Vehicle_update;
    [_crew, 0.1] call IVCS_VirtualSpace_Group_update;
    private _pad = _land get "context" get "helipad";
    [!isNull _pad, "running native LAND owns a helipad"] call _assert;
    if (_removeOwner) then {
        [_crew] call IVCS_VirtualSpace_unregisterEntity;
    } else {
        [_crew, _id] call IVCS_EntityTasks_cancelTask;
    };
    private _expected = if (_removeOwner) then { "failed" } else { "cancelled" };
    // deleteVehicle removes the engine object on the following frame.
    sleep 0.1;
    [(_land get "status") == _expected && { isNull _pad }, "LAND interruption cleans status and pad"] call _assert;
    [(_crew get "tasks") isEqualTo [] && { (_crew get "waypoints") isEqualTo [] }, "LAND interruption leaves no holding task"] call _assert;
    sleep 5;
    private _stoppedAt = getPosATL (_heli get "object");
    sleep 5;
    [(getPosATL (_heli get "object")) distance2D _stoppedAt < 15, "interrupted LAND stops old native approach"] call _assert;
    if (_removeOwner) then { [_crew] call IVCS_VirtualSpace_Group_despawn; } else { [_crew] call _cleanGroup; };
    [_heli] call _cleanVehicle;
} forEach [false, true];

// Boarding must complete only with all required reservations/occupants.
{
    _x params ["_native", "_rendezvous"];
    private _mode = if (_native) then { "spawned GET IN" } else { "virtual GET IN" };
    if (_rendezvous) then { _mode = _mode + " rendezvous"; };
    private _entity = [[14500, 16280, 0]] call _createGroup;
    private _vehicle = ["C_Van_01_transport_F", [14530, 16280, 0]] call _createVehicle;
    if (_native) then {
        [_entity] call IVCS_VirtualSpace_Group_spawn;
        (_entity get "group") setBehaviourStrong "CARELESS";
        [_vehicle] call IVCS_VirtualSpace_Vehicle_spawn;
    };
    private _point = if (_rendezvous) then { [14530, 16280, 0] } else { [-1, -1, -1] };
    private _board = [_entity, _vehicle, _point] call IVCS_EntityTasks_createGetinTask;
    [(_board get "name") == "GET IN", _mode + " creator returns named task"] call _assert;
    [_entity, _board] call IVCS_VirtualSpace_entityAddTask;
    IVCS_Tasks_BoardCallbacks = 0;
    _board set ["callback", { IVCS_Tasks_BoardCallbacks = IVCS_Tasks_BoardCallbacks + 1; }];
    private _deadline = diag_tickTime + 60;
    diag_log format ["[IVCS TASK TEST] BEGIN %1", _mode];
    while { (_board get "status") in ["pending", "running"] && { diag_tickTime < _deadline } } do {
        [_vehicle, 0.1] call IVCS_VirtualSpace_Vehicle_update;
        [_entity, 0.1] call IVCS_VirtualSpace_Group_update;
        sleep 0.1;
    };
    [(_board get "status") == "completed", _mode + " completes"] call _assert;
    private _assignment = ((_entity get "units") select 0) get "vehicleAssignment";
    [_assignment isNotEqualTo [] && { (_assignment select 0) == (_vehicle get "id") }, _mode + " reserves a target seat"] call _assert;
    [(_entity get "id") in (_vehicle get "entitiesInCargo"), _mode + " records cargo owner"] call _assert;
    [IVCS_Tasks_BoardCallbacks == 1 && { (_entity get "waypoints") isEqualTo [] }, _mode + " callback and waypoint cleanup"] call _assert;
    if (_native) then {
        [vehicle (((_entity get "units") select 0) get "object") == (_vehicle get "object"), "spawned GET IN waits for physical boarding"] call _assert;
    };
    [_entity] call _cleanGroup;
    [_vehicle] call _cleanVehicle;
} forEach [[false, false], [true, false], [false, true], [true, true]];

// Cancel reservation before virtual boarding reaches its terminal state.
private _entity = [[14500, 16290, 0]] call _createGroup;
private _vehicle = ["C_Van_01_transport_F", [14503, 16290, 0]] call _createVehicle;
private _board = [_entity, _vehicle] call IVCS_EntityTasks_createGetinTask;
private _boardID = [_entity, _board] call IVCS_VirtualSpace_entityAddTask;
[_entity, _board] call IVCS_EntityTasks_processTask;
[_entity, _board] call IVCS_EntityTasks_processTask;
[_entity, _board] call IVCS_EntityTasks_processTask;
private _reserved = ((_entity get "units") select 0) get "vehicleAssignment";
[_reserved isNotEqualTo [], "GET IN has reservations before terminal completion"] call _assert;
[_entity, _boardID] call IVCS_EntityTasks_cancelTask;
[(((_entity get "units") select 0) get "vehicleAssignment") isEqualTo [], "cancelled boarding releases seat"] call _assert;
[(_entity get "vehiclesInCargoOf") isEqualTo [] && { (_vehicle get "entitiesInCargo") isEqualTo [] }, "cancelled boarding releases cargo links"] call _assert;
[_entity] call _cleanGroup;
[_vehicle] call _cleanVehicle;

// Native reservation rollback must eject only units owned by the cancelled task.
{
    private _removeOwner = _x;
    private _entity = [[14500, 16290, 0]] call _createGroup;
    (_entity get "units") pushBack (["C_man_1", "u_1"] call IVCS_VirtualSpace_Group_createUnit);
    private _vehicle = ["C_Van_01_transport_F", [14503, 16290, 0]] call _createVehicle;
    [_entity] call IVCS_VirtualSpace_Group_spawn;
    [_vehicle] call IVCS_VirtualSpace_Vehicle_spawn;
    private _secondObject = ((_entity get "units") select 1) get "object";
    _secondObject disableAI "MOVE";
    private _board = [_entity, _vehicle] call IVCS_EntityTasks_createGetinTask;
    private _boardID = [_entity, _board] call IVCS_VirtualSpace_entityAddTask;
    for "_i" from 0 to 2 do { [_entity, _board] call IVCS_EntityTasks_processTask; };
    private _firstUnit = (_entity get "units") select 0;
    private _firstObject = _firstUnit get "object";
    private _seatPath = ((_firstUnit get "vehicleAssignment") select 1) select 0;
    if (_seatPath isEqualType []) then {
        _firstObject moveInTurret [_vehicle get "object", _seatPath];
    } else {
        _firstObject moveInCargo [_vehicle get "object", _seatPath];
    };
    [vehicle _firstObject == (_vehicle get "object"), "native rollback fixture has a boarded passenger"] call _assert;
    if (_removeOwner) then {
        [_entity] call IVCS_VirtualSpace_unregisterEntity;
    } else {
        [_entity, _boardID] call IVCS_EntityTasks_cancelTask;
    };
    [vehicle _firstObject == _firstObject, "boarding rollback ejects owned passenger"] call _assert;
    [(_entity get "units") findIf { (_x get "vehicleAssignment") isNotEqualTo [] } == -1, "boarding rollback frees all task reservations"] call _assert;
    [(_vehicle get "entitiesInCargo") isEqualTo [], "boarding rollback removes vehicle cargo link"] call _assert;
    _secondObject enableAI "MOVE";
    if (_removeOwner) then { [_entity] call IVCS_VirtualSpace_Group_despawn; } else { [_entity] call _cleanGroup; };
    [_vehicle] call _cleanVehicle;
} forEach [false, true];

// Missing targets and insufficient capacity fail without partial reservations.
private _entity = [[14500, 16290, 0]] call _createGroup;
private _missing = ["GET IN", [["vehicleID", "missing"]]] call IVCS_EntityTasks_createTaskInstance;
[_entity, _missing] call IVCS_VirtualSpace_entityAddTask;
[_entity, _missing] call IVCS_EntityTasks_processTask;
[_entity, _missing] call IVCS_EntityTasks_processTask;
[(_missing get "status") == "failed", "missing boarding target fails"] call _assert;
private _vehicle = ["C_Van_01_transport_F", [14503, 16290, 0]] call _createVehicle;
_vehicle set ["seats", []];
private _full = [_entity, _vehicle] call IVCS_EntityTasks_createGetinTask;
[_entity, _full] call IVCS_VirtualSpace_entityAddTask;
for "_i" from 0 to 3 do { [_entity, _full] call IVCS_EntityTasks_processTask; };
[(_full get "status") == "failed" && { ((_entity get "units") select 0) get "vehicleAssignment" isEqualTo [] }, "full target fails without partial seating"] call _assert;
[_entity] call _cleanGroup;
[_vehicle] call _cleanVehicle;

// Missing targets and timeouts must release reservations without requiring a
// registry lookup of the removed vehicle; pre-existing seating is not task-owned.
{
    private _removeTarget = _x;
    private _entity = [[14500, 16290, 0]] call _createGroup;
    private _vehicle = ["C_Van_01_transport_F", [14503, 16290, 0]] call _createVehicle;
    [_entity] call IVCS_VirtualSpace_Group_spawn;
    [_vehicle] call IVCS_VirtualSpace_Vehicle_spawn;
    (((_entity get "units") select 0) get "object") disableAI "MOVE";
    private _board = [_entity, _vehicle] call IVCS_EntityTasks_createGetinTask;
    [_entity, _board] call IVCS_VirtualSpace_entityAddTask;
    for "_i" from 0 to 2 do { [_entity, _board] call IVCS_EntityTasks_processTask; };
    [(_board get "currentState") == "boarding", "failure fixture interrupts unfinished native boarding"] call _assert;
    if (_removeTarget) then {
        [_vehicle] call IVCS_VirtualSpace_unregisterEntity;
    } else {
        (_board get "context") set ["timeout", -1];
    };
    for "_i" from 0 to 1 do { [_entity, _board] call IVCS_EntityTasks_processTask; };
    [(_board get "status") == "failed", "interrupted reserved boarding fails"] call _assert;
    [(((_entity get "units") select 0) get "vehicleAssignment") isEqualTo [] &&
        { (_vehicle get "entitiesInCargo") isEqualTo [] }, "failed boarding rolls back reservations and cargo"] call _assert;
    [_entity] call _cleanGroup;
    if (_removeTarget) then { [_vehicle] call IVCS_VirtualSpace_Vehicle_despawn; } else { [_vehicle] call _cleanVehicle; };
} forEach [false, true];

private _entity = [[14500, 16290, 0]] call _createGroup;
private _vehicle = ["C_Van_01_transport_F", [14503, 16290, 0]] call _createVehicle;
[_entity, _vehicle] call IVCS_VirtualSpace_Group_assignAsVehicleCargo;
private _existing = [_entity, _vehicle] call IVCS_EntityTasks_createGetinTask;
private _existingID = [_entity, _existing] call IVCS_VirtualSpace_entityAddTask;
for "_i" from 0 to 2 do { [_entity, _existing] call IVCS_EntityTasks_processTask; };
[_entity, _existingID] call IVCS_EntityTasks_cancelTask;
[(((_entity get "units") select 0) get "vehicleAssignment") isNotEqualTo [] &&
    { (_entity get "id") in (_vehicle get "entitiesInCargo") }, "boarding cancellation preserves pre-existing seating"] call _assert;
[_entity] call _cleanGroup;
[_vehicle] call _cleanVehicle;

private _entity = [[14500, 16290, 0]] call _createGroup;
private _invalidLand = [_entity, [14550, 16290, 0]] call IVCS_EntityTasks_createLandTask;
[_entity, _invalidLand] call IVCS_VirtualSpace_entityAddTask;
for "_i" from 0 to 1 do { [_entity, _invalidLand] call IVCS_EntityTasks_processTask; };
[(_invalidLand get "status") == "failed" && { (_entity get "waypoints") isEqualTo [] }, "LAND without a commanded helicopter fails cleanly"] call _assert;
[_entity] call _cleanGroup;

removeMissionEventHandler ["EachFrame", IVCS_Paths_Generator get "onFrameHandlerID"];
{ if (!isNull _y) then { deleteVehicle _y; }; } forEach (IVCS_Paths_Generator get "props");
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2", IVCS_Tasks_TestPassed, IVCS_Tasks_TestFailed];
