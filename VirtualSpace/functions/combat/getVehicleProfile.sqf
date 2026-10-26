// Config, turret paths, component indices and native calibration are immutable class data.
params ["_class"];
private _profile = IVCS_Combat_VehicleProfiles get _class;
if (!isNil "_profile") exitWith {_profile};
private _config = configFile >> "CfgVehicles" >> _class;
private _armor = getNumber (_config >> "armor") max 1;
private _structural = getNumber (_config >> "armorStructural") max 1;
private _configs = [_config >> "HitPoints",0] call BIS_fnc_returnChildren;
private _personTurrets = createHashMap;
private _weaponPoints = createHashMapFromArray [["[-1]",(_configs apply {toLower configName _x}) select {_x find "gun"!=-1 || {_x find "turret"!=-1}}]];
{
    private _path = _x;
    private _turret = [_class,_path] call BIS_fnc_turretConfig;
    if (getNumber (_turret >> "isPersonTurret") > 0) then {_personTurrets set [str _path,true]};
    private _points = [_turret >> "HitPoints",0] call BIS_fnc_returnChildren;
    _weaponPoints set [str _path,(_points apply {toLower configName _x}) select {_x find "gun"!=-1 || {_x find "turret"!=-1}}];
    _configs append _points;
} forEach ([_class,[]] call BIS_fnc_getTurrets);
private _names = [];
private _indices = createHashMap;
private _hitpoints = createHashMap;
private _engine = []; private _tracks = []; private _wheels = [];
{
    private _name = toLower configName _x;
    if !(_name in _indices) then {
        private _index = count _names;
        _indices set [_name,_index]; _names pushBack configName _x;
        private _resistance = getNumber (_x >> "armor");
        _hitpoints set [_name,if (_resistance < 0) then {-_resistance / _armor} else {_resistance max 0.1}];
        if (_name find "engine" != -1) then {_engine pushBack _index};
        if (_name find "track" != -1) then {_tracks pushBack _index};
        if (_name find "wheel" != -1) then {_wheels pushBack _index};
    };
} forEach _configs;
private _weaponDamage = createHashMap;
{_weaponDamage set [_x,(_y select {_x in _indices}) apply {_indices get _x}]} forEach _weaponPoints;
private _calibration = createHashMap;
private _native = IVCS_Combat_VehicleCalibration get _class;
if (!isNil "_native" && {(_native select 0)==_armor && {(_native select 1)==_structural}}) then {
    {
        _x params ["_magazine","_data"];
        private _ammo = [_magazine] call IVCS_Combat_getAmmoProfile;
        if ((_ammo get "hit") == (_data select 0)) then {
            private _reference = if (_ammo get "supported") then {(((_ammo get "speed") * exp ((_ammo get "friction") * (_data select 1)) / (_ammo get "typicalSpeed")) max 0.2) min 1.5} else {1};
            private _samples = (_data select 2) apply {
                _x params ["_overall","_points"];
                private _indexed = []; private _impact = _overall;
                {
                    private _index = _indices get (_x select 0);
                    if (!isNil "_index") then {_indexed pushBack [_index,_x select 1]; _impact = _impact max ((_x select 1) * 0.25)};
                } forEach _points;
                [_overall,_indexed,_impact]
            };
            _calibration set [_magazine,[_reference,_samples]];
        };
    } forEach (_native select 2);
};
_profile = createHashMapFromArray [
    ["class",_class], ["kind",if (_class isKindOf "Air") then {"air"} else {if (_class isKindOf "Ship") then {"ship"} else {"land"}}],
    ["weaponDamage",_weaponDamage], ["personTurrets",_personTurrets], ["names",_names], ["indices",_indices],
    ["rotors",(_names select {toLower _x find "rotor"!=-1}) apply {_indices get toLower _x}],
    ["mobility",[_engine,_tracks,_wheels]], ["calibration",_calibration],
    ["armor",_armor], ["structural",_structural], ["armored",_class isKindOf "Tank" || {_armor>=100}],
    ["size",getNumber (_config >> "mapSize") max 2], ["hitpoints",_hitpoints]
];
IVCS_Combat_VehicleProfiles set [_class,_profile];
_profile
