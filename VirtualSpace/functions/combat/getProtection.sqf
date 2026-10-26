params ["_equipment"];
private _key = str _equipment;
private _cached = IVCS_Combat_ProtectionProfiles get _key;
if (!isNil "_cached") exitWith { _cached };
private _protection = createHashMap;
{
    private _item = configFile >> "CfgWeapons" >> _x >> "ItemInfo";
    private _entries = configProperties [_item >> "HitpointsProtectionInfo", "isClass _x", true];
    if (_entries isEqualTo [] && { getText (_item >> "hitPointName") != "" }) then { _entries = [_item]; };
    {
        private _name = toLower getText (_x >> "hitPointName");
        private _old = _protection getOrDefault [_name, [0, 1]];
        _protection set [_name, [(_old select 0) + getNumber (_x >> "armor"), (_old select 1) min getNumber (_x >> "passThrough")]];
    } forEach _entries;
} forEach _equipment;
IVCS_Combat_ProtectionProfiles set [_key, _protection];
_protection
