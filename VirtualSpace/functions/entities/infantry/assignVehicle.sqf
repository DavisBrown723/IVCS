params ["_groupEntity","_vehicleEntity", ["_fullGarrison", true]];

private _vehiclesInCommandOf = _groupEntity get "vehiclesInCommandOf";
private _vehicleEntityID = _vehicleEntity get "id";
if (_vehicleEntityID in (_vehiclesInCommandOf)) exitwith { false };

private _unSeatedUnits = [_groupEntity] call IVCS_VirtualSpace_Infantry_getUnseatedUnits;
private _emptySeats = [_vehicleEntity] call IVCS_VirtualSpace_Vehicle_getEmptySeats;

private _active = (_groupEntity get "active") && (_vehicleEntity get "active");
private _vehicleObject = _vehicleEntity get "object";
private _group = _groupEntity get "group";

private _assignedUnits = [];

scopename "main";
{
    _x params ["_seatType","_seats"];

    {
        if (_unSeatedUnits isequalto []) exitwith {breakTo "main"};

        _x params ["_seatPath","_assignedUnit"];

        private _unitToSeat = _unSeatedUnits deleteat 0;
        private _unitId = _unitToSeat get "id";

        _x set [1, _unitId];
        _unitToSeat set ["vehicleAssignment", [_vehicleEntityID, _x]];

        if (_active) then {
            private _unitObject = _unitToSeat get "object";
            switch (_seatType) do {
                case "Driver": { _unitObject assignAsDriver _vehicleObject };
                case "Turrets": { _unitObject assignAsTurret [_vehicleObject, _seatPath] };
                case "Cargo": { _unitObject assignAsCargoIndex [_vehicleObject, _seatPath] };
            };

            _assignedUnits pushback _unitObject;
        };
    } foreach _seats;
} foreach _emptySeats;

if (_active) then {
    _assignedUnits orderGetIn true;
};

private _groupEntityID = _groupEntity get "id";
_vehicleEntity set ["commandingEntity", _groupEntityID];

_vehiclesInCommandOf pushback _vehicleEntityID;

private _vehicleType = _vehicleEntity get "vehicleType";
_groupEntity set ["vehicleType", _vehicleType];

[_groupEntity] call IVCS_VirtualSpace_Infantry_calculateSpeed;
[_groupEntity] call IVCS_VirtualSpace_Infantry_determinePathfindingStrategy;

[_vehicleEntity] call IVCS_VirtualSpace_Vehicle_updateDebugMarkerColor;