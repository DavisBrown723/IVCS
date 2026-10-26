params ["_entity"];
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _engagement = (_combat get "engagements") get (_entity get "combatID");
_engagement set ["mode", "despawning"];
private _members = [_entity] call IVCS_Combat_getSpawnPartners;
{
    if (_x get "active" && { !(_x get "simulationTransition") }) then { [_x] call (missionNamespace getVariable (_x get "despawn")); };
} forEach _members;
if (_members findIf { _x get "active" || { _x get "simulationTransition" } } != -1) exitWith {};
_engagement set ["mode", "virtual"];
_engagement set ["pending", 0];
_engagement set ["lastUpdate", IVCS_SimulationTime];
// Native time must not consume a fresh virtual recovery window.
_engagement set ["lastProgressAt", IVCS_SimulationTime];
_engagement set ["lastContactAt", IVCS_SimulationTime];
