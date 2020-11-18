params ["_entity","_unitID"];

if (_unitID isequaltype locationNull) then {
    _unitID = _unitID getvariable "id";
};

private _entityUnits = _entity getvariable "units";
private _unitToDeleteIndex = _entityUnits findIf {(_x getvariable "id") == _unitID};
private _unit = _entityUnits select _unitToDeleteIndex;

[_entity, _unit] call IVCS_VirtualSpace_onUnitLeaveVehicle;

(_entityUnits select _unitToDeleteIndex) call CBA_fnc_deleteNamespace;
_entityUnits deleteat _unitToDeleteIndex;

if (_entityUnits isequalto []) then {
    [_entity] call IVCS_VirtualSpace_unregisterEntity;
};