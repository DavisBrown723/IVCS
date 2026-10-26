waitUntil {time>0};
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
IVCS_Common_WeaponInfo=createHashMap;IVCS_Common_MagazineInfo=createHashMap;IVCS_Common_AmmoInfo=createHashMap;IVCS_Common_UnitInfo=createHashMap;IVCS_Common_WeaponAliases=createHashMap;
IVCS_Common_VehicleConfigInventories=createHashMap;IVCS_Common_VehicleTurrets=[] call IVCS_Common_getAllVehicleTurretsFromConfig;
IVCS_Paths_Generator=createHashMapFromArray [["requestQueue",[]],["currentRequest",[]]];
IVCS_VirtualSpace_Controller=[false] call IVCS_VirtualSpace_createController;
removeMissionEventHandler ["EachFrame",IVCS_VirtualSpace_Controller get "onFrameHandlerID"];
west setFriend [east,0];east setFriend [west,0];
private _passed=0;private _failed=0;
private _assert={params ["_ok","_label"];if (_ok) then {_passed=_passed+1} else {_failed=_failed+1};diag_log format ["[IVCS TASK TEST] %1 %2",if (_ok) then {"PASS"} else {"FAIL"},_label]};
private _combat=IVCS_VirtualSpace_Controller get "combat";
private _make={params [["_class","O_Soldier_F"],["_side","EAST"],["_count",4],["_pos",[14500,16400,0]]];private _units=[];for "_i" from 0 to (_count-1) do {_units pushBack ([_class,format ["u%1",_i]] call IVCS_VirtualSpace_Group_createUnit)};[_side,"OPF_F",+_pos,_units] call IVCS_VirtualSpace_Group_createEntity};
private _heli={params [["_class","B_Heli_Attack_01_dynamicLoadout_F"],["_pos",[15100,16400,100]]];private _v=[_class,+_pos] call IVCS_VirtualSpace_Vehicle_createEntity;private _count=0;{if ((_x select 0)!="Cargo") then {_count=_count+count (_x select 1)}} forEach (_v get "seats");private _crew=["B_helicrew_F","WEST",_count,+_pos] call _make;[_crew,_v] call IVCS_VirtualSpace_Group_assignVehicle;[_v,_crew]};
private _order={params ["_crew",["_role","ATTACK"],["_mode","YELLOW"],["_behavior","AWARE"]];private _wp=[[16000,16400,0],"MOVE",[["airAttackCenter",[14500,16400,0]],["airCombatRole",_role],["combatMode",_mode],["behavior",_behavior]]] call IVCS_VirtualSpace_createEntityWaypoint;[_crew,_wp] call IVCS_VirtualSpace_entityAddWaypoint;_wp};
private _clean={{if (!isNil {[_x get "id"] call IVCS_VirtualSpace_getEntity}) then {if (_x get "active") then {[_x] call (missionNamespace getVariable (_x get "despawn"))};[_x] call IVCS_VirtualSpace_unregisterEntity}} forEach _this};
private _ammo={params ["_v"];private _n=0;{{_n=_n+(_x select 1)} forEach (_x select 2);{_n=_n+(_x select 2)} forEach (_x select 3)} forEach (_v get "turrets");_n};
private _ledger={params ["_v"];private _result=[];{private _path=_x select 0;{_result pushBack [str _path,_x select 0,_x select 1]} forEach (_x select 2);{_result pushBack [_x select 0,_x select 1,_x select 2]} forEach (_x select 3)} forEach (_v get "turrets");_result sort true;_result};

