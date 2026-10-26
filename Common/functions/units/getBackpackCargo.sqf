params ["_backpackClass", "_includeItems", "_includeMagazines", "_includeWeapons"];

private _backpackConfig = configFile >> "CfgVehicles" >> _backpackClass;
private _cargo = [[], [], []];

// Keep the flat arrays expected by loadout callers: one entry per cargo unit.
{
    _x params ["_category", "_classProperty", "_include", "_destination"];
    if (_include) then {
        {
            private _class = getText (_x >> _classProperty);
            for "_i" from 1 to getNumber (_x >> "count") do {
                _destination pushBack _class;
            };
        } forEach (configProperties [_backpackConfig >> _category, "isClass _x", true]);
    };
} forEach [
    ["TransportItems", "name", _includeItems, _cargo select 0],
    ["TransportMagazines", "magazine", _includeMagazines, _cargo select 1],
    ["TransportWeapons", "weapon", _includeWeapons, _cargo select 2]
];

_cargo
