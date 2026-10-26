// Validate a single reservation against current inventory without building all surplus.
// Loaded magazines and the first fullest spare for each weapon remain protected.
params ["_snapshot","_token"];
_snapshot params ["","","_weapons","_magazines"];
private _index = _magazines findIf { [_x select 3,_token] call IVCS_Ammo_sameToken };
if (_index == -1) exitWith { [] };
private _magazine = _magazines select _index;
_magazine params ["_class","_rounds","_loaded","_currentToken"];
if (_rounds <= 0 || { _loaded }) exitWith { [] };
// Virtual reservations name their source as well as their record. A moved record
// must not authorize removal from the old source array at collection.
if (!(_token isEqualType 0) && { !((_currentToken select 0) isEqualRef (_token select 0)) }) exitWith { [] };
private _protected = _weapons findIf {
    private _compatible = ([_x] call IVCS_Ammo_getWeaponProfile) select 2;
    _compatible getOrDefault [_class,false] && {
        // A better spare (or an earlier equally full one) protects this weapon.
        // Otherwise the reserved magazine itself is its required last reserve.
        private _better = false;
        {
            if (!(_x select 2) && {
                (_x select 1) > _rounds || { (_x select 1) == _rounds && { _forEachIndex < _index } }
            } && { _compatible getOrDefault [_x select 0,false] }) exitWith { _better = true; };
        } forEach _magazines;
        !_better
    }
} != -1;
if (_protected) then { [] } else { _magazine }