private _pair=[] call _heli;_pair params ["_h","_crew"];
private _wp=nil;
private _checkOrders={
    params ["_label"];
    private _current=[];private _found=[_crew] call IVCS_VirtualSpace_getEntityCurrentWaypoint;if (!isNil "_found") then {_current=_found};
    [([_h] call IVCS_Flight_Before_IVCS_Combat_getHelicopterPolicy) isEqualTo ([_h,_crew,_current] call IVCS_Combat_getHelicopterPolicy),_label+" shared policy matches baseline"] call _assert;
    [([_h] call IVCS_Flight_Before_IVCS_Combat_getHelicopterAttackArea) isEqualTo ([_h,_current] call IVCS_Combat_getHelicopterAttackArea),_label+" shared area matches baseline"] call _assert;
    [([_h] call IVCS_Combat_getHelicopterPolicy) isEqualTo ([_h,_crew,_current] call IVCS_Combat_getHelicopterPolicy),_label+" legacy policy caller stays equivalent"] call _assert;
    [([_h] call IVCS_Combat_getHelicopterAttackArea) isEqualTo ([_h,_current] call IVCS_Combat_getHelicopterAttackArea),_label+" legacy area caller stays equivalent"] call _assert;
};
["no waypoint"] call _checkOrders;
_wp=[_crew] call _order;
{
    _wp set ["combatMode",_x select 0];_wp set ["behavior",_x select 1];_wp set ["speed",_x select 2];_wp set ["airCombatRole",_x select 3];
    [str _x] call _checkOrders;
} forEach [
    ["YELLOW","AWARE","NORMAL","ATTACK"],["BLUE","CARELESS","LIMITED","ATTACK"],
    ["GREEN","COMBAT","FULL","TRANSPORT"],["RED","STEALTH","FAST","ATTACK"],
    ["NO CHANGE","UNCHANGED","UNCHANGED","ATTACK"]
];
_crew set ["airWaypointSettings",["BLUE","CARELESS","LIMITED"]];
["changed inherited settings"] call _checkOrders;
_wp set ["airAttackCenter",[14550,16410,0]];_wp set ["airAttackRadius",350];
["changed objective area"] call _checkOrders;
[_h,_crew] call _clean;

// Compare flight results against archived update code over movement and stationary cases.
{
    _x params ["_role","_threat","_speed","_dt"];
    private _snapshots=[];
    {
        private _update=_x;
        _pair=[] call _heli;_pair params ["_h","_crew"];
        _wp=[_crew] call _order;_wp set ["speed",_speed];
        private _a=[] call _make;
        private _e=[_a,_h] call IVCS_Combat_start;
        _wp set ["airCombatRole",_role];
        if (_threat) then {
            _h set ["airThreat",[[14500,16400,0],IVCS_SimulationTime+1000]];
            _h set ["airEvasionPoint",[15300,16200,100]];
        };
        private _result=[_crew,_h,_dt] call _update;
        private _again=[_crew,_h,0.1] call _update;
        _snapshots pushBack [_result,_again,+(_h get "position"),+(_crew get "position"),+(_h get "flightVelocity"),_h get "flightHeading",_h get "engineOn",_h get "airMovementOverride",_e get "mode"];
        [_a,_h,_crew] call _clean;
    } forEach [IVCS_Flight_Before_IVCS_Combat_updateHelicopter,IVCS_Combat_updateHelicopter];
    [(_snapshots select 0) isEqualTo (_snapshots select 1),format ["flight matches baseline: %1 threat=%2 speed=%3 dt=%4",_role,_threat,_speed,_dt]] call _assert;
} forEach [
    ["ATTACK",false,"NORMAL",0],["ATTACK",false,"LIMITED",0.1],["ATTACK",false,"FULL",1],
    ["ATTACK",true,"NORMAL",0],["ATTACK",true,"LIMITED",0.1],["ATTACK",true,"FULL",1],
    ["ATTACK",true,"FAST",100],["TRANSPORT",true,"NORMAL",100]
];

