params ["_vehicleEntity"];

private _mannedTurrets = [];

private _seats = _vehicleEntity get "seats";
{
    _x params ["_seatType","_typeSeats"];

    if (_seatType == "turrets") then {
        _mannedTurrets = _typeSeats select { (_x select 1) == "" };
    };
} foreach _seats;

_mannedTurrets