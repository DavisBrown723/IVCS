params ["_entity","_unitID"];

if (_unitID isequaltype locationNull) then {
    _unitID = _unitID get "id";
};

private _entityUnits = _entity get "units";
private _unitToDeleteIndex = _entityUnits findIf {(_x get "id") == _unitID};
private _unit = _entityUnits select _unitToDeleteIndex;

[_entity, _unit] call IVCS_VirtualSpace_onUnitLeaveVehicle;

_entityUnits deleteat _unitToDeleteIndex;

if (_entityUnits isequalto []) then {
    [_entity] call IVCS_VirtualSpace_unregisterEntity;
};