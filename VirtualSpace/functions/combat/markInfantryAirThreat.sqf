params ["_group","_helicopter","_now"];
if !([_group] call IVCS_Combat_isInfantry) exitWith {};
private _state=_group get "airDefense";
if (_state isEqualTo [] || {(_state select 0)!=(_group get "combatID")}) then {
    private _position=_group get "position";
    private _distance=(IVCS_VirtualSpace_Controller get "combat") get "airRetreatDistance";
    private _destination=_position getPos [_distance,(_helicopter get "position") getDir _position];
    _destination set [2,_position select 2];
    _group set ["airDefense",[_group get "combatID",_now,_destination]];
};
