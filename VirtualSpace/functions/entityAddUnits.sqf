params ["_entity","_unitsToAdd"];

private _entityUnits = _entity getvariable "units";
private _nextUnitIDNum = _entity getvariable "nextUnitIDNum";

{
    private _unitToAdd = _x;

    private _unitID = format ["u_%1", _nextUnitIDNum];
    _nextUnitIDNum = _nextUnitIDNum + 1;

    _unitToAdd setvariable ["id", _unitID];

    _entityUnits pushback _unitToAdd;
} foreach _unitsToAdd;

_entity setvariable ["nextUnitIDNum", _nextUnitIDNum];