if (diag_tickTime - IVCS_Common_OnFrame_LastIteration < 30) exitwith {};

private _allSides = ["EAST","WEST","GUER"];
{
    private _side = _x;
    private _enemySides = [];
    private _friendlySides = _allSides - _enemySides;

    IVCS_Common_SideAllegiances setvariable [_side, [_friendlySides,_enemySides]];
} foreach _allSides;

IVCS_Common_OnFrame_LastIteration = diag_tickTime;