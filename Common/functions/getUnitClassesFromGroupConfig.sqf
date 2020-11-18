params ["_groupConfig"];

private _groupUnitSubClasses = _groupConfig call BIS_fnc_getCfgSubClasses;
_groupUnitSubClasses apply { getText (_groupConfig  >> _x >> "vehicle") }