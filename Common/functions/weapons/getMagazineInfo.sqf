params ["_magazineClass"];

private _cachedMagazineInfo = IVCS_Common_MagazineInfo get _magazineClass;
if (!isnil "_cachedMagazineInfo") exitwith { _cachedMagazineInfo };

private _magazineConfig = configfile >> "CfgMagazines" >> _magazineClass;
private _magazineSize = getnumber (_magazineConfig >> "count");
private _magazineAmmo = gettext (_magazineConfig >> "ammo");

private _ammoInfo = [_magazineAmmo] call IVCS_Common_getAmmoInfo;

private _magazineInfo = [_magazineClass, _magazineSize, _magazineAmmo, _ammoInfo];
IVCS_Common_MagazineInfo set [_magazineClass, _magazineInfo];

_magazineInfo