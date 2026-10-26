params ["_helicopter","_target"];
private _area=[_helicopter] call IVCS_Combat_getHelicopterAttackArea;
_area isNotEqualTo [] && {(_helicopter get "position") distance2D (_area select 0)<=(_area select 1)} && {(_target get "position") distance2D (_area select 0)<=(_area select 1)}
