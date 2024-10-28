params ["_entity"];

private _units = _entity get "units";

_units select { (_x get "vehicleAssignment") isequalto [] }