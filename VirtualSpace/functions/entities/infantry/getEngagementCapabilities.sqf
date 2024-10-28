params ["_entity"];

private _capabilities = [];

// private _vehiclesInCommandOf = _entity get "vehiclesInCommandOf";
// {
//     private _vehicleEntity = [_x] call IVCS_VirtualSpace_getEntity;
//     private _vehicleClass = _vehicleEntity get "class";
// } foreach _vehiclesInCommandOf;

private _units = _entity get "units";
{
    private _weapons = _x get "weapons";

    {
        _x params ["_weapon","_magazines"];

        {
            _x params ["_magazine","_magazineAmmoCount","_ammoUses"];

            { _capabilities pushbackunique _x } foreach _ammoUses;
        } foreach _magazines;
    } foreach _weapons;
} foreach _units;

_capabilities