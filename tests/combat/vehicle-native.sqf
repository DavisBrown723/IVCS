// Native frontal impacts and blast probes. Logs only actual changes, not a virtual formula.
waitUntil { time > 0 };
private _passed=0; private _failed=0;
private _assert={params ["_ok","_label"];if (_ok) then {_passed=_passed+1} else {_failed=_failed+1};diag_log format ["[IVCS TASK TEST] %1 %2",if (_ok) then {"PASS"} else {"FAIL"},_label]};
private _vehicles=["C_Offroad_01_F","O_MRAP_02_F","O_APC_Wheeled_02_rcws_v2_F","O_MBT_02_cannon_F"];
private _magazines=["30Rnd_65x39_caseless_mag","NLAW_F","RPG32_F","Titan_AT","1Rnd_HE_Grenade_shell","HandGrenade","DemoCharge_Remote_Mag","ATMine_Range_Mag"];
{
    private _class=_x;
    {
        private _mag=_x;
        private _mc=configFile >> "CfgMagazines" >> _mag;
        private _ammoClass=getText (_mc >> "ammo");
        private _ac=configFile >> "CfgAmmo" >> _ammoClass;
        private _simulation=toLower getText (_ac >> "simulation");
        private _explosive=_mag in ["HandGrenade","DemoCharge_Remote_Mag","ATMine_Range_Mag"];
        for "_trial" from 1 to 3 do {
            private _target=createVehicle [_class,[14500,16400,0],[],0,"CAN_COLLIDE"];
            _target setDir 0; _target allowDamage true; _target engineOn false;
            sleep 0.2;
            private _bounds=boundingBoxReal _target;
            private _low=(_bounds select 0) select 2;
            private _high=(_bounds select 1) select 2;
            private _aim=(getPosATL _target) vectorAdd [0,0,0.8];
            private _projectile=objNull;
            if (_explosive) then {
                private _blast=(getPosATL _target) vectorAdd [0,0.5,0.2];
                _projectile=createVehicle [_ammoClass,_blast,[],0,"CAN_COLLIDE"];
                triggerAmmo _projectile;
            } else {
                private _origin=_aim vectorAdd [0,15,0];
                private _ray=lineIntersectsSurfaces [ATLToASL _origin,ATLToASL _aim,objNull,objNull,true,1,"FIRE"];
                diag_log format ["[IVCS NATIVE RAY] %1",[_class,_mag,_trial,_ray isNotEqualTo [] && { ((_ray select 0) select 2) == _target }]];
                _projectile=createVehicle [_ammoClass,_origin,[],0,"CAN_COLLIDE"];
                _projectile setPosATL _origin;
                _projectile setVectorDirAndUp [[0,-1,0],[0,0,1]];
                _projectile setVelocity [0,-(getNumber (_ac >> "maxSpeed") max (getNumber (_mc >> "initSpeed") max 200)),0];
            };
            sleep 1.2;
            private _hp=getAllHitPointsDamage _target;
            private _changed=[];
            { if (((_hp select 2) select _forEachIndex)>0 && { _x select [0,1] != "#" }) then {_changed pushBack [_x,(_hp select 2) select _forEachIndex]}; } forEach (_hp select 0);
            diag_log format ["[IVCS NATIVE VEHICLE] %1",[_class,_mag,_trial,damage _target,alive _target,_changed,_simulation,getNumber (_ac >> "hit"),getText (_ac >> "submunitionAmmo")]];
            deleteVehicle _projectile; deleteVehicle _target;
            sleep 0.05;
        };
    } forEach _magazines;
} forEach _vehicles;
[true,"native impact observations completed"] call _assert;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
