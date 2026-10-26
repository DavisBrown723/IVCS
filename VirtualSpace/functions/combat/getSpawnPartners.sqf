params ["_entity"];
if ((_entity get "combatID") == "") exitWith { [_entity] };
private _engagement = (((IVCS_VirtualSpace_Controller get "combat") get "engagements") get (_entity get "combatID"));
((_engagement getOrDefault ["members",_engagement get "groups"]) apply { [_x] call IVCS_VirtualSpace_getEntity }) select { !isNil "_x" }
