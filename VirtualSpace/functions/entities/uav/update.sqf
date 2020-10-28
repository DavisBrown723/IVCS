params ["_entity", "_deltaTime"];

private _active = _entity getvariable "active";
if (_active) then {
    private _vehicleObject = _entity getvariable "object";

    private _newEntityPos = getpos _vehicleObject;
    _entity setvariable ["position", _newEntityPos];
};