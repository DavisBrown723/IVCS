params ["_ammo"];

private _cachedAmmoInfo = IVCS_Common_AmmoInfo get _ammo;
if (!isnil "_cachedAmmoInfo") exitwith { _cachedAmmoInfo };

private _ammoConfig = configfile >> "CfgAmmo" >> _ammo;
private _ammoUses = [];

private _ammoUsageFlags = getnumber (_ammoConfig >> "aiAmmoUsageFlags");
if (_ammoUsageFlags != 0) then {
    _ammoUses = (_ammoUsageFlags call BIS_fnc_bitflagsToArray) apply {
        switch (_x) do {
            case 1: { "light" };
            case 2: { "marking" };
            case 4: { "concealment" };
            case 8: { "countermeasures" };
            case 16: { "mine" };
            case 32: { "underwater" };
            case 64: { "infantry" };
            case 128: { "vehicles" };
            case 256: { "air" };
            case 512: { "armor" };
        };
    };
} else {
    private _airLock = getnumber (_ammoConfig >> "airLock");
    switch (_airLock) do {
        case 0: { _ammoUses append ["infantry","vehicles","armor"] };
        case 1: { _ammoUses append ["vehicles","armor","air"] };
        case 2: { _ammoUses pushback "air" };
    };
};

// only let laser lock - capable ammo be used on lasers, etc
// private _irLock = getnumber (_ammoConfig >> "irLock");
// private _laserLock = getnumber (_ammoConfig >> "laserLock");

IVCS_Common_AmmoInfo set [_ammo, _ammoUses];

_ammoUses