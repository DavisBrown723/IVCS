// Read current records; class profiles contain only immutable configuration data.
params ["_unit"];
private _result = [];
(_unit get "weapons") findIf {
    _x params ["_weapon", "_magazines"];
    private _weaponProfile = IVCS_Combat_WeaponProfiles get _weapon;
    if (isNil "_weaponProfile") then { _weaponProfile = [_weapon] call IVCS_Combat_getWeaponProfile; };
    _weaponProfile get "supported" && {
        private _ammoProfile = nil;
        private _index = _magazines findIf {
            (_x select 1) > 0 && {
                _ammoProfile = IVCS_Combat_AmmoProfiles get (_x select 0);
                if (isNil "_ammoProfile") then { _ammoProfile = [_x select 0] call IVCS_Combat_getAmmoProfile; };
                _ammoProfile get "supported"
            }
        };
        if (_index != -1) then { _result = [_magazines select _index, _weaponProfile, _ammoProfile]; };
        _index != -1
    }
};
_result
