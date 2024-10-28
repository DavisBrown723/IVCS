params ["_grid","_position", ["_dontRestrict", false]];

private _bounds = _grid get "bounds";

_position params ["_argX","_argY"];

if (
    _dontRestrict || {
        _argX >= (_bounds select 0) &&
        {_argY >= (_bounds select 1)} &&
        {_argX <= (_bounds select 2)} &&
        {_argY <= (_bounds select 3)}
    }
) then {
    private _origin = _grid get "origin";
    _argX = _argX + (abs (_origin select 0));
    _argY = _argY + (abs (_origin select 1));

    private _cellSize = _grid get "cellSize";
    [
        floor (_argX / _cellSize),
        floor (_argY / _cellSize)
    ]
} else {
    [-1,-1]
};