// Traverse transport links once at engagement creation, not on every combat tick.
params ["_entities"];
private _result = _entities select [0];
private _seen = createHashMapFromArray (_result apply { [_x get "id", true] });
private _index = 0;
while { _index < count _result } do {
    private _entity = _result select _index;
    private _links = if ((_entity get "entityType") == "group") then {
        (_entity get "vehiclesInCommandOf") + (_entity get "vehiclesInCargoOf")
    } else { [_entity get "commandingEntity"] + (_entity get "entitiesInCargo") };
    {
        if (_x != "" && { !(_x in _seen) }) then {
            private _linked = [_x] call IVCS_VirtualSpace_getEntity;
            if (!isNil "_linked") then { _seen set [_x,true]; _result pushBack _linked; };
        };
    } forEach _links;
    _index = _index + 1;
};
_result
