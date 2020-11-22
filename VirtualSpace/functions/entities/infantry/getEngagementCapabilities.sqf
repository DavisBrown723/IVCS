params ["_entity"];

private _capabilities = [];

// private _vehiclesInCommandOf = _entity getvariable "vehiclesInCommandOf";
// {
//     private _vehicleEntity = [_x] call IVCS_VirtualSpace_getEntity;
//     private _vehicleClass = _vehicleEntity getvariable "class";
// } foreach _vehiclesInCommandOf;

private _units = _entity getvariable "units";
{
    private _weapons = _x getvariable "weapons";

    {
        _x params ["_weapon","_magazines"];

        {
            _x params ["_magazine","_magazineAmmoCount","_ammoUses"];

            { _capabilities pushbackunique _x } foreach _ammoUses;
        } foreach _magazines;
    } foreach _weapons;
} foreach _units;

_capabilities