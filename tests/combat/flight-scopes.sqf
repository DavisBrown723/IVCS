// Isolated diagnostic scopes. Tuple returns preserve variables across the new call scopes.
private _replaceOnce={
    params ["_source","_needle","_replacement"];
    _source=toString ((toArray _source) select {_x!=13});
    _needle=toString ((toArray _needle) select {_x!=13});
    private _index=_source find _needle;
    if (_index<0 || {((_source select [_index+count _needle]) find _needle)>=0}) then {throw format ["Flight diagnostic anchor missing/ambiguous: %1",_needle]};
    (_source select [0,_index])+_replacement+(_source select [_index+count _needle])
};
IVCS_FlightDiag_Rows=[];
private _source=preprocessFileLineNumbers "IVCS\VirtualSpace\functions\combat\updateHelicopter.sqf";
_source=[_source,'private _hp =','private _condition=call {private _scope=createProfileScope "IVCS_FLIGHT_Health"; private _hp ='] call _replaceOnce;
_source=[_source,'private _disabled = (_vehicle get "speedPerSecond") <= 0;','private _disabled = (_vehicle get "speedPerSecond") <= 0; [_crash,_disabled]}; private _crash=_condition select 0;private _disabled=_condition select 1;'] call _replaceOnce;
_source=[_source,'if (_evade) then {','if (_evade) then {private _scope=createProfileScope "IVCS_FLIGHT_Evasion";'] call _replaceOnce;
_source=[_source,'private _inArea=_area','private _inArea=call {private _scope=createProfileScope "IVCS_FLIGHT_AreaCheck"; _area'] call _replaceOnce;
_source=[_source,'(_attackTarget get "position") distance2D (_area select 0)<=(_area select 1)};','(_attackTarget get "position") distance2D (_area select 0)<=(_area select 1)}};'] call _replaceOnce;
_source=[_source,'if (!_evade && {_inArea}) then {','if (!_evade && {_inArea}) then {private _scope=createProfileScope "IVCS_FLIGHT_Destination";'] call _replaceOnce;
_source=[_source,'if (_inArea && {_destination isNotEqualTo []}) then {','if (_inArea && {_destination isNotEqualTo []}) then {private _scope=createProfileScope "IVCS_FLIGHT_Leash";'] call _replaceOnce;
if ((_source find "private _velocity=[0,0,0];")>=0) then {
    _source=[_source,'if (_destination isNotEqualTo _position) then {','if (_destination isNotEqualTo _position) then {private _scope=createProfileScope "IVCS_FLIGHT_Integrate";'] call _replaceOnce;
    _source=[_source,'_vehicle set ["engineOn",true]; _vehicle set ["flightVelocity",_velocity];','IVCS_FlightDiag_Rows pushBack ["move",diag_frameNo,_vehicle get "id",_dt,_position,_destination,_position distance _destination,_velocity,_next isEqualTo _position,_hold,_evade]; _vehicle set ["engineOn",true]; _vehicle set ["flightVelocity",_velocity];'] call _replaceOnce;
} else {
_source=[_source,'private _speed = _vehicle get "speedPerSecond";','private _motion=call {private _scope=createProfileScope "IVCS_FLIGHT_Integrate"; private _speed = _vehicle get "speedPerSecond";'] call _replaceOnce;
_source=[_source,'_vehicle set ["engineOn",true]; _vehicle set ["flightVelocity",_velocity];','IVCS_FlightDiag_Rows pushBack ["move",diag_frameNo,_vehicle get "id",_dt,_position,_destination,_distance,_velocity,_next isEqualTo _position,_hold,_evade]; [_velocity,_next]}; private _velocity=_motion select 0;private _next=_motion select 1; _vehicle set ["engineOn",true]; _vehicle set ["flightVelocity",_velocity];'] call _replaceOnce;
};
IVCS_Combat_updateHelicopter=compile _source;
_source=preprocessFileLineNumbers "IVCS\SpacialGrid\functions\remove.sqf";
_source=[_source,'private _index = _cell find _item;','private _index=call {private _scope=createProfileScope "IVCS_FLIGHT_GridFind"; _cell find _item}; IVCS_FlightDiag_Rows pushBack ["grid",diag_frameNo,count _cell,_index,_position];'] call _replaceOnce;
IVCS_SpacialGrid_remove=compile _source;
{
    private _saved="IVCS_FlightDiag_"+_x;
    missionNamespace setVariable [_saved,missionNamespace getVariable _x];
    missionNamespace setVariable [_x,compile format ['private _scope=createProfileScope %1; _this call %2',str ("IVCS_FLIGHT_"+_x),_saved]];
} forEach ["IVCS_SpacialGrid_remove","IVCS_SpacialGrid_insert","IVCS_SpacialGrid_positionToCoords","IVCS_SpacialGrid_coordsToCell"];
diag_log "[IVCS PERF] FLIGHT_SCOPES installed";
