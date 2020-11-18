params ["_vehicleEntity","_groupEntity"];

private _groupEntityAssignedVehicles = _groupEntity getvariable "assignedVehicles";
if !(_groupEntityAssignedVehicles isequalto []) exitwith { false };

private _emptySeats = [_vehicleEntity] call IVCS_VirtualSpace_Vehicle_getEmptySeats;

private _groupEntityUnitCount = count (_groupEntity getvariable "units");
private _emptyCargoSeats = [_emptySeats apply {
    if ((_x select 0) != "Driver") then {
        _x select 1
    } else {
        []
    };
}] call IVCS_Common_flattenArray;

count _emptyCargoSeats >= _groupEntityUnitCount