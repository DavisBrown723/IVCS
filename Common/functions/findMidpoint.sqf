params ["_points"];

// avoid vectoradd so we can take points of varying dimensions

private _sumX = 0;
private _sumY = 0;
{
    _sumX = _sumX + (_x select 0);
    _sumY = _sumY + (_x select 1);
} foreach _points;

private _pointCount = count _points;

[_sumx / _pointCount, _sumY / _pointCount]