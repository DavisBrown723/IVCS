params ["_entity","_vehicleEntity"];

private _entityID = _entity getvariable "id";
private _vehicleCommandingEntity = _vehicleEntity getvariable "commandingEntity";

if (_entityID == _vehicleCommandingEntity) exitwith {
    "command"
};

private _vehicleCargoEntities = _vehicleEntity getvariable "entitiesInCargo";
if (_entityID in _vehicleCargoEntities) exitwith {
    "cargo"
};

"none"