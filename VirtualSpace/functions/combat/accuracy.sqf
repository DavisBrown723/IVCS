params ["_unit","_weapon","_ammo","_range",["_factors",[]]];
if (_factors isEqualTo []) then { _factors = [_weapon,_ammo,_range] call IVCS_Combat_getShotFactors; };
private _armDamage = 0;
private _hitpoints = _unit get "hitpoints";
{ _armDamage = _armDamage max (_hitpoints select _x select 1); } forEach (([_unit] call IVCS_Combat_getHitpointLayout) select 2);
(((_factors select 0) * (1 - 0.65 * _armDamage)) max 0) min 0.8
