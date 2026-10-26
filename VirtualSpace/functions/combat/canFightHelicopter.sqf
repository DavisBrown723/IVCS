params ["_target","_helicopter"];
private _incoming=[_target,_helicopter] call IVCS_Combat_canShootHelicopter;
if (_incoming) exitWith {true};
private _policy = [_helicopter] call IVCS_Combat_getHelicopterPolicy;
if !(_policy select 2) exitWith {false};
[_target,_helicopter,true] call IVCS_Combat_canHelicopterFire
