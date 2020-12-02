if (diag_tickTime - IVCS_Common_OnFrame_LastIteration < 30) exitwith {};

private _allSides = ["EAST","WEST","GUER"] apply { [_x, _x call IVCS_Common_sideStringToObject]};
{
    _x params ["_sideStr","_sideObj"];
    private _otherSides = _allsides - [_x];
    private _enemySides = _otherSides select { _sideObj getfriend (_x select 1) < 0.6};
    private _friendlySides = _otherSides - _enemySides;

    IVCS_Common_SideAllegiances setvariable [_sideStr, [_friendlySides apply {_x select 0},_enemySides apply {_x select 0}]];
} foreach _allSides;

IVCS_Common_OnFrame_LastIteration = diag_tickTime;