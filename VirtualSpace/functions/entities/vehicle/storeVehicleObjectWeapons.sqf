params ["_vehicleEntity"];

private _vehicleObject = _vehicleEntity get "object";
private _magazines = magazinesAllTurrets [_vehicleObject, true];
private _pylonsByName = createHashMap;
{
    _x params ["_index", "_name", "_turret", "_magazine", "_ammo"];
    if (_turret isEqualTo []) then { _turret = [-1]; };
    _pylonsByName set [_name, [_magazine, _ammo, _turret]];

    // Do not restore a pylon magazine a second time as ordinary turret ammo.
    if (_magazine != "") then {
        private _index = _magazines findIf {
            (_x select 0) == _magazine && { (_x select 1) isEqualTo _turret } && { (_x select 2) == _ammo }
        };
        if (_index != -1) then { _magazines deleteAt _index; };
    };
} forEach getAllPylonsInfo _vehicleObject;

private _turretMagazineMap = createHashMap;
{
    _x params ["_magazine", "_turret", "_ammo"];
    (_turretMagazineMap getOrDefault [_turret, [], true]) pushBack [_magazine, _ammo];
} forEach _magazines;

{
    _x params ["_turretPath", "_turretWeapons", "_turretMagazines", "_turretPylons"];
    _turretMagazines resize 0;
    _turretMagazines append (_turretMagazineMap getOrDefault [_turretPath, []]);
    {
        private _saved = _pylonsByName get (_x select 0);
        _x set [1, _saved select 0];
        _x set [2, _saved select 1];
        _x set [3, _saved select 2];
    } forEach _turretPylons;
} forEach (_vehicleEntity get "turrets");

private _pylonsByStation = createHashMap;
{private _records=_x select 3;{(_pylonsByStation getOrDefault [str (_x select 3),[],true]) pushBack _x} forEach _records;_records resize 0} forEach (_vehicleEntity get "turrets");
{(_x select 3) append (_pylonsByStation getOrDefault [str (_x select 0),[]])} forEach (_vehicleEntity get "turrets");
