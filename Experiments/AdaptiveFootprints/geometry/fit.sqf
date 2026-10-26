// [positions, padding, options] -> ["circle"|"rectangle", center, halfAxes, clockwiseDegrees].
// Fits all supplied object origins. Empty input returns []; the caller owns membership.
params ["_positions", ["_padding", 0], ["_options", createHashMap]];
if (_positions isEqualTo []) exitWith { [] };
_padding = _padding max 0;
private _origin = [0,0,0];
{ _origin = _origin vectorAdd [_x select 0, _x select 1, 0]; } forEach _positions;
_origin = _origin vectorMultiply (1 / count _positions);
private _radius = 0;
{ _radius = _radius max (_origin distance2D _x); } forEach _positions;
_radius = _radius + _padding;
private _circle = ["circle", _origin, [_radius,_radius], 0];
if !(_options getOrDefault ["enabled", true]) exitWith { _circle };
private _sorted = _positions apply { [_x select 0, _x select 1] };
_sorted sort true;
private _unique = [];
{ if (_unique isEqualTo [] || {!(_x isEqualTo (_unique select (count _unique - 1)))}) then { _unique pushBack _x; }; } forEach _sorted;
if (count _unique < (2 max (_options getOrDefault ["minimumRectangleMembers", 4]))) exitWith { _circle };
// Monotone-chain hull removes interior points before examining edge orientations.
private _reverse = +_unique;
reverse _reverse;
private _hull = [];
{
    private _half = [];
    {
        private _point = _x;
        private _done = false;
        while {count _half >= 2 && {!_done}} do {
            private _a = _half select (count _half - 2);
            private _b = _half select (count _half - 1);
            private _cross = ((_b select 0) - (_a select 0)) * ((_point select 1) - (_a select 1)) - ((_b select 1) - (_a select 1)) * ((_point select 0) - (_a select 0));
            if (_cross <= 0) then { _half deleteAt (count _half - 1); } else { _done = true; };
        };
        _half pushBack _point;
    } forEach _x;
    _half deleteAt (count _half - 1);
    _hull append _half;
} forEach [_unique, _reverse];
private _bestArea = 1e30;
private _bestAngle = 1e30;
private _best = [];
{
    private _a = _x;
    private _b = _hull select ((_forEachIndex + 1) mod count _hull);
    private _dx = (_b select 0) - (_a select 0);
    private _dy = (_b select 1) - (_a select 1);
    // Marker local x axis is [cos(angle), -sin(angle)]; y is [sin(angle), cos(angle)].
    private _angle = ((((-_dy) atan2 _dx) mod 90) + 90) mod 90;
    private _cos = cos _angle;
    private _sin = sin _angle;
    private _minX = 1e30;
    private _minY = 1e30;
    private _maxX = -1e30;
    private _maxY = -1e30;
    {
        private _dx = (_x select 0) - (_origin select 0);
        private _dy = (_x select 1) - (_origin select 1);
        private _localX = _dx * _cos - _dy * _sin;
        private _localY = _dx * _sin + _dy * _cos;
        _minX = _minX min _localX;
        _maxX = _maxX max _localX;
        _minY = _minY min _localY;
        _maxY = _maxY max _localY;
    } forEach _hull;
    private _area = (_maxX - _minX) * (_maxY - _minY);
    if (_area < _bestArea - 0.001 || {abs (_area - _bestArea) <= 0.001 && {_angle < _bestAngle}}) then {
        _bestArea = _area;
        _bestAngle = _angle;
        private _midX = (_minX + _maxX) / 2;
        private _midY = (_minY + _maxY) / 2;
        private _center = [(_origin select 0) + _midX * _cos + _midY * _sin, (_origin select 1) - _midX * _sin + _midY * _cos, 0];
        _best = ["rectangle", _center, [(_maxX - _minX) / 2 + _padding, (_maxY - _minY) / 2 + _padding], _angle];
    };
} forEach _hull;
(_best select 2) params ["_halfX", "_halfY"];
private _aspect = (_halfX max _halfY) / ((_halfX min _halfY) max 0.001);
private _areaRatio = (4 * _halfX * _halfY) / ((pi * _radius * _radius) max 0.001);
if (_aspect >= (_options getOrDefault ["minimumAspectRatio", 1.8]) && {_areaRatio <= (_options getOrDefault ["maximumRectangleAreaRatio", 0.70])}) then { _best } else { _circle }
