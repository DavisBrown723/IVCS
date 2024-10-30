params ["_entityID"];

private _entities = IVCS_VirtualSpace_Controller get "entities";
private _allEntities = _entities get "ALL";

_allEntities get _entityID;