params ["_weapon", "_ammo", "_range"];
private _speed = _ammo get "speed";
private _override = _weapon get "initSpeed";
if (_override > 0) then { _speed = _override; };
if (_override < 0) then { _speed = _speed * -_override; };
_speed * exp ((_ammo get "friction") * _range)
