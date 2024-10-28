params ["_vehicleClass", "_position"];

if (_vehicleClass iskindof "Man") exitwith {
    diag_log format ["IVCS: createVehicleEntity - Cannot create vehicle entity from non-vehicle class"];
};

private _vehicleConfig = configfile >> "CfgVehicles" >> _vehicleClass;

private _vehicleType = [_vehicleClass] call IVCS_Common_findUnitType;
private _maxSpeed = getnumber (_vehicleConfig >> "maxSpeed");

private _hitpoints = [_vehicleConfig >> "HitPoints", 0] call BIS_fnc_returnChildren;
private _side = [_vehicleClass] call IVCS_Common_getVehicleSide;

private _vehicleEntity = createHashMapFromArray [
    ["timeLastUpdate", diag_tickTime],
    ["delayedInitComplete", false],
    ["active", false],
    ["class", _vehicleClass],
    ["vehicleType", _vehicleType],
    ["position", _position],
    ["side", _side],
    ["engineOn", false],

    ["assignedEntity", ""],
    ["commandingEntity", ""],
    ["entitiesInCargo", []],

    ["object", objNull],
    ["speedPerSecond", round (_maxSpeed * 0.15)],
    ["hitpoints", _hitpoints apply {[configname _x, 0]}]
];

private _seatCount = 0;
private _vehicleSeats = [_vehicleClass] call IVCS_Common_findVehicleSeats;
private _seatAssignments = _vehicleSeats apply {
    _x params ["_seatType","_seatPaths"];

    _seatPaths = _seatPaths apply { [_x, ""] };
    _seatCount = _seatCount + (count _seatPaths);

    [_seatType, _seatPaths]
};
_vehicleEntity set ["seatCount", _seatCount];
_vehicleEntity set ["seats", _seatAssignments];

// get weapon info

private _weapons = [_vehicleClass] call IVCS_Common_getVehicleWeapons;
private _weaponsInfo = _weapons apply {
    _x params ["_turretPath","_turretWeaponsInfo"];

    _turretWeaponsInfo = _turretWeaponsInfo apply {
        _x params ["_weapon","_weaponMagazines"];

        _weaponMagazines = _weaponMagazines apply {
            private _magazineInfo = [_x] call IVCS_Common_getMagazineInfo;
            private _magazineAmmoCount = _magazineInfo select 1;
            [_x, _magazineAmmoCount]
        };

        [_weapon, _weaponMagazines]
    };

    [_turretPath, _turretWeaponsInfo]
};
_vehicleEntity setvariable ["weapons", _weaponsInfo];

// get pylon info

private _vehiclePylonInfo = [_vehicleClass] call IVCS_Common_getVehiclePylons;
private _vehiclePylons = _vehiclePylonInfo apply {
    private _pylonName = _x select 0;
    private _pylonMagazine = _x select 1;

    private _magazineInfo = [_pylonMagazine] call IVCS_Common_getMagazineInfo;
    private _magazineAmmoCount = _magazineInfo select 1;

    [_pylonName, _pylonMagazine, _magazineAmmoCount]
};
_vehicleEntity setvariable ["pylons", _vehiclePylons];

// set type specific vars

if (_vehicleType == "uav") then {
    _vehicleEntity set ["entityType", "uav"];

    // _vehicleEntity set ["update", "IVCS_VirtualSpace_Uav_update"];
    // _vehicleEntity set ["spawn", "IVCS_VirtualSpace_Uav_spawn"];
    // _vehicleEntity set ["despawn", "IVCS_VirtualSpace_Uav_despawn"];
    // _vehicleEntity set ["unregister", "IVCS_VirtualSpace_Uav_unregister"];
    _vehicleEntity set ["update", "IVCS_VirtualSpace_Vehicle_update"];
    _vehicleEntity set ["spawn", "IVCS_VirtualSpace_Vehicle_spawn"];
    _vehicleEntity set ["despawn", "IVCS_VirtualSpace_Vehicle_despawn"];
    _vehicleEntity set ["unregister", "IVCS_VirtualSpace_Vehicle_unregister"];
} else {
    _vehicleEntity set ["entityType", "vehicle"];

    _vehicleEntity set ["update", "IVCS_VirtualSpace_Vehicle_update"];
    _vehicleEntity set ["spawn", "IVCS_VirtualSpace_Vehicle_spawn"];
    _vehicleEntity set ["despawn", "IVCS_VirtualSpace_Vehicle_despawn"];
    _vehicleEntity set ["unregister", "IVCS_VirtualSpace_Vehicle_unregister"];
};

[_vehicleEntity] call IVCS_VirtualSpace_registerEntity;

private _debug = IVCS_VirtualSpace_Controller get "debug";
private _debugMarker = if (_debug) then {
    [_vehicleEntity] call IVCS_VirtualSpace_createEntityDebugMarker;
} else {
    ""
};
_vehicleEntity set ["debugMarker", _debugMarker];

_vehicleEntity