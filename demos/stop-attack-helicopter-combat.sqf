// Run on the server: [] execVM "IVCS\demos\stop-attack-helicopter-combat.sqf";
if (!isServer) exitWith {};
terminate (missionNamespace getVariable ["IVCS_Demo_AttackHelicopterCombatScript", scriptNull]);
{
    private _entity = [_x] call IVCS_VirtualSpace_getEntity;
    if (!isNil "_entity") then {
        if (_entity get "active") then {
            if ((_entity get "entityType") == "group") then {
                [_entity] call IVCS_VirtualSpace_Group_despawn;
            } else {
                [_entity] call IVCS_VirtualSpace_Vehicle_despawn;
            };
        };
        [_entity] call IVCS_VirtualSpace_unregisterEntity;
    };
} forEach (missionNamespace getVariable ["IVCS_Demo_AttackHelicopterCombatIDs", []]);
{ deleteMarker (_x select 1); } forEach (missionNamespace getVariable ["IVCS_Demo_AttackHelicopterCombatMarkers", []]);
IVCS_Demo_AttackHelicopterCombatIDs = [];
IVCS_Demo_AttackHelicopterCombatMarkers = [];
IVCS_Demo_AttackHelicopterCombatScript = scriptNull;
