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

private _targets=[
    ["B_Heli_Attack_01_dynamicLoadout_F",[14500,16400,100]] call IVCS_VirtualSpace_Vehicle_createEntity,
    ["O_MBT_02_cannon_F",[14500,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity,
    ["O_Truck_03_transport_F",[14500,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity
];
{
    private _unit=[_x,"probe"] call IVCS_VirtualSpace_Group_createUnit;
    private _inventory=str (_unit get "weapons");
    {
        private _profile=[_x get "class"] call IVCS_Combat_getVehicleProfile;
        {
            private _range=_x;
            {
                private _only=_x;private _oldCache=createHashMap;private _newCache=createHashMap;
                private _old=[_unit,_oldCache,_profile,_range,_only] call IVCS_Resolution_Before_IVCS_Combat_getVehicleShot;
                private _new=[_unit,_newCache,_profile,_range,_only] call IVCS_Combat_getVehicleShot;
                [_old isEqualTo _new,format ["selector matches baseline %1/%2 range=%3 AA=%4",_unit get "class",_profile get "class",_range,_only]] call _assert;
                if (_new isNotEqualTo []) then {
                    [(_old select 0) isEqualRef (_new select 0),"filtered selection retains the actual owned magazine record"] call _assert;
                };
                _old=[_unit,_oldCache,_profile,_range,_only] call IVCS_Resolution_Before_IVCS_Combat_getVehicleShot;
                _new=[_unit,_newCache,_profile,_range,_only] call IVCS_Combat_getVehicleShot;
                [_old isEqualTo _new,"warm selector retains the same firing choice"] call _assert;
            } forEach [false,true];
        } forEach [0,5,35,36,100,300,301,750,751];
    } forEach _targets;
    [_inventory isEqualTo str (_unit get "weapons"),"selector probes never consume ammunition"] call _assert;
} forEach ["O_Soldier_F","O_Soldier_AA_F","O_Soldier_AT_F","O_Soldier_LAT_F","O_Soldier_GL_F","B_Soldier_AA_F"];
private _unit=["O_Soldier_F","rifle"] call IVCS_VirtualSpace_Group_createUnit;
private _profile=[(_targets select 0) get "class"] call IVCS_Combat_getVehicleProfile;
private _oldCache=createHashMap;private _newCache=createHashMap;
[_unit,_oldCache,_profile,600] call IVCS_Resolution_Before_IVCS_Combat_getVehicleShot;
[_unit,_newCache,_profile,600] call IVCS_Combat_getVehicleShot;
[count _oldCache>0 && {count _newCache==0},"distant riflemen skip full weapon-selection state construction"] call _assert;
_unit=["O_Soldier_AA_F","aa"] call IVCS_VirtualSpace_Group_createUnit;
private _launcher=(_unit get "weapons") select {getNumber(configFile>>"CfgWeapons">>(_x select 0)>>"type")==4} select 0;
IVCS_Combat_WeaponProfiles deleteAt (_launcher select 0);
private _selected=[_unit,createHashMap,_profile,600,true] call IVCS_Combat_getVehicleShot;
[_selected isNotEqualTo [],"an uncached AA weapon profile initializes before filtering"] call _assert;
(_selected select 0) set [1,0];
private _old=[_unit,createHashMap,_profile,600,true] call IVCS_Resolution_Before_IVCS_Combat_getVehicleShot;
private _new=[_unit,createHashMap,_profile,600,true] call IVCS_Combat_getVehicleShot;
[_old isEqualTo _new,"emptying a selected magazine immediately changes the next choice"] call _assert;
{(_x select 1) resize 0} forEach (_unit get "weapons");
[([_unit,createHashMap,_profile,600,true] call IVCS_Combat_getVehicleShot) isEqualTo [],"an AA-capable weapon with no rounds cannot fire"] call _assert;
_combat set ["range",10];
_old=[_unit,createHashMap,_profile,36,false] call IVCS_Resolution_Before_IVCS_Combat_getVehicleShot;
_new=[_unit,createHashMap,_profile,36,false] call IVCS_Combat_getVehicleShot;
[_old isEqualTo _new,"changed ground range preserves air selection"] call _assert;
_combat set ["range",300];
_targets call _clean;

// Identical seeded crew damage, including duplicate owners, cargo, deaths and empty owners.
{
    private _class=_x;
    {
        private _lethal=_x;
        {
            private _roll=_x;private _snapshots=[];
            {
                private _before=_x;
                private _v=[_class,[14500,16400,100]] call IVCS_VirtualSpace_Vehicle_createEntity;
                private _g=["O_crew_F","EAST",3] call _make;[_g,_v] call IVCS_VirtualSpace_Group_assignVehicle;
                private _cargo=["O_Soldier_F","EAST",2] call _make;
                if (_class=="O_Truck_03_transport_F") then {
                    [_cargo,_v] call IVCS_VirtualSpace_Group_assignAsVehicleCargo;
                    (_v get "entitiesInCargo") append [_g get "id",_cargo get "id",_cargo get "id"];
                };
                private _units=((_g get "units")+(_cargo get "units")) select [0];
                private _ammo=createHashMapFromArray [["antiArmor",_roll>0.25]];
                private _count=if (_before) then {[_v,_ammo,0.4,_lethal,_roll] call IVCS_Resolution_Before_IVCS_Combat_damageCrew} else {
                    [_v,_ammo,0.4,_lethal,_roll,[_class] call IVCS_Combat_getVehicleProfile] call IVCS_Combat_damageCrew
                };
                _snapshots pushBack [_count,_units apply {[_x get "damage",+(_x get "hitpoints"),(_x get "vehicleAssignment") isEqualTo []]}];
                [_g,_cargo,_v] call _clean;
            } forEach [true,false];
            [(_snapshots select 0) isEqualTo (_snapshots select 1),format ["crew damage matches seeded baseline %1 lethal=%2 roll=%3",_class,_lethal,_roll]] call _assert;
        } forEach [0,0.2,0.5,0.999];
    } forEach [false,true];
} forEach ["O_Truck_03_transport_F","O_MBT_02_cannon_F","B_Heli_Attack_01_dynamicLoadout_F"];
private _v=["O_Truck_03_transport_F",[14500,16400,0]] call IVCS_VirtualSpace_Vehicle_createEntity;
[([_v,createHashMapFromArray [["antiArmor",true]],1,true,0.5] call IVCS_Combat_damageCrew)==0,"unoccupied vehicles do not query crew profiles"] call _assert;
[_v] call _clean;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
