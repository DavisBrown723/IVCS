params ["_code","_args","_delay"];

private _executionID = IVCS_Execution_controller get "nextExecutionID";
IVCS_Execution_controller set ["nextExecutionID", _executionID + 1];

private _execution = [_executionID, _code, _args, time + _delay, _delay];

private _waitAndExecuteList = IVCS_Execution_controller get "executeAfterSecondsList";
_waitAndExecuteList pushback _execution;
IVCS_Execution_controller set ["executeAfterSecondsListSorted", false];

private _executionsByID = IVCS_Execution_controller get "executionsByID";
_executionsByID set [_executionID, _execution];

_executionID