params ["_entity","_vehicleEntity"];

private _entityID = _entity get "id";
private _vehicleCommandingEntity = _vehicleEntity get "commandingEntity";

if (_entityID == _vehicleCommandingEntity) exitwith {
    "command"
};

private _vehicleCargoEntities = _vehicleEntity get "entitiesInCargo";
if (_entityID in _vehicleCargoEntities) exitwith {
    "cargo"
};

"none"