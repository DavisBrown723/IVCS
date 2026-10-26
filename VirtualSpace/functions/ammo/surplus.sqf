// Current-inventory reserve policy for both virtual and native snapshots.
params ["_snapshot"];
_snapshot params ["","","_weapons","_magazines"];
private _protected = [];
{
    private _profile = IVCS_Ammo_WeaponProfiles get _x;
    if (isNil "_profile") then { _profile = [_x] call IVCS_Ammo_getWeaponProfile; };
    private _compatible = _profile select 2;
    private _spare = -1;
    private _rounds = 0;
    {
        // Starting at zero excludes empty magazines without a second rounds test.
        if ((_x select 1) > _rounds && { !(_x select 2) } && {
            _compatible getOrDefault [_x select 0,false]
        }) then { _spare = _forEachIndex; _rounds = _x select 1; };
    } forEach _magazines;
    if (_spare != -1) then { _protected pushBackUnique _spare; };
} forEach _weapons;
private _available = [];
{
    // Loaded magazines are rejected here; no separate protection pass is needed.
    if ((_x select 1) > 0 && { !(_x select 2) } && { !(_forEachIndex in _protected) }) then { _available pushBack _x; };
} forEach _magazines;
_available
