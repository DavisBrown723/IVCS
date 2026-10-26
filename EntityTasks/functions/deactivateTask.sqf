// Detach runtime movement while retaining unfinished orders for resumption.
params ["_entity", "_task"];
private _context = _task get "context";
private _current = [_entity] call IVCS_VirtualSpace_getEntityCurrentWaypoint;
if (!isNil "_current") then { _task set ["resumeWaypoint", _current get "name"]; };
_entity deleteAt "activeTask";
_entity set ["ignoreWpCallback", ""];
private _hadMovement = (_entity get "waypoints") isNotEqualTo [];
{
    [_entity, _x, true] call IVCS_VirtualSpace_entityRemoveWaypoint;
} forEach ((_entity get "waypoints") select [0]);

// Exclude combat already spent while active; the remaining pause is counted on resume.
if ((_entity get "combatID") != "" && { "startedAt" in _context } && { (_context get "startedAt") >= 0 }) then {
    private _from = (_context get "activatedAt") max (_entity get "combatStartedAt");
    _context set ["startedAt", (_context get "startedAt") + (IVCS_SimulationTime - _from)];
};
_context set ["pausedAt", IVCS_SimulationTime];
_context call ((_task get "template") get "onDeactivate");
if (_hadMovement && { _entity get "active" }) then {
    doStop (units (_entity get "group"));
    _entity set ["movementStopped", true];
};
