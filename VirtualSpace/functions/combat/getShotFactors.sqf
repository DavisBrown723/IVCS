// Exact range-dependent factors shared by shooters and hits with the same profiles.
params ["_weapon","_ammo","_range"];
private _speed = [_weapon,_ammo,_range] call IVCS_Combat_getImpactSpeed;
private _spread = (_weapon get "dispersion") * _range;
private _probability = ((IVCS_VirtualSpace_Controller get "combat") get "accuracyScale") / (1 + (_range / 100)^2 + (_spread / 0.35)^2);
[_probability * (sqrt (_speed / 900) min 1.2),((_speed / (_ammo get "typicalSpeed")) max 0.2) min 1.5]
