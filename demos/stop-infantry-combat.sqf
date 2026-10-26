// Run on the server: [] execVM "IVCS\demos\stop-infantry-combat.sqf";
if (!isServer) exitWith {};
terminate (missionNamespace getVariable ["IVCS_Demo_InfantryCombatScript", scriptNull]);
{
    private _entity = [_x] call IVCS_VirtualSpace_getEntity;
    if (!isNil "_entity") then {
        if (_entity get "active") then { [_entity] call IVCS_VirtualSpace_Group_despawn; };
        [_entity] call IVCS_VirtualSpace_unregisterEntity;
    };
} forEach (missionNamespace getVariable ["IVCS_Demo_InfantryCombatIDs", []]);
{ deleteMarker _x; } forEach (missionNamespace getVariable ["IVCS_Demo_InfantryCombatMarkers", []]);
IVCS_Demo_InfantryCombatIDs = [];
IVCS_Demo_InfantryCombatMarkers = [];
IVCS_Demo_InfantryCombatScript = scriptNull;
