// Class names return cached templates; objects return fresh inventory snapshots.
// Result: [weapon loadout, magazines not assigned to a carried weapon].
// Each magazine is [class, remaining rounds, ammo uses] and appears once.
params ["_source"];
private _fromConfig = _source isEqualType "";
if (_fromConfig && { _source in IVCS_Common_UnitInfo }) exitWith { IVCS_Common_UnitInfo get _source };

private _weapons = [];
private _magazines = [];
if (_fromConfig) then {
    private _config = configFile >> "CfgVehicles" >> _source;
    _weapons = getArray (_config >> "weapons") - ["Throw", "Put", "Binocular"];
    private _classes = getArray (_config >> "magazines");
    private _cargo = [getText (_config >> "backpack"), false, true, true] call IVCS_Common_getBackpackCargo;
    _classes append (_cargo select 1);
    { _weapons pushBackUnique _x; } forEach (_cargo select 2);
    _magazines = _classes apply { [_x, ([_x] call IVCS_Common_getMagazineInfo) select 1] };
} else {
    _weapons = weapons _source;
    _magazines = magazinesAmmoFull [_source, true];
};
private _loadout = _weapons apply { [_x, []] };
private _compatibleMagazines = _weapons apply { private _info = [_x] call IVCS_Common_getWeaponInfo; _info param [3,_info select 2] };
private _magazineCargo = [];
{
    _x params ["_class", "_rounds"];
    private _record = [_class, _rounds, +(([_class] call IVCS_Common_getMagazineInfo) select 3)];
    private _index = _compatibleMagazines findIf { _class in _x };
    if (_index == -1) then {
        _magazineCargo pushBack _record;
    } else {
        ((_loadout select _index) select 1) pushBack _record;
    };
} forEach _magazines;
private _inventory = [_loadout, _magazineCargo];
if (_fromConfig) then { IVCS_Common_UnitInfo set [_source, _inventory]; };
_inventory
