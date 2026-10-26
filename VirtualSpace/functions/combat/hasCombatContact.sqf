params ["_engagement","_participants"];
if (_participants call IVCS_Combat_canSee) exitWith {true};
if !(_participants call IVCS_Combat_isHelicopterPair) exitWith {false};
private _helicopter=_participants select 1;
(_engagement get "supporters") findIf {private _entity=[_x] call IVCS_VirtualSpace_getEntity;!isNil "_entity" && {[_entity,_helicopter] call IVCS_Combat_canSee}} != -1
