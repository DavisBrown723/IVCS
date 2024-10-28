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

        // _markerstr = createMarker [str [_x,_y], _sectorCenter];
        // _markerstr setMarkerShape "RECTANGLE";
        // _markerstr setMarkerSize [_cellSize / 2, _cellSize / 2];
        // if (_x mod 2 == 0) then {
        //     if (_y mod 2== 0) then {
        //         _markerstr setmarkercolor "colorred";
        //     } else {
        //         _markerstr setmarkercolor "colorblack";
        //     };
        // } else {
        //     if (_y mod 2== 0) then {
        //         _markerstr setmarkercolor "colorblack";
        //     } else {
        //         _markerstr setmarkercolor "colorred";
        //     };
        // };
        // _markerstr setmarkeralpha 0.5;
        // _markerstr setmarkertext (str [_x,_y]);
    };
};

private _grid = createHashMapFromArray [
    ["origin", _origin],
    ["length", _gridSize],
    ["cellSize", _cellSize],
    ["cellsPerRow", _gridCellLength],
    ["bounds", _gridBounds],
    ["cells", _cells]
];

_grid