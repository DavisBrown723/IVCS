params ["_unit", "_killer", "_instigator", "_useEffects"];

private _entityID = _unit getvariable "entityID";
private _unitID = _unit getvariable "unitID";

private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;

[_entity, _unitID] call IVCS_VirtualSpace_entityRemoveUnit;