params ["_waypoint","_callbackArguments","_callbackCode"];

private _statements = _waypoint get "statements";
_statements pushback [_callbackArguments,_callbackCode];