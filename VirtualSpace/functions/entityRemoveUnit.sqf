params ["_entity","_unit"];

private _entityUnits = _entity getvariable "units";

if (_unit isequaltype locationNull) then {
    _unit = _unit getvariable "id";
};

private _unitToDeleteIndex = _entityUnits findIf {(_x getvariable "id") == _unit};
(_entityUnits select _unitToDeleteIndex) call CBA_fnc_deleteNamespace;
_entityUnits deleteat _unitToDeleteIndex;

if (_entityUnits isequalto []) then {
    [_entity] call IVCS_VirtualSpace_unregisterEntity;
};