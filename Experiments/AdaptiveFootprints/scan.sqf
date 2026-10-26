// Scheduled authoring operation. Returns plain [class, model, position] records.
// Half-open tile ownership removes overlap without relying on transient object IDs.
params [["_settings", call IVCS_AF_indexSettings], ["_bounds", [0,0,worldSize,worldSize]]];
_bounds params ["_minX", "_minY", "_maxX", "_maxY"];
private _tile = (_settings get "tileSize") max 50;
private _records = [];
for "_row" from 0 to (ceil ((_maxY - _minY) / _tile) - 1) do {
    private _bottom = _minY + _row * _tile;
    private _top = (_bottom + _tile) min _maxY;
    for "_column" from 0 to (ceil ((_maxX - _minX) / _tile) - 1) do {
        private _left = _minX + _column * _tile;
        private _right = (_left + _tile) min _maxX;
        private _center = [(_left + _right) / 2, (_bottom + _top) / 2, 0];
        private _radius = sqrt ((_right - _left)^2 + (_top - _bottom)^2) / 2 + 1;
        {
            private _pos = getPosWorld _x;
            _pos params ["_px", "_py"];
            if (_px >= _left && {_px < _right} && {_py >= _bottom} && {_py < _top}) then {
                private _model = toLower ((getModelInfo _x) param [1, ""]);
                if (_model != "") then {
                    _records pushBack [toLower typeOf _x, _model, [_px, _py, 0]];
                };
            };
        } forEach nearestTerrainObjects [_center, _settings get "terrainTypes", _radius, false, true];
        if (canSuspend) then { sleep 0.001; };
    };
    diag_log format ["[IVCS AF INDEX] scan row %1/%2, objects=%3", _row + 1, ceil ((_maxY - _minY) / _tile), count _records];
};
_records
