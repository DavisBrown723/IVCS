params ["_entity","_entityUnit"];

private _vehicleAssignment = _entityUnit get "vehicleAssignment";
_vehicleAssignment params ["_vehicleID","_seat"];

_seat set [0, ""];
_entityUnit set ["vehicleAssignment", []];

// perhaps we could shuffle unit assignments
// so we don't drop vehicle assignments
// this way vehicle assignments must be explicity dropped
// and we avoid loose vehicles

private _vehicleEntity = [_vehicleID] call IVCS_VirtualSpace_getEntity;
private _remainingAssignedUnits = [_entity,_vehicleEntity] call IVCS_VirtualSpace_countUnitsAssignedToVehicle;
if (_remainingAssignedUnits == 0) then {
    private _assignmentType = [_entity, _vehicleEntity] call IVCS_VirtualSpace_Group_getVehicleAssignmentType;
    if (_assignmentType == "command") then {
        [_entity,_vehicleEntity] call IVCS_VirtualSpace_Group_unassignVehicle;
    } else {
        [_entity,_vehicleEntity] call IVCS_VirtualSpace_Group_unassignAsVehicleCargo;
    };
};