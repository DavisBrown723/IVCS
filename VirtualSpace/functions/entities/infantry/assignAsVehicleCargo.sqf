params ["_groupEntity","_vehicleEntity", ["_fullGarrison", true]];

private _vehiclesInCargoOf = _groupEntity getvariable "vehiclesInCargoOf";
private _vehicleEntityID = _vehicleEntity getvariable "id";
if (_vehicleEntityID in (_vehiclesInCargoOf)) exitwith { false };

private _unSeatedUnits = [_groupEntity] call IVCS_VirtualSpace_Infantry_getUnseatedUnits;
private _emptyCargoSeats = [_vehicleEntity, true] call IVCS_VirtualSpace_Vehicle_getEmptySeats;

private _active = (_groupEntity getvariable "active") && (_vehicleEntity getvariable "active");
private _vehicleObject = _vehicleEntity getvariable "object";
private _group = _groupEntity getvariable "group";

private _assignedUnits = [];

scopename "main";
{
    _x params ["_seatType","_seats"];

    {
        if (_unSeatedUnits isequalto []) exitwith {breakTo "main"};

        _x params ["_seatPath","_assignedUnit"];

        private _unitToSeat = _unSeatedUnits deleteat 0;
        private _unitId = _unitToSeat getvariable "id";

        _x set [1, _unitId];
        _unitToSeat setvariable ["vehicleAssignment", [_vehicleEntityID, _x]];

        if (_active) then {
            private _unitObject = _unitToSeat getvariable "object";
            switch (_seatType) do {
                case "Turrets": { _unitObject assignAsTurret [_vehicleObject, _seatPath] };
                case "Cargo": { _unitObject assignAsCargoIndex [_vehicleObject, _seatPath] };
            };

            _assignedUnits pushback _unitObject;
        };
    } foreach _seats;
} foreach _emptyCargoSeats;

if (_active) then {
    _assignedUnits orderGetIn true;
};

private _groupEntityID = _groupEntity getvariable "id";
private _vehicleEntitiesInCargo = _vehicleEntity getvariable "entitiesInCargo";
_vehicleEntitiesInCargo pushback _groupEntityID;

_vehiclesInCargoOf pushback _vehicleEntityID;

private _vehicleEntityPosition = _vehicleEntity getvariable "position";
[_groupEntity,_vehicleEntityPosition] call IVCS_VirtualSpace_setEntityPosition;

[_vehicleEntity] call IVCS_VirtualSpace_Vehicle_updateDebugMarkerColor;