params ["_entity"];
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _engagement = (_combat get "engagements") get (_entity get "combatID");
if ((_engagement get "mode")=="native") exitWith {};
_engagement set ["mode", "spawning"];
_engagement set ["pending", 0];
private _members = [_entity] call IVCS_Combat_getSpawnPartners;
{
    if (!(_x get "active")) then { [_x] call (missionNamespace getVariable (_x get "spawn")); };
} forEach _members;
if (_members findIf { !(_x get "active") || { _x get "simulationTransition" } } != -1) exitWith {};
if ((_engagement get "mode") in ["native","finished"]) exitWith {};
// Boarding can reset native motion. Restore it after all connected crew finish spawning.
{
    if ((_x get "entityType")!="group" && {(_x get "vehicleType")=="helicopter"} && {_x get "flightRestorePending"}) then {
        private _object=_x get "object";
        _object setDir (_x get "flightHeading");
        _object setVelocity (_x get "flightVelocity");
        _x set ["flightRestorePending",false];
    };
} forEach _members;
_engagement set ["mode", "native"];
_engagement set ["lastUpdate", IVCS_SimulationTime];
private _participants = (_engagement get "groups") apply { [_x] call IVCS_VirtualSpace_getEntity };
{
    private _entity = _x;
    private _isAttacker = ([_entity] call IVCS_Combat_getCombatSide) getFriend ([_participants select 0] call IVCS_Combat_getCombatSide) >= 0.6;
    private _opponent = _participants select (if (_isAttacker) then {1} else {0});
    private _opponents=if (_isAttacker) then {[_opponent]} else {[_opponent]+((_engagement get "supporters") apply {[_x] call IVCS_VirtualSpace_getEntity})};
    private _enemies=[];
    {if ((_x get "entityType")=="group") then {_enemies append units (_x get "group")} else {_enemies pushBack (_x get "object")}} forEach _opponents;
    if ((_entity get "entityType") == "group") then {
        private _group = _entity get "group";
        [_entity,false] call IVCS_Combat_clearAirDefense;
        private _airCrew = ((_entity get "vehiclesInCommandOf")+(_entity get "vehiclesInCargoOf")) findIf {
            private _v=[_x] call IVCS_VirtualSpace_getEntity; (_v get "vehicleType")=="helicopter"
        } != -1;
        if (!_airCrew) then {if (!((_entity get "id") in (_engagement get "nativeSettings"))) then {(_engagement get "nativeSettings") set [_entity get "id",[combatMode _group,behaviour leader _group]]}; _group setCombatMode "RED"; _group setBehaviourStrong "COMBAT"};
        { _group reveal [_x, 4]; } forEach _enemies;
        { _x stop false; } forEach units _group;
        units _group doFollow leader _group;
        { _x set ["planting",[]]; } forEach (_entity get "units");
        _entity set ["movementStopped", false];
    } else {
        private _crewGroups = (_entity get "nativeCrew") apply {group _x};
        { private _crewGroup = _x; { _crewGroup reveal [_x,4]; } forEach _enemies; } forEach (_crewGroups arrayIntersect _crewGroups);
    };
} forEach _members;

// Enforce a reposition hold before newly restored AI can begin firing.
if (_participants call IVCS_Combat_isHelicopterPair && {((_participants select 0) get "entityType")=="group"}) then {
    private _heli=_participants select 1;
    private _passes=(([_heli] call IVCS_Combat_getHelicopterPolicy) select 2) && {[_heli,_participants select 0] call IVCS_Combat_inHelicopterAttackArea};
    [_heli,_passes && {!(([_engagement] call IVCS_Combat_getHelicopterPass) select 1)}] call IVCS_Combat_setHelicopterPassHold;
};
