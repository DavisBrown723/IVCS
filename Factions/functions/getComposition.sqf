params ["_faction"];

private _composition = IVCS_Factions_Compositions get _faction;
if (isnil "_composition") then {
    _composition = [_faction] call IVCS_Factions_loadStaticComposition;
};

_composition