params ["_entity","_task"];

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