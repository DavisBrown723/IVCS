params ["_center","_radius","_direction","_angle"];

private _resize2D = _center isEqualTypeArray [0,0];
private _randomPosition = _center getPos [_radius * sqrt random 1, _direction - 0.5 * _angle + random _angle];

if (_resize2D) then {
    _randomPosition resize 2;
} else {
    _position
}