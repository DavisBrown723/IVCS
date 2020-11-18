params ["_entity"];

private _units = _entity getvariable "units";

_units select { (_x getvariable "vehicleAssignment") isequalto [] }