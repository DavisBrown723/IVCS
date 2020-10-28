params ["_unit", "_killer", "_instigator", "_useEffects"];

private _entityID = _unit getvariable "entityID";
private _unitID = _unit getvariable "unitID";

private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
private _entityUnit = [_entity,_unitID] call IVCS_VirtualSpace_getEntityUnit;

private _vehicleAssignment = _entityUnit getvariable "vehicleAssignment";
if !(_vehicleAssignment isequalto []) then {
    _vehicleAssignment params ["_vehicleID","_seat"];

    _seat set [0, ""];
    _entityUnit setvariable ["vehicleAssignment", []];

    // perhaps we could shuffle unit assignments
    // so we don't drop vehicle assignments
    // this way vehicle assignments must be explicity dropped
    // and we avoid loose vehicles

    private _vehicleEntity = [_vehicleID] call IVCS_VirtualSpace_getEntity;
    private _remainingAssignedUnits = [_entity,_vehicleEntity] call IVCS_VirtualSpace_countUnitsAssignedToVehicle;
    if (_remainingAssignedUnits == 0) then {
        [_entity,_vehicleEntity] call IVCS_VirtualSpace_unassignEntityFromVehicle;
    };
};

[_entity, _unitID] call IVCS_VirtualSpace_entityRemoveUnit;