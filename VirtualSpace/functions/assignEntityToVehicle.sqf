params ["_entity","_vehicle"];

private _vehicleAssignedEntity = _vehicle getvariable "assignedEntity";
if (_vehicleAssignedEntity != "") exitwith {
    false
};

private _vehicleSeats = _vehicle getvariable "seats";
private _vehicleSeatCount = _vehicle getvariable "seatCount";
private _entityUnits = _entity getvariable "units";

if (count _entityUnits > _vehicleSeatCount) exitwith {
    false
};

// assign units to empty seats

scopename "main";
private _vehicleID = _vehicle getvariable "id";
private _unitsLeftToAssign = _entityUnits select {(_x getvariable "vehicleAssignment") isequalto []};
{
    params ["_seatType","_seats"];

    {
        if (_unitsLeftToAssign isequalto []) exitwith {breakTo "main"};

        params ["_seatPath","_assignedUnit"];

        if (_assignedUnit == "") then {
            private _unit = _unitsLeftToAssign deleteat 0;
            private _unitID = _unit getvariable "id";
            
            _x set [0, _unitID];
            _unit setvariable ["vehicleAssignment", [_vehicleID, _x]];
        };
    } foreach _seats;
} foreach _vehicleSeats;

private _assignedVehicles = _entity getvariable "assignedVehicles";
_assignedVehicles pushback _vehicleID;

_vehicle setvariable ["assignedEntity", _entity getvariable "id"];

private _vehicleDebugMarker = _vehicle getvariable "debugMarker";
if (_vehicleDebugMarker != "") then {
    private _entitySide = _entity getvariable "side";
    private _entitySideColor = [_entitySide] call IVCS_Common_sideStringToColor;
    _vehicleDebugMarker setMarkerColor _entitySideColor;
};

true