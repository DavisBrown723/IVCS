params ["_vehicleClass", "_position"];

if (_vehicleClass iskindof "Man") exitwith {
    diag_log format ["IVCS: createVehicleEntity - Cannot create vehicle entity from non-vehicle class"];
};

private _vehicleConfig = configfile >> "CfgVehicles" >> _vehicleClass;

private _vehicleType = [_vehicleClass] call IVCS_Common_findUnitType;
private _maxSpeed = getnumber (_vehicleConfig >> "maxSpeed");

private _profile = [_vehicleClass] call IVCS_Combat_getVehicleProfile;
private _side = [_vehicleClass] call IVCS_Common_getVehicleSide;

private _vehicleEntity = createHashMapFromArray [
    ["timeLastUpdate", IVCS_SimulationTime],
    ["delayedInitComplete", false],

    ["entityType", "vehicle"],
    ["vehicleType", _vehicleType],
    ["class", _vehicleClass],
    ["active", false],
    ["simulationTransition", false],
    ["combatID", ""],
    ["nextCombatScan", 0],
    ["combatStartedAt", 0],
    ["damage", 0],
    ["position", _position],
    ["side", _side],
    ["engineOn",_vehicleClass isKindOf "Air" && { (_position param [2,0]) > 20 }],
    ["nativeCrew",[]],
    ["turretFireDelays",createHashMap],
    ["combatCooldowns",createHashMap],
    ["airPassCrew",[]], ["airPassModes",[]], ["nativeAirTarget",objNull], ["nativeAirDestination",[]], ["airThreat",[]], ["airEvasionPoint",[]], ["airMovementOverride",false],
    ["flightRestorePending",false], ["flightHeading",0], ["flightVelocity",[0,0,0]],

    ["assignedEntity", ""],
    ["commandingEntity", ""],
    ["entitiesInCargo", []],

    ["speedPerSecond", round (_maxSpeed * 0.15)],
    ["baseSpeedPerSecond",round (_maxSpeed * 0.15)],
    ["hitpoints",(_profile get "names") apply {[_x,0]}],

    ["object", objNull]
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

private _vehicleInventory = [_vehicleClass] call IVCS_Common_getContainerInventoryFromConfig;
_vehicleEntity set ["inventory", _vehicleInventory];

private _vehicleTurrets = [_vehicleClass] call IVCS_VirtualSpace_Vehicle_getTurretsLoadout;
_vehicleEntity set ["turrets", _vehicleTurrets];
{
    {[_x] call IVCS_Combat_getTurretWeaponProfile} forEach (_x select 1);
    {if ((_x select 1)!="") then {[getText (configFile >> "CfgMagazines" >> (_x select 1) >> "pylonWeapon")] call IVCS_Combat_getTurretWeaponProfile}} forEach (_x select 3);
} forEach _vehicleTurrets;

// set type specific vars

if (getNumber (_vehicleConfig >> "isUav") > 0) then {
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
    _vehicleEntity set ["update", "IVCS_VirtualSpace_Vehicle_update"];
    _vehicleEntity set ["spawn", "IVCS_VirtualSpace_Vehicle_spawn"];
    _vehicleEntity set ["despawn", "IVCS_VirtualSpace_Vehicle_despawn"];
    _vehicleEntity set ["unregister", "IVCS_VirtualSpace_Vehicle_unregister"];
};

[_vehicleEntity] call IVCS_VirtualSpace_registerEntity;
if (_vehicleType=="helicopter") then {((IVCS_VirtualSpace_Controller get "combat") get "helicopters") set [_vehicleEntity get "id",_vehicleEntity]};

private _debug = IVCS_VirtualSpace_Controller get "debug";
private _debugMarker = if (_debug) then {
    [_vehicleEntity] call IVCS_VirtualSpace_createEntityDebugMarker;
} else {
    ""
};
_vehicleEntity set ["debugMarker", _debugMarker];

_vehicleEntity