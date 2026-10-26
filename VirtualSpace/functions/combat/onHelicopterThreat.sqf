params ["_object","_source"];
if (isNull _source || {side _object getFriend side _source>=0.6 && {side _source getFriend side _object>=0.6}}) exitWith {};
private _vehicle = [_object getVariable ["entityID",""]] call IVCS_VirtualSpace_getEntity;
if (!isNil "_vehicle") then {[_vehicle,createHashMapFromArray [["position",getPos _source],["id",_source getVariable ["entityID",""]]]] call IVCS_Combat_markAirThreat};
