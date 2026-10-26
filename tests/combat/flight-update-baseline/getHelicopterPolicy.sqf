// Fire permission and flight intent are independent. Resolve unchanged waypoint settings.
params ["_vehicle"];
private _crew = [_vehicle get "commandingEntity"] call IVCS_VirtualSpace_getEntity;
private _role = "TRANSPORT"; private _mode = "YELLOW"; private _behavior = "AWARE"; private _speed = "NORMAL";
if (!isNil "_crew") then {
    private _settings = _crew get "airWaypointSettings";
    _mode = _settings select 0; _behavior = _settings select 1; _speed = _settings select 2;
    private _wp = [_crew] call IVCS_VirtualSpace_getEntityCurrentWaypoint;
    if (!isNil "_wp") then {
        _role = _wp get "airCombatRole";
        if ((_wp get "combatMode") != "NO CHANGE") then {_mode = _wp get "combatMode"};
        if ((_wp get "behavior") != "UNCHANGED") then {_behavior = _wp get "behavior"};
        if ((_wp get "speed") != "UNCHANGED") then {_speed = _wp get "speed"};
    };
};
[_role,_mode != "BLUE" && {_behavior != "CARELESS"},_role == "ATTACK" && {_mode in ["YELLOW","RED"]} && {_behavior != "CARELESS"},_behavior != "CARELESS",_speed]
