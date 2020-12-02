params ["_opcomName","_entity"];

private _opcom = [_opcomName] call IVCS_OPCOM_getByName;

private _entityID = _entity getvariable "id";

private _entityInfoMap = _opcom getvariable "entityInfoMap";
private _entityInfo = _entityInfoMap getvariable _entityID;

private _allEntities = _opcom getvariable "allEntities";
_allEntities deleteat (_allEntities find _entityID);

_entityInfo params ["_isIdle","_vehicleType"];

if (_isIdle) then {
    private _idleEntities = _opcom getvariable "idleEntities";
    private _idleEntitiesOfType = _idleEntities getvariable _vehicleType;
    _idleEntitiesOfType deleteat (_idleEntitiesOfType find _entityID);
} else {
    private _activeEntities = _opcom getvariable "activeEntities";
    private _activeEntitiesOfType = _activeEntities getvariable _vehicleType;
    _activeEntitiesOfType deleteat (_activeEntitiesOfType find _entityID);
};