params ["_executionID"];

private _executionsByID = IVCS_Execution_controller get "executionsByID";
private _execution = _executionsByID deleteat _executionID;

if (!isnil "_execution") then {
    _execution set [0, -1];
};