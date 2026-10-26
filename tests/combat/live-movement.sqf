// Run: powershell -File tests/tasks/run.ps1 -TestScript tests/combat/live-movement.sqf -Port 2497 -TimeoutSeconds 120
waitUntil { time > 0 };
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
IVCS_Common_WeaponInfo = createHashMap;
IVCS_Common_MagazineInfo = createHashMap;
IVCS_Common_AmmoInfo = createHashMap;
IVCS_Common_UnitInfo = createHashMap;
IVCS_Common_WeaponAliases = createHashMap;
IVCS_Paths_Generator = createHashMapFromArray [["requestQueue", []], ["currentRequest", []]];
IVCS_VirtualSpace_Controller = [false] call IVCS_VirtualSpace_createController;
removeMissionEventHandler ["EachFrame", IVCS_VirtualSpace_Controller get "onFrameHandlerID"];
private _passed = 0; private _failed = 0;
private _assert = {
    params ["_ok", "_label"];
    if (_ok) then { _passed = _passed + 1; } else { _failed = _failed + 1; };
    diag_log format ["[IVCS TASK TEST] %1 %2", if (_ok) then { "PASS" } else { "FAIL" }, _label];
};
west setFriend [east,0]; east setFriend [west,0];
private _blueUnits = [];
for "_i" from 0 to 2 do { _blueUnits pushBack (["B_Soldier_F",format ["u_%1",_i]] call IVCS_VirtualSpace_Group_createUnit); };
private _blue = ["WEST","BLU_F",[14500,16400,0],_blueUnits] call IVCS_VirtualSpace_Group_createEntity;
private _red = ["EAST","OPF_F",[14700,16400,0],[["O_Soldier_F","u_0"] call IVCS_VirtualSpace_Group_createUnit]] call IVCS_VirtualSpace_Group_createEntity;
private _waypoint = [[14500,16460,0],"MOVE",[["speed","NORMAL"],["completionRadius",7],["behavior","AWARE"]]] call IVCS_VirtualSpace_createEntityWaypoint;
[_blue,_waypoint] call IVCS_VirtualSpace_entityAddWaypoint;
private _engagement = [_blue,_red] call IVCS_Combat_start;
[_blue] call IVCS_VirtualSpace_Group_spawn;
private _group = _blue get "group";
private _objects = units _group;
{ _x disableAI "ALL"; _x allowDamage false; } forEach units (_red get "group");
[(_engagement get "mode") == "native" && { _red get "active" },"live handoff still spawns both opponents"] call _assert;
// Isolate movement orders from native tactical choices and incoming fire.
{ _x disableAI "TARGET"; _x disableAI "AUTOTARGET"; _x allowDamage false; } forEach _objects;
_group setCombatMode "BLUE";
_group setBehaviourStrong "AWARE";
sleep 0.5;
diag_log format ["[IVCS TASK TEST] HANDOFF_COMMANDS %1",_objects apply { currentCommand _x }];
[_objects findIf { currentCommand _x == "STOP" } == -1,"handoff does not give units permanent stop orders"] call _assert;
private _positions = _objects apply { getPosATL _x };
private _deadline = diag_tickTime + 35;
waitUntil { sleep 0.2; ((leader _group) distance2D (_positions select 0)) > 12 || { diag_tickTime > _deadline } };
diag_log format ["[IVCS TASK TEST] HANDOFF_MOVEMENT %1",_objects apply { _x distance2D (_positions select (_objects find _x)) }];
[(leader _group) distance2D (_positions select 0) > 12,"native leader follows its restored movement waypoint"] call _assert;
// Followers can lag behind the leader while settling into formation.
waitUntil {
    sleep 0.2;
    (_objects select [1]) findIf { _x distance2D (_positions select (_objects find _x)) <= 3 } == -1 || { diag_tickTime > _deadline }
};
[(_objects select [1]) findIf { _x distance2D (_positions select (_objects find _x)) <= 3 } == -1,"native followers can advance with their leader"] call _assert;
private _recipient = (_blue get "units") select 1;
private _object = _recipient get "object";
private _destination = (getPosATL _object) getPos [20,90];
private _request = createHashMapFromArray [
    ["native",true],["recipient",_recipient],["phase","approaching"],
    ["oldForcedWalk",false],["oldCommand","MOVE"],["oldDestination",_destination]
];
doStop _object;
[_blue,_request] call IVCS_Ammo_releaseRequest;
sleep 0.2;
[currentCommand _object == "MOVE","ammo cleanup restores movement even during an engagement"] call _assert;
_request set ["oldCommand",""];
doStop _object;
[_blue,_request] call IVCS_Ammo_releaseRequest;
sleep 0.2;
[currentCommand _object != "STOP","ammo cleanup returns an ordinary follower to its formation in combat"] call _assert;
_request set ["oldCommand","STOP"];
[_blue,_request] call IVCS_Ammo_releaseRequest;
sleep 0.2;
[currentCommand _object == "STOP","ammo cleanup preserves a deliberate prior stop order"] call _assert;
_request set ["recipient",(_blue get "units") select 0];
_request set ["oldCommand",""];
_object = leader _group;
private _leaderPosition = getPosATL _object;
doStop _object;
[_blue,_request] call IVCS_Ammo_releaseRequest;
sleep 0.2;
[currentCommand _object != "STOP","ammo cleanup also releases a leader without a prior movement command"] call _assert;
_deadline = diag_tickTime + 10;
waitUntil { sleep 0.2; _object distance2D _leaderPosition > 3 || { diag_tickTime > _deadline } };
[_object distance2D _leaderPosition > 3,"released leader resumes actual waypoint movement"] call _assert;
{
    if (_x get "active") then { [_x] call IVCS_VirtualSpace_Group_despawn; };
    [_x] call IVCS_VirtualSpace_unregisterEntity;
} forEach [_blue,_red];
[count ((IVCS_VirtualSpace_Controller get "entities") get "ALL") == 0,"movement test cleans up its entities"] call _assert;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
