params ["_faction"];

private _sideNum = getnumber (configfile >> "CfgFactionClasses" >> _faction >> "side");
[_sideNum] call IVCS_Common_sideNumToString