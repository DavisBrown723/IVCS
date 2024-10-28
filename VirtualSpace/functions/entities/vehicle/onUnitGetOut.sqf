params ["_vehicle", "_role", "_unit", "_turret"];

private _unitID = _unit get "unitID";
private _entityID = _unit get "entityID";

private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
private _entityUnit = [_entity, _unitID] call IVCS_VirtualSpace_getEntityUnit;
private _unitVehicleAssignment = _entityUnit get "vehicleAssignment";

if (_unitVehicleAssignment isequalto []) exitwith {};

_unitVehicleAssignment params ["_assignedVehEntityID","_seat"];

private _vehicleEntityID = _vehicle get "entityID";

if (_vehicleEntityID == _assignedVehEntityID && {!((assignedVehicle _unit) isequalto _vehicle)}) then {
    [_entity, _entityUnit] call IVCS_VirtualSpace_onUnitLeaveVehicle;
};