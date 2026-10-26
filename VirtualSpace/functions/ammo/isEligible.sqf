params ["_unit","_native"];
(_unit get "damage") < 1 && { !_native || {
    private _object = _unit get "object";
    alive _object && { local _object } && { !isPlayer _object } && { vehicle _object == _object } && { lifeState _object != "INCAPACITATED" }
} }
