params ["_entity","_task"];

private _timeLastProcess = _task get "timeLastProcessed";
if (time - _timeLastProcess > 1) then {
    private _arguments = _task get "arguments";
    private _currentStatePhase = _task get "currentStatePhase";

    if (_currentStatePhase == 0) then {
        private _onEnter = _task get "onEnter";
        _arguments call _onEnter;

        _task set ["currentStatePhase", 1];
    } else {
        if (_currentStatePhase == 1) then {
            private _onUpdate = _task get "onUpdate";
            private _newStateName = _arguments call _onUpdate;

            if (!isnil "_newStateName" && { _newStateName != "" }) then {
                _task set ["nextState", IVCS_EntityTasks_TaskTemplates get _newStateName];
                _task set ["currentStatePhase", 2];
            };
        } else {
            private _onLeaving = _task get "onLeaving";
            _arguments call _onLeaving;

            _task set ["currentState", _task get "nextState"];
            _task set ["nextState", []];
            _task set ["currentStatePhase", 0];
        };
    };
};






private _tasks = _entity get "tasks";

private _timeLastProcess = _task get "timeLastProcess";
if (time - _timeLastProcess > 1) then {
    private _taskStateData = _task get "data";
    private _taskState = _task get "currentState";

    _taskState params ["_initFunc","_isEndState","_isRepeatable","_hasExecuted","_outgoingConditions"];

    if (!_hasExecuted) then {
        _taskStateData call _initFunc;

        if (_isEndState) then {
            private _callback = _task get "callback";
            private _callbackArgs = _task get "callbackArgs";
            ([_task] + _callbackArgs) call _callback;
            
            _tasks deleteat 0;
        } else {
            _taskState set [3, true];
        };
    } else {
        {
            _x params ["_conditionFunc","_onChosenFunc","_nextState"];

            if (_taskStateData call _conditionFunc) exitwith {
                _taskStateData call _onChosenFunc;
                _task set ["currentState", _nextState];
            };
        } foreach _outgoingConditions;
        if (_isRepeatable) then {
            _taskState set [1, false];
        };
    };

    _task set ["timeLastProcess", time];
};