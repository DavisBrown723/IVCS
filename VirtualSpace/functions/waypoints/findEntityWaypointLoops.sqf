params ["_entity"];

private _waypoints = _entity get "waypoints";
private _loops = [];

private _loopWaypoints = [];
{
	private _type = _x get "type";
	if (_type == "CYCLE") then {
		if (_loopWaypoints isnotequalto []) then {
			_loops pushback _loopWaypoints;
			_loopWaypoints = [];
		};
	} else {
		_loopWaypoints pushback _x;
	};
} foreach _waypoints;

if (_loopWaypoints isnotequalto []) then {
	_loops pushback _loopWaypoints;
};

_loops apply {
	private _lowerBoundIndex = _waypoints find (_x select 0);
	private _upperBoundIndex = _waypoints find (_x select -1);

	[_lowerBoundIndex, _upperBoundIndex, _x]
}