params ["_opcom","_entities","_setActive",["_currentOrderID", "none"]];

private ["_typeFrom","_typeTo"];
if (_setActive) then {
    _typeFrom = _opcom getvariable "idleEntities";
    _typeTo = _opcom getvariable "activeEntities";
} else {
    _typeFrom = _opcom getvariable "activeEntities";
    _typeTo = _opcom getvariable "idleEntities";
};

private _entityInfoMap = _opcom getvariable "entityInfoMap";
{
    private _id = _x;
    private _entity = [_id] call IVCS_VirtualSpace_getEntity;
    if (!isnil "_entity") then {
        private _entityInfo = _entityInfoMap getvariable _id;

        _entityInfo set [0, _setActive];
        if (_currentOrderID != "none") then {
            _entityInfo set [2, _currentOrderID];
        };

        private _vehicleType = _entityInfo select 1;
        private _typeFromArray = _typeFrom getvariable _vehicleType;
        _typeFromArray deleteat (_typeFromArray find _id);

        private _typeToArray = _typeTo getvariable _vehicleType;
        _typeToArray pushback _id;
    };
} foreach _entities;