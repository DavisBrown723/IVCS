params ["_unitClass", ["_id",""]];

private _inventory = [_unitClass] call IVCS_Common_getUnitInventoryInfo;
_inventory params ["_templateWeapons", "_templateCargo"];
// Ammo belongs to a unit, never to the cached class template.
private _unitWeapons = _templateWeapons apply {
    [_x select 0, (_x select 1) apply { [_x select 0, _x select 1, +(_x select 2)] }]
};
private _magazineCargo = _templateCargo apply { [_x select 0, _x select 1, +(_x select 2)] };
// Preprocess weapon class metadata outside combat frame work.
{
    [_x select 0] call IVCS_Ammo_getWeaponProfile;
    if !((_x select 0) in IVCS_Combat_WeaponProfiles) then { [_x select 0] call IVCS_Combat_getWeaponProfile; };
    {
        if !((_x select 0) in IVCS_Combat_AmmoProfiles) then { [_x select 0] call IVCS_Combat_getAmmoProfile; };
    } forEach (_x select 1);
} forEach _unitWeapons;
{
    if !((_x select 0) in IVCS_Combat_AmmoProfiles) then { [_x select 0] call IVCS_Combat_getAmmoProfile; };
} forEach _magazineCargo;
{ if !(_x in IVCS_Combat_WeaponProfiles) then { [_x] call IVCS_Combat_getWeaponProfile; }; } forEach ["Throw","Put"];
private _profile = [_unitClass] call IVCS_Combat_getUnitProfile;

private _unit = createHashMapFromArray [
	["id", _id],
	["class", _unitClass],
	["object", objnull],
	["damage", 0],
    ["hitpoints", (keys (_profile get "hitpoints")) apply { [_x, 0] }],
    ["equipment", +(_profile get "equipment")],
    ["fireDelay", 0],
    ["planting",[]],
    ["utilityWeapons",(getArray (configFile >> "CfgVehicles" >> _unitClass >> "weapons")) select { _x in ["Throw","Put"] }],
    ["ammoRetryAt", 0],
	["weapons", _unitWeapons],
    ["magazineCargo", _magazineCargo],
	["vehicleAssignment", []]
];

[_unit] call IVCS_Combat_getHitpointLayout;
_unit
