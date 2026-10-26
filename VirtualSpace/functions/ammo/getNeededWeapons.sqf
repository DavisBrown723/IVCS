// Virtual inventory fast path: inspect current rounds without allocating snapshots.
params ["_unit",["_native",false]];
if (_native) exitWith {
    private _snapshot = [_unit,true] call IVCS_Ammo_snapshot;
    _snapshot params ["","_primary","_weapons","_magazines"];
    private _wanted = _weapons select {
        private _profile = IVCS_Ammo_WeaponProfiles get _x;
        if (isNil "_profile") then { _profile = [_x] call IVCS_Ammo_getWeaponProfile; };
        private _compatible = _profile select 2;
        (_profile select 0) in [1,2,4] && { _magazines findIf { (_x select 1) > 0 && { _compatible getOrDefault [_x select 0,false] } } == -1 }
    };
    if (_primary in _wanted) then { _wanted = [_primary] + (_wanted - [_primary]); };
    _wanted
};
private _weapons = _unit get "weapons";
private _wanted = [];
private _primary = "";
{
    _x params ["_weapon", "_records"];
    // Class metadata is prewarmed when units are imported. Gear edits can add
    // a new class, so only a cache miss needs the profile-building adapter.
    private _profile = IVCS_Ammo_WeaponProfiles get _weapon;
    if (isNil "_profile") then { _profile = [_weapon] call IVCS_Ammo_getWeaponProfile; };
    private _type = _profile select 0;
    if (_type == 1 && { _primary == "" }) then { _primary = _weapon; };
    if (_type in [1,2,4]) then {
        private _compatible = _profile select 2;
        private _hasAmmo = _records findIf {
            (_x select 1) > 0 && { _compatible getOrDefault [_x select 0, false] }
        } != -1;
        if (!_hasAmmo) then {
            // The same policy counts compatible ammunition in cargo or another weapon.
            _hasAmmo = (_unit get "magazineCargo") findIf {
                (_x select 1) > 0 && { _compatible getOrDefault [_x select 0, false] }
            } != -1 || {
                _weapons findIf {
                    !((_x select 1) isEqualRef _records) && {
                        (_x select 1) findIf {
                            (_x select 1) > 0 && { _compatible getOrDefault [_x select 0, false] }
                        } != -1
                    }
                } != -1
            };
        };
        if (!_hasAmmo) then {
            if (_weapon == _primary) then {
                // Prioritize and deduplicate only the primary, as the former final pass did.
                if !(_weapon in _wanted) then { _wanted insert [0,[_weapon]]; };
            } else { _wanted pushBack _weapon; };
        };
    };
} forEach _weapons;
_wanted
