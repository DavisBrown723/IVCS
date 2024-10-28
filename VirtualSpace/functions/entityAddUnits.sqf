params ["_entity","_unitsToAdd"];

private _entityUnits = _entity get "units";
private _nextUnitIDNum = _entity get "nextUnitIDNum";

{
    private _unitToAdd = _x;

    private _unitID = format ["u_%1", _nextUnitIDNum];
    _nextUnitIDNum = _nextUnitIDNum + 1;

    _unitToAdd set ["id", _unitID];

    _entityUnits pushback _unitToAdd;
} foreach _unitsToAdd;

_entity set ["nextUnitIDNum", _nextUnitIDNum];