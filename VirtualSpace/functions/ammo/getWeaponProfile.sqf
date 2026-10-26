// Shared immutable class data. Magazine contents remain owned by each unit.
params ["_class"];
private _profile = IVCS_Ammo_WeaponProfiles get _class;
if (!isNil "_profile") exitWith { _profile };
private _info = [_class] call IVCS_Common_getWeaponInfo;
private _type = getNumber (configFile >> "CfgWeapons" >> (_info select 0) >> "type");
private _compatible = _info select 2;
_profile = [_type, _compatible, createHashMapFromArray (_compatible apply { [_x, true] })];
IVCS_Ammo_WeaponProfiles set [_class, _profile];
_profile
