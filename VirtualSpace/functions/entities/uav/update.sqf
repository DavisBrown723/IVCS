params ["_entity", "_deltaTime"];

private _active = _entity get "active";
if (_active) then {
    private _vehicleObject = _entity get "object";

    private _newEntityPos = getpos _vehicleObject;
    [_entity, _newEntityPos] call IVCS_VirtualSpace_setEntityPosition;
};