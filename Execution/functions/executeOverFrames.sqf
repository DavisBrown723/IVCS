params ["_executionBlocks", ["_framesBetweenExecutions", 1], ["_delayExecutionByFrames", 0]];

if (_executionBlocks isequalto [] || { _framesBetweenExecution < 1 }) exitwith {};

private _nextFrameToExecute = IVCS_CurrentFrame + _delayExecutionByFrames;
if (_nextFrameToExecute == IVCS_CurrentFrame) then {
    private _block = _executionBlocks deleteat 0;
    (_block select 0) call (_block select 1);

    _nextFrameToExecute = _nextFrameToExecute + _framesBetweenExecutions;
};

while { _nextFrameToExecute - IVCS_FrameCap > 0 } do {
    _nextFrameToExecute = _nextFrameToExecute - IVCS_FrameCap;
};

private _executionID = IVCS_Execution_controller get "nextExecutionID";
IVCS_Execution_controller set ["nextExecutionID", _executionID + 1];

private _execution = [_executionID, _framesBetweenExecutions, _executionBlocks];

private _executeOverFramesList = IVCS_Execution_controller get "executeOverFramesList";
private _nextFrameToExecuteCodeBlocks = _executeOverFramesList getOrDefault [_nextFrameToExecute, [], true];
_nextFrameToExecuteCodeBlocks pushback _execution;

private _executionsByID = IVCS_Execution_controller get "executionsByID";
_executionsByID set [_executionID, _execution];

_executionID