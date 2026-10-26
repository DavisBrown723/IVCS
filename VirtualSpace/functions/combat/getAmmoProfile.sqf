params ["_magazine"];
private _cached = IVCS_Combat_AmmoProfiles get _magazine;
if (!isNil "_cached") exitWith { _cached };
private _magConfig = configFile >> "CfgMagazines" >> _magazine;
private _ammoClass = getText (_magConfig >> "ammo");
private _ammo = configFile >> "CfgAmmo" >> _ammoClass;
private _simulation = toLower getText (_ammo >> "simulation");
private _submunition = getText (_ammo >> "submunitionAmmo");
private _penetratorHit = if (_submunition == "") then { 0 } else { getNumber (configFile >> "CfgAmmo" >> _submunition >> "hit") };
// Zero usage flags use Arma's target-category fallback, shared with the inventory importer.
private _infantry = "infantry" in ([_ammoClass] call IVCS_Common_getAmmoInfo) && {!(isNumber (_ammo >> "allowAgainstInfantry")) || {getNumber (_ammo >> "allowAgainstInfantry")>0}};
private _uses = [_ammoClass] call IVCS_Common_getAmmoInfo;
private _mounted = _simulation in ["shotbullet","shotshell","shotrocket","shotmissile"] && {getNumber (_ammo >> "artilleryLock")==0} && {_uses findIf {_x in ["infantry","vehicles","armor","air"]} != -1};
private _profile = createHashMapFromArray [
    ["airSupported",_mounted && {"air" in _uses || {_simulation=="shotbullet"}}], ["mountedSupported",_mounted], ["groundSupported",_mounted && {getNumber (_ammo >> "airLock")<2}], ["bullet",_simulation=="shotbullet"],
    ["infantrySupported",_infantry && {_simulation in ["shotbullet","shotshell","shotrocket","shotmissile"]} && {getNumber (_ammo >> "artilleryLock")==0} && {getNumber (_ammo >> "airLock")<2}],
    ["vehicleSupported",_simulation in ["shotrocket","shotmissile"]],
    ["airLock",getNumber (_ammo >> "airLock")],
    ["blast",getNumber (_ammo >> "indirectHit")],
    ["blastRadius",getNumber (_ammo >> "indirectHitRange")],
    ["fuseDistance",getNumber (_ammo >> "fuseDistance")],
    ["antiArmor",_penetratorHit > 0 || { getNumber (_ammo >> "caliber") >= 5 } || { getNumber (_ammo >> "indirectHit") >= 500 }],
    ["penetrator",_penetratorHit > 0 || { getNumber (_ammo >> "caliber") >= 5 }],
    ["guided",_simulation == "shotmissile" && { getNumber (_ammo >> "irLock") > 0 || { getNumber (_ammo >> "laserLock") > 0 } }],
    ["vehicleHit",getNumber (_ammo >> "hit") + _penetratorHit],
    ["class", _magazine],
    ["supported", toLower getText (_ammo >> "simulation") == "shotbullet" && { getNumber (_ammo >> "explosive") == 0 }],
    ["hit", getNumber (_ammo >> "hit")],
    ["speed", getNumber (_magConfig >> "initSpeed") max 1],
    ["typicalSpeed", getNumber (_ammo >> "typicalSpeed") max 1],
    ["friction", getNumber (_ammo >> "airFriction") min 0]
];
IVCS_Combat_AmmoProfiles set [_magazine, _profile];
_profile
