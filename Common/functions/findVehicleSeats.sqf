params ["_vehicleClass"];

private _vehicleConfig = configfile >> "cfgvehicles" >> _vehicleClass;
private _seats = [];

private _hasDriver = getnumber (_vehicleConfig >> "hasdriver") > 0;
if (_hasDriver) then {
    _seats pushback ["Driver", [-1]];
};

private _turretSeats = [_vehicleClass,[]] call bis_fnc_getturrets;

private _cargoCount = getnumber (_vehicleConfig >> "transportsoldier");
private _cargoSeats = [];
for "_t" from 0 to (_cargoCount - 1) do {
    _cargoSeats pushback _t;
};

_seats pushback ["Turrets", _turretSeats];
_seats pushback ["Cargo", _cargoSeats];

_seats