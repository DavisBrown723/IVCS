params ["_unit","_weapon","_ammo","_range","_region","_selection",["_factors",[]]];
private _profile = [_unit get "class"] call IVCS_Combat_getUnitProfile;
private _layout = [_unit] call IVCS_Combat_getHitpointLayout;
private _targets = (_layout select 3) get _region;
if (_targets isEqualTo []) then { _targets = _layout select 4; };
if (_targets isEqualTo []) exitWith {
    // Unsupported custom hitpoint layouts still take overall damage.
    _unit set ["damage",((_unit get "damage") + (_ammo get "hit") / (_profile get "armor")) min 1];
};
private _target = _targets select (floor (_selection * count _targets) min (count _targets - 1));
_target params ["_index","_hitInfo","_name"];
private _protection = ([_unit get "equipment"] call IVCS_Combat_getProtection) getOrDefault [toLower _name,[0,1]];
if (_factors isEqualTo []) then { _factors = [_weapon,_ammo,_range] call IVCS_Combat_getShotFactors; };
private _armor = (_profile get "armor") * (_hitInfo select 0) + (_protection select 0);
private _increment = (_ammo get "hit") * (_factors select 1) / _armor;
private _hitpoint = (_unit get "hitpoints") select _index;
_hitpoint set [1,((_hitpoint select 1) + _increment) min 1];
private _passThrough = (_hitInfo select 1) min (_protection select 1);
private _damage = (_unit get "damage") + _increment * (_passThrough max 0.05) / (_profile get "structural");
if ((_hitInfo select 2) in ["head","torso"] && { (_hitpoint select 1) >= 1 }) then { _damage = 1; };
_unit set ["damage",_damage min 1];
