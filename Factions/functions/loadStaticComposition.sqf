params ["_faction"];

private _compositionFilePath = format ["IVCS\Factions\compositions\%1.sqf", tolower _faction];
private _composition = call compile preprocessFileLineNumbers _compositionFilePath;

[_faction, _composition] call IVCS_Factions_loadComposition;

_composition