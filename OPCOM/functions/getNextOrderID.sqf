params ["_opcom"];

private _idNum = _opcom getvariable "nextOrderIDNum";
_opcom setvariable ["nextOrderIDNum", _idNum + 1];

format ["order_%1", _idNum];