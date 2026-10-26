// Cheap, bounded group retreat and exposure; no per-unit cover search or task insertion.
params ["_group","_dt"];
private _state=_group get "airDefense";
if (_state isEqualTo [] || {(_state select 0)!=(_group get "combatID")}) exitWith {};
private _combat=IVCS_VirtualSpace_Controller get "combat";
if (IVCS_SimulationTime-(_state select 1)<(_combat get "airReactionDelay")) exitWith {};
private _engagement=(_combat get "engagements") get (_state select 0);
if ((_engagement get "mode") in ["spawning","despawning"]) exitWith {};
if !([_group] call IVCS_Combat_isInfantry) exitWith {};
private _destination=_state select 2;
if (_group get "active") exitWith {
    if ((_group get "airDefenseDestination") isEqualTo []) then {
        private _stances=[];
        {_stances pushBack [_x,unitPos _x];_x setUnitPos "MIDDLE"} forEach units (_group get "group");
        _group set ["airDefenseStances",_stances];_group set ["airDefenseDestination",+_destination];
        (leader (_group get "group")) doMove _destination;
    };
};
private _position=_group get "position";
private _distance=_position distance2D _destination;
private _move=(_group get "moveSpeedPerSecond")*_dt min _distance;
private _next=_position getPos [_move,_position getDir _destination];_next set [2,_position select 2];
[_group,_next] call IVCS_VirtualSpace_setEntityPosition;
if (_distance-_move<=1 && {((_engagement get "groups") select 0)==(_group get "id")}) then {
    private _helicopter=[(_engagement get "groups") select 1] call IVCS_VirtualSpace_getEntity;
    if (!([_group,_helicopter,true] call IVCS_Combat_canShootHelicopter)) then {[_state select 0,"withdrawal"] call IVCS_Combat_finish};
};
