params ["_entity","_unitID"];

private _units = _entity getvariable "units";
private _unitIndex = _units findif {(_x getvariable "id") == _unitID};

if (_unitIndex != -1) then {
    _units select _unitIndex
};