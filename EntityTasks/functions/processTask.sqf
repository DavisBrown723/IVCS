params ["_entity","_task"];

private _tasks = _entity getvariable "tasks";

private _timeLastProcess = _task getvariable "timeLastProcess";
if (time - _timeLastProcess > 1) then {
    private _taskStateData = _task getvariable "data";
    private _taskState = _task getvariable "currentState";

    _taskState params ["_initFunc","_isEndState","_isRepeatable","_hasExecuted","_outgoingConditions"];

    if (!_hasExecuted) then {
        _taskStateData call _initFunc;

        if (_isEndState) then {
            private _callback = _task getvariable "callback";
            private _callbackArgs = _task getvariable "callbackArgs";
            ([_task] + _callbackArgs) call _callback;
            
            [_task] call IVCS_EntityTasks_deleteTask;
            _tasks deleteat 0;
        } else {
            _taskState set [3, true];
        };
    } else {
        {
            _x params ["_conditionFunc","_onChosenFunc","_nextState"];

            if (_taskStateData call _conditionFunc) exitwith {
                _taskStateData call _onChosenFunc;
                _task setvariable ["currentState", _nextState];
            };
        } foreach _outgoingConditions;
        if (_isRepeatable) then {
            _taskState set [1, false];
        };
    };

    _task setvariable ["timeLastProcess", time];
};