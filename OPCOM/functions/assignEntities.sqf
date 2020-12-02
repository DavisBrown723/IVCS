params ["_opcom","_entities"];

private _allEntities = _opcom getvariable "allEntities";
private _entityUsageMap = _opcom getvariable "entityInfoMap";

{
    private _id = _x getvariable "id";
    private _entityType = _x getvariable "entityType";
    if (_entityType == "group") then {
        _allEntities pushback _id;
        _entityUsageMap setvariable [_id, [true,"",""]]; // isActive, vehicleType, currentOrderID
    };
} foreach _entities;