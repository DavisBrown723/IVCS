params ["_vehicleEntity",["_cargoOnly", false]];

private _vehicleSeats = _vehicleEntity getvariable "seats";
private _allEmptySeats = [];
{
    _x params ["_seatType","_seats"];

    if (!_cargoOnly || { _seatType != "Driver" }) then {
        private _emptySeats = [];
        {
            _x params ["_seatPath","_assignedUnit"];

            if (_assignedUnit == "") then {
                _emptySeats pushback _x;
            };
        } foreach _seats;

        _allEmptySeats pushback [_seatType, _emptySeats];
    };
} foreach _vehicleSeats;

_allEmptySeats