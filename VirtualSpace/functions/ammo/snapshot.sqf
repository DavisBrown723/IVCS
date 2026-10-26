// Normalized snapshot: [unit profile, primary weapon, carried weapons, magazines].
// Magazine: [class, rounds, loaded, token, native container].
params ["_unit", "_native"];
private _weapons = [];
private _primary = "";
private _magazines = [];
if (_native) then {
    private _object = _unit get "object";
    _primary = primaryWeapon _object;
    _weapons = weapons _object;
    {
        _x params ["_class", "_rounds", "_loaded", "", "_location", "_id"];
        private _container = switch (_location) do {
            case "Uniform": { uniformContainer _object };
            case "Vest": { vestContainer _object };
            case "Backpack": { backpackContainer _object };
            default { objNull };
        };
        _magazines pushBack [_class, _rounds, _loaded, _id, _container];
    } forEach (magazinesAmmoFull [_object, true]);
} else {
    {
        _x params ["_weapon", "_records"];
        private _profile = IVCS_Ammo_WeaponProfiles get _weapon;
        if (isNil "_profile") then { _profile = [_weapon] call IVCS_Ammo_getWeaponProfile; };
        private _type = _profile select 0;
        if (_type in [1,2,4]) then { _weapons pushBack _weapon; };
        if (_primary == "" && { _type == 1 }) then { _primary = _weapon; };
        private _loaded = _records findIf { (_x select 1) > 0 };
        { _magazines pushBack [_x select 0, _x select 1, _forEachIndex == _loaded, [_records, _x], objNull]; } forEach _records;
    } forEach (_unit get "weapons");
    private _cargo = _unit get "magazineCargo";
    { _magazines pushBack [_x select 0, _x select 1, false, [_cargo, _x], objNull]; } forEach _cargo;
};
if (_native) then { _weapons = _weapons select { (([_x] call IVCS_Ammo_getWeaponProfile) select 0) in [1,2,4] }; };
[_unit, _primary, _weapons, _magazines]
