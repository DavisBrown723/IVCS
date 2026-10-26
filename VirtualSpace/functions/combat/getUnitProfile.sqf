params ["_class"];
private _cached = IVCS_Combat_UnitProfiles get _class;
if (!isNil "_cached") exitWith { _cached };
private _config = configFile >> "CfgVehicles" >> _class;
private _regions = createHashMapFromArray [["head", []], ["torso", []], ["arms", []], ["legs", []]];
private _hitpoints = createHashMap;
{
    private _name = toLower configName _x;
    private _lower = _name;
    private _region = switch (true) do {
        case (_lower find "head" >= 0 || { _lower find "face" >= 0 } || { _lower find "neck" >= 0 }): { "head" };
        case (_lower find "arm" >= 0 || { _lower find "hand" >= 0 }): { "arms" };
        case (_lower find "leg" >= 0): { "legs" };
        default { "torso" };
    };
    _hitpoints set [_name, [getNumber (_x >> "armor") max 0.1, getNumber (_x >> "passThrough"), _region, getText (_x >> "depends")]];
    // Head and hands have dependencies but are physical, protected regions.
    // Only broad engine aggregates are excluded from anatomical selection.
    if (!(_name in ["hitbody", "incapacitated"]) || { getText (_x >> "depends") in ["", "0"] }) then {
        (_regions get _region) pushBack _name;
    };
} forEach (configProperties [_config >> "HitPoints", "isClass _x", true]);
private _linked = getArray (_config >> "linkedItems");
private _vest = "";
private _helmet = "";
{
    switch (getNumber (configFile >> "CfgWeapons" >> _x >> "ItemInfo" >> "type")) do {
        case 701: { _vest = _x; };
        case 605: { _helmet = _x; };
    };
} forEach _linked;
private _profile = createHashMapFromArray [
    ["armor", getNumber (_config >> "armor") max 1],
    ["structural", getNumber (_config >> "armorStructural") max 0.1],
    ["hitpoints", _hitpoints], ["regions", _regions], ["targets", (_regions get "head") + (_regions get "torso") + (_regions get "arms") + (_regions get "legs")], ["equipment", [_vest, _helmet]]
];
IVCS_Combat_UnitProfiles set [_class, _profile];
_profile
