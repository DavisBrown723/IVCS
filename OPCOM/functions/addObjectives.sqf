params ["_opcom","_newObjectives"];

private _objectives = _opcom getvariable "objectives";
private _nextObjectiveID = _opcom getvariable "nextObjectiveID";
private _debug = _opcom getvariable "debug";

{
    private _objectiveID = format ["obj_%1", _nextObjectiveID];
    _nextObjectiveID = _nextObjectiveID + 1;

    private _objective = [_x] call IVCS_OPCOM_createObjectiveFromLocation;
    _objective setvariable ["id", _objectiveID];

    _objectives setvariable [_objectiveID, _objective];

    if (_debug) then {
        private _opcomName = _opcom getvariable "name";
        private _debugMarkerName = format ["%1_%2", _opcomName, _objectiveID];
        private _objectivePosition = _objective getvariable "position";
        private _objectiveSize = _objective getvariable "size";

        private _debugMarker = createMarker [_debugMarkerName, _objectivePosition];
        _debugMarker setmarkershape "ellipse";
        _debugMarker setmarkersize [_objectiveSize,_objectiveSize];
        _debugMarker setmarkeralpha 0.55;
        _objective setvariable ["debugMarker", _debugMarker];
    };
} foreach _newObjectives;

_opcom setvariable ["nextObjectiveID", _nextObjectiveID];