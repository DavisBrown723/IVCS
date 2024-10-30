params ["_entityID","_waypointID","_path"];

private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
if (!isnil "_entity") then {
	private _active = _entity get "active";
	if (!_active) then {
		private _waypoint = [_entity,_waypointID] call IVCS_VirtualSpace_getEntityWaypoint;

		// debug
		{
			private _marker = createmarker [str _x, _x];
			_marker setmarkertype "mil_dot";
			_marker setMarkerSize [0.5, 0.5];
		} foreach _path;
		// debug

		_waypoint set ["movePoints", _path];
		_waypoint set ["pathGenerationRequestID", "COMPLETE"];
	} else {
		hint format ["Path callback for active profile - waypoint %1", _waypoint get "name"];
	};
};