_pair=[] call _heli;_pair params ["_h","_crew"];_wp=[_crew] call _order;
private _a=[] call _make;private _e=[_a,_h] call IVCS_Combat_start;
_h set ["airThreat",[[14500,16400,0],IVCS_SimulationTime+1000]];
_h set ["airEvasionPoint",[15300,16200,100]];
[_crew,_h,100] call IVCS_Combat_updateHelicopter;
private _atRest=+(_h get "position");
private _waypointQueries=0;private _passQueries=0;private _vehicleWrites=0;private _crewWrites=0;
private _getWaypoint=IVCS_VirtualSpace_getEntityCurrentWaypoint;
private _getPass=IVCS_Combat_getHelicopterPass;private _setPosition=IVCS_VirtualSpace_setEntityPosition;
IVCS_VirtualSpace_getEntityCurrentWaypoint={_waypointQueries=_waypointQueries+1;_this call _getWaypoint};
IVCS_Combat_getHelicopterPass={_passQueries=_passQueries+1;_this call _getPass};
IVCS_VirtualSpace_setEntityPosition={if ((_this select 0) isEqualRef _h) then {_vehicleWrites=_vehicleWrites+1};if ((_this select 0) isEqualRef _crew) then {_crewWrites=_crewWrites+1};_this call _setPosition};
[_crew,_h,0.1] call IVCS_Combat_updateHelicopter;
[_waypointQueries==1,"flight resolves the current waypoint once per ordinary update"] call _assert;
[_passQueries==0,"virtual evasion skips the unused offensive pass query"] call _assert;
[_vehicleWrites==0 && {_crewWrites==1},"stationary flight skips its own position write and still synchronizes the crew"] call _assert;
[(_h get "position") isEqualTo _atRest && {(_h get "flightVelocity") isEqualTo [0,0,0]},"stationary evasion retains position with zero velocity"] call _assert;
IVCS_VirtualSpace_getEntityCurrentWaypoint=_getWaypoint;IVCS_Combat_getHelicopterPass=_getPass;IVCS_VirtualSpace_setEntityPosition=_setPosition;
[_crew,[14000,16400,0]] call IVCS_VirtualSpace_setEntityPosition;
[_crew,_h,0.1] call IVCS_Combat_updateHelicopter;
[(_crew get "position") isEqualTo _atRest,"stationary aircraft repairs an out-of-sync crew position"] call _assert;
_h set ["airThreat",[]];
_passQueries=0;IVCS_Combat_getHelicopterPass={_passQueries=_passQueries+1;_this call _getPass};
[_crew,_h,0.1] call IVCS_Combat_updateHelicopter;
[_passQueries==1,"expired evasion immediately resumes offensive pass queries"] call _assert;
IVCS_Combat_getHelicopterPass=_getPass;
// Changes to the order are read immediately even while aircraft motion has stopped.
_h set ["airThreat",[[14500,16400,0],IVCS_SimulationTime+1000]];
_wp set ["airAttackRadius",50];
[_crew,_h,0.1] call IVCS_Combat_updateHelicopter;
[(_e get "mode")=="finished" && {(_e get "reason")=="area"},"stationary evasion still enforces a changed attack boundary"] call _assert;
[_a,_h,_crew] call _clean;

// Stationary flight must still react to health changes and retain the old grid position.
_pair=[] call _heli;_pair params ["_h","_crew"];_wp=[_crew] call _order;
_h set ["airThreat",[[14500,16400,0],IVCS_SimulationTime+1000]];_h set ["airEvasionPoint",+(_h get "position")];
[_crew,_h,0.1] call IVCS_Combat_updateHelicopter;
private _oldPosition=_h get "position";private _oldAltitude=_oldPosition select 2;
_h set ["speedPerSecond",0];[_crew,_h,0.1] call IVCS_Combat_updateHelicopter;
[(_h get "position" select 2)<_oldAltitude && {(_h get "flightVelocity" select 2)<0},"stationary aircraft still descend immediately after mobility failure"] call _assert;
[(_oldPosition select 2)==_oldAltitude,"forced descent does not mutate the position retained by the old grid entry"] call _assert;
[_h,_crew] call _clean;
[count ((_combat get "engagements"))==0,"flight optimization fixtures release all engagements"] call _assert;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
