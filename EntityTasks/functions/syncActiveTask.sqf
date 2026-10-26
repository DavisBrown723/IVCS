/*
    Reconcile the queue head with the activated task immediately after mutations.
    Hooks may mutate the queue; reconcile again after they return. State entry is
    owned by processTask and is never repeated merely because a task resumes.
*/
params ["_entity"];
if (_entity getOrDefault ["taskTransition", false]) exitWith {};
_entity set ["taskTransition", true];
private _settled = false;
while { !_settled } do {
    private _desired = [_entity] call IVCS_VirtualSpace_getCurrentEntityTask;
    private _active = _entity get "activeTask";
    _settled = (isNil "_desired" && { isNil "_active" }) || {
        !isNil "_desired" && { !isNil "_active" } && { _desired isEqualRef _active }
    };
    if (!_settled) then {
        if (!isNil "_active") then { [_entity, _active] call IVCS_EntityTasks_deactivateTask; };
        // Deactivation hooks can cancel or replace the desired task.
        _desired = [_entity] call IVCS_VirtualSpace_getCurrentEntityTask;
        if (!isNil "_desired") then {
            _entity set ["activeTask", _desired];
            private _context = _desired get "context";
            private _pausedAt = _context getOrDefault ["pausedAt", -1];
            if (_pausedAt >= 0 && { "startedAt" in _context } && { (_context get "startedAt") >= 0 }) then {
                _context set ["startedAt", (_context get "startedAt") + (IVCS_SimulationTime - _pausedAt)];
            };
            _context set ["pausedAt", -1];
            _context set ["activatedAt", IVCS_SimulationTime];
            {
                [_entity, _x] call IVCS_VirtualSpace_entityAddWaypoint;
            } forEach (_desired get "waypoints");
            private _waypoints = _entity get "waypoints";
            private _resume = _desired getOrDefault ["resumeWaypoint", ""];
            private _index = _waypoints findIf { (_x get "name") == _resume };
            if (_index >= 0) then {
                _entity set ["currentWaypointIndex", _index];
                [_entity] call IVCS_VirtualSpace_determineCycleWaypointLoop;
                if (_entity get "active" && { _index > 0 }) then {
                    _entity set ["ignoreWpCallback", (_waypoints select 0) get "name"];
                    (_entity get "group") setCurrentWaypoint [_entity get "group", _index];
                };
            };
            // A priority order may have already reached the suspended destination.
            // Virtual pathfinding must not turn that zero-length trip into a failure.
            private _current = [_entity] call IVCS_VirtualSpace_getEntityCurrentWaypoint;
            if (_pausedAt >= 0 && { !(_entity get "active") } && { !isNil "_current" } &&
                { (_current get "type") == "MOVE" } &&
                { (_entity get "position") distance2D (_current get "position") <= ((_current get "completionRadius") max 7) }) then {
                [_entity get "id", _current get "name"] call IVCS_VirtualSpace_onWaypointCompleted;
            };
            [_entity] call IVCS_EntityTasks_resumeMovement;
            private _activated = _entity get "activeTask";
            private _head = [_entity] call IVCS_VirtualSpace_getCurrentEntityTask;
            if (!isNil "_activated" && { _activated isEqualRef _desired } &&
                { !isNil "_head" && { _head isEqualRef _desired } } &&
                { !((_desired get "status") in ["completed", "failed", "cancelled"]) }) then {
                _context call ((_desired get "template") get "onActivate");
            };
        };
    };
};
_entity set ["taskTransition", false];
