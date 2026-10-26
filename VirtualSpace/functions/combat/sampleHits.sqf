// Inverse binomial CDF: sample successes, not each missed firing attempt.
// Small independent chunks keep the initial probability representable at high counts.
params ["_attempts","_accuracy","_random"];
if (_attempts == 0 || { _accuracy <= 0 }) exitWith { 0 };
if (_accuracy >= 1) exitWith { _attempts };
private _reflect = _accuracy > 0.5;
private _probability = if (_reflect) then { 1 - _accuracy } else { _accuracy };
private _miss = 1 - _probability;
private _ratio = _probability / _miss;
private _remaining = _attempts;
private _count = 0;
while { _remaining > 0 } do {
    private _n = _remaining min 32;
    private _roll = call _random;
    private _mass = _miss ^ _n;
    private _cumulative = _mass;
    private _k = 0;
    while { _roll >= _cumulative && { _k < _n } } do {
        _mass = _mass * (_n - _k) / (_k + 1) * _ratio;
        _k = _k + 1;
        _cumulative = _cumulative + _mass;
    };
    _count = _count + _k;
    _remaining = _remaining - _n;
};
if (_reflect) then { _attempts - _count } else { _count }
