if (isGamePaused) exitwith {};



// handle executeAfterSeconds

private _waitAndExecuteList = IVCS_Execution_controller get "executeAfterSecondsList";
private _waitAndExecuteListSorted = IVCS_Execution_controller get "executeAfterSecondsListSorted";

if (!_waitAndExecuteListSorted) then {
    _waitAndExecuteList sort true;
    _waitAndExecuteListSorted = true;
};

private _time = time;
private _keepExecuting = false;

{
    _x params ["_id","_code","_args","_nextExecution","_delay"];

    if (_time < _nextExecution) exitwith {};

    _waitAndExecuteList deleteat 0;

    if (_id >= 0) then {
        _args call _code;

        if (_delay != -1) then {
            _x set [3, _time + _delay];

            _waitAndExecuteList pushback _x;
            _waitAndExecuteListSorted = false;
        };
    };
} foreach _waitAndExecuteList;

IVCS_Execution_controller set ["executeAfterSecondsListSorted", _waitAndExecuteListSorted];



// handle executeAfterFrames

private _frame = IVCS_CurrentFrame;

private _waitAndExecuteFrameList = IVCS_Execution_controller get "executeAfterFramesList";
private _frameExecutions = _waitAndExecuteFrameList deleteat _frame;

if (!isnil "_frameExecutions") then {
    {
        _x params ["_id","_code","_args","_delay"];

        if (_id >= 0) then {
            _args call _code;

            if (_delay > 0) then {
                private _nextFrame = _frame + _delay;
                while { _nextFrame - IVCS_FrameCap > 0 } do {
                    _nextFrame = _nextFrame - IVCS_FrameCap;
                };

                private _nextFrameExecutions = _waitAndExecuteFrameList getOrDefault [_nextFrame, [], true];
                _nextFrameExecutions pushback _x;
            };
        };
    } foreach _frameExecutions;
};



// handle executeOverFrames

private _executeOverFramesList = IVCS_Execution_controller get "executeOverFramesList";
private _currFrameExecutions = _executeOverFramesList deleteat _frame;

if (!isnil "_currFrameExecutions") then {
    {
        _x params ["_id","_framesBetweenExecution","_executionBlocks"];

        if (_id >= 0) then {
            private _executeBlock = _executionBlocks deleteat 0;
            (_executeBlock select 0) call (_executeBlock select 1);

            if (_executionBlocks isnotequalto []) then {
                private _nextFrameToExecute = _frame + _framesBetweenExecution;
                while { _nextFrameToExecute - IVCS_FrameCap > 0 } do {
                    _nextFrameToExecute = _nextFrameToExecute - IVCS_FrameCap;
                };

                private _nextFrameExecutions = _executeOverFramesList getOrDefault [_nextFrameToExecute, [], true];
                _nextFrameExecutions pushback _x;
            };
        };
    } foreach _currFrameExecutions;
};