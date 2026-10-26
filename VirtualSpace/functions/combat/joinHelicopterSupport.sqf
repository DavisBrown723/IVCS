// AA prioritizes an air threat; one engagement owns its whole transport/crew graph.
params ["_support","_helicopter",["_now",IVCS_SimulationTime]];
private _combat=IVCS_VirtualSpace_Controller get "combat";
private _engagement=(_combat get "engagements") get (_helicopter get "combatID");
if (isNil "_engagement" || {!((_engagement get "mode") in ["virtual","native"])} || {((_engagement get "groups") select 1)!=(_helicopter get "id")}) exitWith {nil};
private _oldID=_support get "combatID";
if (_oldID==(_engagement get "id") || {_support get "simulationTransition"}) exitWith {nil};
private _oldEngagement=(_combat get "engagements") get _oldID;
private _switchable=isNil "_oldEngagement" || {
    private _oldParticipants=(_oldEngagement get "groups") apply {[_x] call IVCS_VirtualSpace_getEntity};
    (_oldEngagement get "mode") in ["virtual","native"] && {!(_oldParticipants call IVCS_Combat_isHelicopterPair)}
};
if (!_switchable) exitWith {nil};
if ((_support get "entityType")=="group" && {!([_support] call IVCS_Combat_isInfantry)}) exitWith {nil};
private _primary=[(_engagement get "groups") select 0] call IVCS_VirtualSpace_getEntity;
private _side=[_support] call IVCS_Combat_getCombatSide;
private _ally=[_primary] call IVCS_Combat_getCombatSide;
private _enemy=[_helicopter] call IVCS_Combat_getCombatSide;
if (_side getFriend _ally<0.6 || {_ally getFriend _side<0.6} || {_side getFriend _enemy>=0.6 && {_enemy getFriend _side>=0.6}}) exitWith {nil};
if (_now<((_support get "combatCooldowns") getOrDefault [_helicopter get "id",-1]) || {_now<((_helicopter get "combatCooldowns") getOrDefault [_support get "id",-1])}) exitWith {nil};
if (!([_support,_helicopter] call IVCS_Combat_canSee) || {!([_support,_helicopter,true] call IVCS_Combat_canShootHelicopter)}) exitWith {nil};
private _members=[[_support]] call IVCS_Combat_getLinkedEntities;
if (_members findIf {!((_x get "combatID") in ["",_oldID]) || {_x get "simulationTransition"}} != -1) exitWith {nil};
// Flush before membership changes so joining AA cannot fire retroactively through pending time.
if ((_engagement get "mode")=="virtual") then {[_helicopter] call IVCS_Combat_flushPending};
if ((_engagement get "mode")=="finished") exitWith {nil};
if (!isNil "_oldEngagement") then {
    if ((_oldEngagement get "mode")=="virtual") then {[_support] call IVCS_Combat_flushPending};
};
if (isNil {[_support get "id"] call IVCS_VirtualSpace_getEntity}) exitWith {nil};
if (!([_support,_helicopter,true] call IVCS_Combat_canShootHelicopter)) exitWith {nil};
// Pending damage may have removed an operator or a linked crew group.
_members=[[_support]] call IVCS_Combat_getLinkedEntities;
if (_oldID!="") then {[_oldID,"airSupport",_now] call IVCS_Combat_finish};
(_engagement get "supporters") pushBack (_support get "id");
(_engagement get "supportJoinedAt") set [_support get "id",_now];
{
    _x set ["combatID",_engagement get "id"];_x set ["combatStartedAt",_now];
    (_engagement get "members") pushBack (_x get "id");
    if ((_x get "entityType")=="group") then {
        [_x] call IVCS_Ammo_cancelGroup;
        if (_oldID=="") then {{_x set ["fireDelay",0]} forEach (_x get "units")};
    } else {if (_oldID=="") then {_x set ["turretFireDelays",createHashMap]}};
} forEach _members;
private _native=(_engagement get "mode")=="native" || {_members findIf {_x get "active"} != -1};
if (_native) then {_engagement set ["mode","spawning"];[_helicopter] call IVCS_Combat_onSpawn};
_engagement
