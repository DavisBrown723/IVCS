params ["_entity","_unitID"];

private _units = _entity get "units";
private _unitIndex = _units findif {(_x get "id") == _unitID};

if (_unitIndex != -1) then {
    _units select _unitIndex
};