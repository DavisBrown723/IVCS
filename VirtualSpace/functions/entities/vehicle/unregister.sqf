params ["_entity"];
((IVCS_VirtualSpace_Controller get "combat") get "helicopters") deleteAt (_entity get "id");
[_entity] call IVCS_Combat_onRemoved;

private _commandingEntity = [_entity get "commandingEntity"] call IVCS_VirtualSpace_getEntity;
if (!isNil "_commandingEntity") then {
    [_commandingEntity, _entity] call IVCS_VirtualSpace_Group_unassignVehicle;
};
{
    private _cargoEntity = [_x] call IVCS_VirtualSpace_getEntity;
    if (!isNil "_cargoEntity") then {
        [_cargoEntity, _entity] call IVCS_VirtualSpace_Group_unassignAsVehicleCargo;
    };
} forEach +(_entity get "entitiesInCargo");

deleteMarker (_entity get "debugMarker");
