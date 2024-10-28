// params ["_grid","_startPos","_endPos","_width"];

// private _dir = _startPos getdir _endPos;
// private _halfWidth = _width / 2;
// private _botLeft = _startPos getpos [_halfWidth, _dir - 90];
// private _botRight = _startPos getpos [_halfWidth, _dir + 90];
// private _topLeft = _endPos getpos [_halfWidth, _dir - 90];
// private _topRight = _endPos getpos [_halfWidth, _dir + 90];

// private ["_min]

// private _minCoords = [_grid, _lowerLeft, true] call IVCS_SpacialGrid_positionToCoords;
// private _maxCoords = [_grid, _upperRight, true] call IVCS_SpacialGrid_positionToCoords;

// private _cellsPerRow = _grid get "cellsPerRow";

// _minCoords = _minCoords apply {_x max 0};
// _maxCoords = _maxCoords apply {_x min (_cellsPerRow - 1)};

// private _cells = _grid get "cells";
// private _cellsInRadius = [];

// for "_y" from (_minCoords select 1) to (_maxCoords select 1) do {
//     for "_x" from (_minCoords select 0) to (_maxCoords select 0) do {
//         private _index = _x + (_y * _cellsPerRow);
//         _cellsInRadius append (_cells select _index);
//     };
// };

// _cellsInRadius


// https://math.stackexchange.com/questions/2449221/calculating-percentage-of-overlap-between-two-rectangles
/*
First Rec: 
		t0
	
	l0		r0

		b0


Second Rec: 

		t1

	l1		r1

		b1



overlap = (max(l0, l1) - min(r0, r1)) * (max(t0,t1) - min(b0, b1))
*/