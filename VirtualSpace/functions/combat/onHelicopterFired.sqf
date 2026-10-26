// Native firing triggers the same infantry response as virtual attempts; flares do not.
params ["_object","_gunner","_magazine"];
private _helicopter=[_object getVariable ["entityID",""]] call IVCS_VirtualSpace_getEntity;
if (isNil "_helicopter" || {(_helicopter get "combatID")==""}) exitWith {};
if !(([_magazine] call IVCS_Combat_getAmmoProfile) get "infantrySupported") exitWith {};
private _engagement=((IVCS_VirtualSpace_Controller get "combat") get "engagements") get (_helicopter get "combatID");
if ((_engagement get "mode")!="native") exitWith {};
private _target=assignedTarget _gunner;
private _id=if (isNull _target) then {(_engagement get "groups") select 0} else {_target getVariable ["entityID",""]};
private _group=[_id] call IVCS_VirtualSpace_getEntity;
if (!isNil "_group" && {(_group get "entityType")=="group"} && {(_group get "combatID")==(_engagement get "id")}) then {[_group,_helicopter,IVCS_SimulationTime] call IVCS_Combat_markInfantryAirThreat};
