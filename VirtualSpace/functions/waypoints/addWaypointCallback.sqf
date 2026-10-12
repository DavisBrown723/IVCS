params ["_waypoint", "_arguments", "_code"];
private _callbacks = _waypoint getOrDefault ["callbacks", [], true];
_callbacks pushBack [_arguments, _code];
