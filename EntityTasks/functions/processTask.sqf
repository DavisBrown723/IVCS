params ["_entity"];

private _tasks = _entity getvariable "tasks";
if (count _tasks > 0) then {

    private _currTask = _tasks select 0;
    private _currTaskStateData = _currTask getvariable "data";
    private _currTaskState = _currTask getvariable "currentState";

    _currTaskState params ["_initFunc","_isEndState","_isRepeatable","_hasExecuted","_outgoingConditions"];

    if (!_hasExecuted) then {
        _currTaskStateData call _initFunc;

        if (_isEndState) then {
            [_currTask] call IVCS_EntityTasks_deleteTask;
            _tasks deleteat 0;
        } else {
            _currTaskState set [3, true];
        };
    } else {
        {
            _x params ["_conditionFunc","_onChosenFunc","_nextState"];

            if (_currTaskStateData call _conditionFunc) exitwith {
                _currTaskStateData call _onChosenFunc;
                _currTask setvariable ["currentState", _nextState];
            };
        } foreach _outgoingConditions;
        if (_isRepeatable) then {
            _currTaskState set [1, false];
        };
    };
};