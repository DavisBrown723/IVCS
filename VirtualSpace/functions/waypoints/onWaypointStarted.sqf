params ["_entity","_waypoint"];

private _airSettings = _entity get "airWaypointSettings";
{private _value=_waypoint get (_x select 0); if (_value!=(_x select 1)) then {_airSettings set [_forEachIndex,_value]}} forEach [["combatMode","NO CHANGE"],["behavior","UNCHANGED"],["speed","UNCHANGED"]];
_entity set ["airWaypointSettings",_airSettings];
private _waypointType = _waypoint get "type";
switch (_waypointType) do {
    case "LAND";
	case "MOVE": {
        private _entityActive = _entity get "active";
        if (!_entityActive) then {
            private _vehiclesInCommandOf = _entity get "vehiclesInCommandOf";
            {
                private _vehicleEntity = [_x] call IVCS_VirtualSpace_getEntity;
                _vehicleEntity set ["engineOn", true];

                private _vehicleEntityType = _vehicleEntity get "vehicleType";
                private _heightAdjustment = switch (_vehicleEntityType) do {
                    case "helicopter": { 50 };
                    case "plane": { 300 };
                    default { 0 };
                };

                if (_heightAdjustment > 0) then {
                    private _vehicleEntityPosition = _vehicleEntity get "position";
                    if (_vehicleEntityPosition select 2 < 5) then {
                        _vehicleEntityPosition set [2, _heightAdjustment];
                    };
                };
            } foreach _vehiclesInCommandOf;
        };
	};
};

_waypoint set ["initialized", true];