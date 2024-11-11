params [["_unitsIdentifier", true]];

if (!canSuspend) exitwith {
    hint "IVCS_Common_findDisposableWeapons needs to be scheduled";
};

private _unitsToCheck = [];
private _baseCheck = "getnumber (_x >> 'scope') >= 2 && {(configname _x) iskindof 'man'}";
switch (typename _unitsIdentifier) do {
    case "BOOL": {
        _unitsToCheck = _baseCheck configClasses (configFile >> "CfgVehicles");
    };
    case "STRING": {
        private _sideNum = [_unitsIdentifier] call IVCS_Common_sideStringToNum;
        _unitsToCheck = (_baseCheck + format [" && {(getnumber (_x >> 'side')) == %1}", _sideNum]) configClasses (configFile >> "CfgVehicles");
    };
    case "ARRAY": {
        _unitsToCheck = (_baseCheck + format ["&& {(configname _x) in %1}", _unitsIdentifier]) configClasses (configFile >> "CfgVehicles");
    };
};

private _unitsToCheckCount = count _unitsToCheck;
private _spawnPos = [0,0,0];
private _transformedWeapons = [];
{
    hintsilent format ["Checking Unit: %1 of %2", _foreachindex + 1, _unitsToCheckCount];
    private _unitClass = configname _x;
    private ["_unit","_unitInitWeapons"];
    isnil {
        _unit = (group player) createUnit [_unitClass, _spawnPos, [], 0, "NONE"];
        _unitInitWeapons = weapons _unit;
        false
    };
    sleep 0.05;

    private _unitPostWeapons = weapons _unit;
    private _changedWeapons = _unitPostWeapons - _unitInitWeapons;

    if !(_changedWeapons isequalto []) then {
        private _transformationPair = _unitInitWeapons - _unitPostWeapons + _changedWeapons;
        _transformedWeapons pushbackunique _transformationPair;
    };

    deletevehicle _unit;
    sleep 0.05;
} foreach _unitsToCheck;

hintSilent "All units checked, data copied to clipboard";

private _stringRet = "";
private _newLine = toString [13,10];

{
    _x params ["_initialWeapon","_postWeapon"];

    _stringRet = _stringRet + (format ["IVCS_Common_WeaponAliases set [""%1"", ""%2""];", _initialWeapon, _postWeapon]) + _newLine;
} foreach _transformedWeapons;

copyToClipboard _stringRet;