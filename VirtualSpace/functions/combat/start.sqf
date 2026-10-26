params ["_a", "_b", ["_now", IVCS_SimulationTime], ["_seed", floor random 65536]];
// Normalize the vehicle participant into the second slot.
if ((_a get "vehicleType")=="helicopter" || {(_a get "entityType") in ["vehicle","uav"] && {(_b get "vehicleType")!="helicopter"}}) then { private _first = _a; _a = _b; _b = _first; };
if (_a isEqualRef _b || { !([_a,_b] call IVCS_Combat_isPair) }) exitWith { nil };
if ((_b get "vehicleType")=="helicopter" && {(_b get "combatID")!=""} && {(_a get "combatID")!=(_b get "combatID")}) exitWith {[_a,_b,_now] call IVCS_Combat_joinHelicopterSupport};
if ((_a get "combatID") != "" || { (_b get "combatID") != "" }) exitWith { nil };
private _sideA=[_a] call IVCS_Combat_getCombatSide;
private _sideB=[_b] call IVCS_Combat_getCombatSide;
if (_sideA getFriend _sideB >= 0.6 && { _sideB getFriend _sideA >= 0.6 }) exitWith { nil };
if (!([_a, _b] call IVCS_Combat_canSee)) exitWith { nil };
if (_now < ((_a get "combatCooldowns") getOrDefault [_b get "id",-1]) || {_now < ((_b get "combatCooldowns") getOrDefault [_a get "id",-1])}) exitWith { nil };
private _vehicleTarget = (_b get "entityType") in ["vehicle","uav"];
private _armed = if ([_a,_b] call IVCS_Combat_isHelicopterPair) then {[_a,_b] call IVCS_Combat_canFightHelicopter} else {if (_vehicleTarget) then {
    [_a,_b] call IVCS_Combat_canFightVehicle
} else { ((_a get "units") + (_b get "units")) findIf { ([_x] call IVCS_Combat_getShot) isNotEqualTo [] } != -1 }};
if (!_armed) exitWith { nil };
private _members = [[_a,_b]] call IVCS_Combat_getLinkedEntities;
if (_members findIf { (_x get "combatID") != "" || { _x get "simulationTransition" } } != -1) exitWith { nil };
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _id = format ["combat_%1", _combat get "nextID"];
_combat set ["nextID", (_combat get "nextID") + 1];
private _engagement = createHashMapFromArray [
    ["id", _id], ["airOffensive",[_a,_b] call IVCS_Combat_isHelicopterPair && {(([_b] call IVCS_Combat_getHelicopterPolicy) select 2)} && {[_b,_a] call IVCS_Combat_inHelicopterAttackArea}], ["startedAt",_now], ["supporters",[]], ["supportJoinedAt",createHashMap], ["groups", [_a get "id", _b get "id"]], ["members",_members apply { _x get "id" }],
    ["mode", "virtual"], ["lastUpdate", _now], ["pending", 0], ["elapsed", 0],
    ["lastProgressAt",_now], ["lastContactAt",_now],
    ["seed", _seed], ["vehicleShots",0], ["vehicleHits",0], ["shots", 0], ["hits", 0], ["casualties", 0], ["nativeSettings", createHashMap]
];
(_combat get "engagements") set [_id, _engagement];
(_combat get "queue") pushBack _id;
{
    if ((_x get "entityType") == "group") then { [_x] call IVCS_Ammo_cancelGroup; };
    if ((_x get "entityType")!="group" && {_x get "active"}) then {_x set ["flightRestorePending",false]};
    _x set ["combatID", _id];
    _x set ["combatStartedAt", IVCS_SimulationTime];
    if ((_x get "entityType") == "group") then { { _x set ["fireDelay", 0]; _x set ["planting",[]]; } forEach (_x get "units"); } else { _x set ["turretFireDelays",createHashMap]; };
} forEach _members;
private _activeIndex = _members findIf { _x get "active" };
if (_activeIndex != -1) then { [_members select _activeIndex] call IVCS_Combat_onSpawn; };
_engagement
