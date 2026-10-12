params ["_code","_args","_delay"];

if (_delay < 1) exitwith { _args call _code };

private _desiredFrame = IVCS_CurrentFrame + _delay;
while { _desiredFrame - IVCS_FrameCap > 0 } do {
    _desiredFrame = _desiredFrame - IVCS_FrameCap;
};

private _executionID = IVCS_Execution_controller get "nextExecutionID";
IVCS_Execution_controller set ["nextExecutionID", _executionID + 1];

private _execution = [_executionID, _code, _args, _delay];

private _waitAndExecuteList = IVCS_Execution_controller get "executeAfterFramesList";
private _frameExecutions = _waitAndExecuteList getOrDefault [_desiredFrame, [], true];
_frameExecutions pushback _execution;

private _executionsByID = IVCS_Execution_controller get "executionsByID";
_executionsByID set [_executionID, _execution];

_executionID