params ["_origin","_gridSize","_cellSize"];

_origin params ["_originX","_originY"];

private _gridCellLength = ceil (_gridSize / _cellSize);
private _gridBounds = [_originX, _originY, _originX + (_gridCellLength * _cellSize), _originY + (_gridCellLength * _cellSize)];

private _cells = [];
for "_y" from 0 to _gridCellLength - 1 do {
    for "_x" from 0 to _gridCellLength - 1 do {
        _cells pushback [];

        private _sectorOrigin = [
            _originX + (_x * _cellSize),
            _originY + (_y * _cellSize)
        ];
        private _sectorCenter = _sectorOrigin vectorAdd [_cellSize / 2, _cellSize / 2];
        _markerstr = createMarker [str [_x,_y], _sectorCenter];
        // _markerstr setMarkerShape "ICON";
        // _markerstr setMarkerType "hd_dot";
        // _markerstr setMarkerSize [2,2];
        _markerstr setMarkerShape "RECTANGLE";
        _markerstr setMarkerSize [_cellSize / 2, _cellSize / 2];
        if (_x mod 2 == 0) then {
            if (_y mod 2== 0) then {
                _markerstr setmarkercolor "colorred";
            } else {
                _markerstr setmarkercolor "colorblack";
            };
        } else {
            if (_y mod 2== 0) then {
                _markerstr setmarkercolor "colorblack";
            } else {
                _markerstr setmarkercolor "colorred";
            };
        };
        // _markerstr setmarkercolor "colorred";
        _markerstr setmarkeralpha 0.5;
        _markerstr setmarkertext (str [_x,_y]);
    };
};

private _grid = [] call CBA_fnc_createNamespace;
_grid setvariable ["origin", _origin];
_grid setvariable ["length", _gridSize];
_grid setvariable ["cellSize", _cellSize];
_grid setvariable ["cellsPerRow", _gridCellLength];
_grid setvariable ["bounds", _gridBounds];
_grid setvariable ["cells", _cells];

_grid