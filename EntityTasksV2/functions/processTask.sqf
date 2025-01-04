params ["_entity","_task"];

private _context = _task get "context";
private _currentStatePhase = _task get "currentStatePhase";

if (_currentStatePhase == 0) then {
    private _taskWaypoints = _task get "waypoints";
    [_entity,"waypoints", _taskWaypoints];

    private _onEnter = _task get "onEnter";
    _context call _onEnter;

    _task set ["currentStatePhase", 1];
} else {
    if (_currentStatePhase == 1) then {
        private _onUpdate = _task get "onUpdate";
        private _newStateName = _context call _onUpdate;

        if (!isnil "_newStateName" && { _newStateName != "" }) then {
            _task set ["nextState", IVCS_EntityTasks_TaskTemplates get _newStateName];
            _task set ["currentStatePhase", 2];
        };
    } else {
        private _onLeaving = _task get "onLeaving";
        _context call _onLeaving;

        _task set ["currentState", _task get "nextState"];
        _task set ["nextState", []];
        _task set ["currentStatePhase", 0];

        _entity set ["waypoints", []];
    };
};
