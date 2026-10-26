// Position-only terrain check; inject a water predicate for deterministic fixtures.
params ["_position", "_radius", "_step", ["_isWater", { surfaceIsWater (_this select 0) }]];
if ([_position] call _isWater) exitWith { true };
_radius = _radius max 0;
_step = _step max 1;
private _found = false;
private _cells = floor (_radius / _step);
for "_dy" from -_cells to _cells do {
    for "_dx" from -_cells to _cells do {
        private _offset = [_dx * _step, _dy * _step, 0];
        if (vectorMagnitude _offset <= _radius && {[_position vectorAdd _offset] call _isWater}) exitWith { _found = true; };
    };
    if (_found) exitWith {};
};
_found
