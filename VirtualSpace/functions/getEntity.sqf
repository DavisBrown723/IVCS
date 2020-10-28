params ["_entityID"];

private _entities = IVCS_VirtualSpace_Controller getvariable "entities";
private _allEntities = _entities getvariable "all";

_allEntities getvariable _entityID;