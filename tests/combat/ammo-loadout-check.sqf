// Run: powershell -File tests/tasks/run.ps1 -TestScript tests/combat/ammo-loadout-check.sqf -Port 2497 -TimeoutSeconds 120
// Regression: factory ammunition must match stock native unit inventories.
waitUntil { time > 0 };
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
IVCS_Common_WeaponInfo = createHashMap;
IVCS_Common_MagazineInfo = createHashMap;
IVCS_Common_AmmoInfo = createHashMap;
IVCS_Common_UnitInfo = createHashMap;
IVCS_Common_WeaponAliases = createHashMap;
private _classes = [];
{
    { _classes pushBackUnique _x; } forEach ([_x] call IVCS_Common_getUnitClassesFromGroupConfig);
} forEach [
    configFile >> "CfgGroups" >> "West" >> "BLU_F" >> "Infantry" >> "BUS_InfSquad",
    configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad"
];
private _counts = {
    params ["_weapons"];
    private _usable = 0;
    private _other = 0;
    {
        private _supported = ([_x select 0] call IVCS_Combat_getWeaponProfile) get "supported";
        {
            if (_supported && { ([_x select 0] call IVCS_Combat_getAmmoProfile) get "supported" }) then {
                _usable = _usable + (_x select 1);
            } else { _other = _other + (_x select 1); };
        } forEach (_x select 1);
    } forEach _weapons;
    [_usable,_other]
};

private _inventorySnapshot = {
    params ["_inventory"];
    _inventory params ["_weapons", "_cargo"];
    private _records = _cargo apply { [toLower (_x select 0),_x select 1] };
    { { _records pushBack [toLower (_x select 0),_x select 1]; } forEach (_x select 1); } forEach _weapons;
    _records sort true;
    _records
};
private _nativeGroup = createGroup [west,true];
IVCS_Backpack_TestPassed = 0;
IVCS_Backpack_TestFailed = 0;
private _assert = {
    params ["_ok", "_label"];
    if (_ok) then { IVCS_Backpack_TestPassed = IVCS_Backpack_TestPassed + 1; } else { IVCS_Backpack_TestFailed = IVCS_Backpack_TestFailed + 1; };
    diag_log format ["[IVCS TASK TEST] %1 %2",if (_ok) then { "PASS" } else { "FAIL" },_label];
};
private _ammoSnapshot = {
    params ["_weapons"];
    private _records = [];
    {
        private _weapon = _x select 0;
        { _records pushBack [toLower _weapon,toLower (_x select 0),_x select 1]; } forEach (_x select 1);
    } forEach _weapons;
    _records sort true;
    _records
};
{
    private _class = _x;
    private _factoryWeapons = [_class] call IVCS_Common_getUnitLoadoutInfo;
    private _factory = [_factoryWeapons] call _counts;
    private _unit = _nativeGroup createUnit [_class,[14000,16000,0],[],0,"NONE"];
    _unit disableAI "ALL";
    sleep 0.05;
    private _nativeWeapons = [_unit] call IVCS_Common_getUnitObjectLoadoutInfo;
    private _native = [_nativeWeapons] call _counts;
    private _bag = getText (configFile >> "CfgVehicles" >> _class >> "backpack");
    private _transport = [];
    {
        _transport pushBack [getText (_x >> "magazine"),getNumber (_x >> "count")];
    } forEach (configProperties [configFile >> "CfgVehicles" >> _bag >> "TransportMagazines","isClass _x",true]);
    diag_log format ["[IVCS TASK TEST] AMMO_STOCK_COMPARE %1",[_class,_bag,_factory,_native,_transport]];
    [_factory isEqualTo _native,format ["%1 factory ammunition totals match native stock",_class]] call _assert;
    [([_factoryWeapons] call _ammoSnapshot) isEqualTo ([_nativeWeapons] call _ammoSnapshot),format ["%1 individual magazines match native stock",_class]] call _assert;
    private _factoryInventory = [_class] call IVCS_Common_getUnitInventoryInfo;
    private _nativeInventory = [_unit] call IVCS_Common_getUnitInventoryInfo;
    private _physicalMagazines = (magazinesAmmoFull [_unit,true]) apply { [toLower (_x select 0),_x select 1] };
    _physicalMagazines sort true;
    [([_factoryInventory] call _inventorySnapshot) isEqualTo _physicalMagazines,format ["%1 factory preserves all stock magazines including incompatible cargo",_class]] call _assert;
    [([_nativeInventory] call _inventorySnapshot) isEqualTo _physicalMagazines,format ["%1 live capture preserves every physical magazine exactly once",_class]] call _assert;
    if (_class == "B_soldier_A_F") then {
        private _cargoRecord = (_nativeInventory select 1) select 0;
        (_cargoRecord select 2) pushBack "test-only";
        private _fresh = [_unit] call IVCS_Common_getUnitInventoryInfo;
        [!("test-only" in ((_fresh select 1) select 0 select 2)),"live inventory snapshots own their magazine metadata"] call _assert;
        [!("test-only" in (([_cargoRecord select 0] call IVCS_Common_getMagazineInfo) select 3)),"live snapshot metadata cannot mutate the magazine cache"] call _assert;
        private _legacy = [_class] call IVCS_VirtualSpace_Group_getUnitLoadout;
        [(_legacy apply { [_x select 0,(_x select 1) apply { _x select [0,2] }] }) isEqualTo (_factoryWeapons apply { [_x select 0,(_x select 1) apply { _x select [0,2] }] }),"legacy weapon lookup preserves magazine counts through the shared importer"] call _assert;
    };
    deleteVehicle _unit;
} forEach _classes;
deleteGroup _nativeGroup;

// Physical engine cargo is an independent oracle for expansion, item field names,
// inherited cargo, and category filters. A weapon crate exercises quantities
// even though stock backpacks generally do not contain multiple weapons.
// Avoid support crates here: Arma moves binocular-type TransportItems into
// weapon cargo, while this helper intentionally preserves config categories.
private _flatCounts = {
    params ["_classes"];
    private _counts = createHashMap;
    { private _name = toLower _x; _counts set [_name,(_counts getOrDefault [_name,0]) + 1]; } forEach _classes;
    private _records = (keys _counts) apply { [_x,_counts get _x] };
    _records sort true;
    _records
};
private _engineCounts = {
    params ["_cargo"];
    private _records = [];
    { if (((_cargo select 1) select _forEachIndex) > 0) then { _records pushBack [toLower _x,(_cargo select 1) select _forEachIndex]; }; } forEach (_cargo select 0);
    _records sort true;
    _records
};
{
    private _class = _x;
    private _object = createVehicle [_class,[14200,16000,0],[],0,"CAN_COLLIDE"];
    sleep 0.05;
    private _nativeCargo = [getItemCargo _object,getMagazineCargo _object,getWeaponCargo _object] apply { [_x] call _engineCounts };
    private _imported = [_class,true,true,true] call IVCS_Common_getBackpackCargo;
    {
        private _actual = [_x] call _flatCounts;
        if !(_actual isEqualTo (_nativeCargo select _forEachIndex)) then { diag_log format ["[IVCS TASK TEST] CARGO_MISMATCH %1",[_class,_forEachIndex,_actual,_nativeCargo select _forEachIndex]]; };
        [_actual isEqualTo (_nativeCargo select _forEachIndex),format ["%1 cargo category %2 matches physical engine inventory",_class,_forEachIndex]] call _assert;
    } forEach _imported;
    if (_class == "B_AssaultPack_mcamo_Ammo") then {
        for "_mask" from 0 to 7 do {
            private _flags = [_mask mod 2 == 1, floor (_mask / 2) mod 2 == 1, floor (_mask / 4) mod 2 == 1];
            private _filtered = [_class,_flags select 0,_flags select 1,_flags select 2] call IVCS_Common_getBackpackCargo;
            private _expected = [];
            { _expected pushBack (if (_x) then { _nativeCargo select _forEachIndex } else { [] }); } forEach _flags;
            [(_filtered apply { [_x] call _flatCounts }) isEqualTo _expected,format ["include flags %1 select only requested cargo categories",_mask]] call _assert;
        };
        [({ _x == "30Rnd_65x39_caseless_mag" } count (_imported select 1)) == 6,"ammo backpack contains all six configured rifle magazines"] call _assert;
    };
    deleteVehicle _object;
} forEach ["B_AssaultPack_mcamo_Ammo","B_FieldPack_cbr_Ammo","B_AssaultPack_rgr_Medic","B_AssaultPack_mcamo","Box_NATO_Wps_F"];
[(["",true,true,true] call IVCS_Common_getBackpackCargo) isEqualTo [[],[],[]],"absent backpack has no cargo"] call _assert;
[(["IVCS_missing_backpack",true,true,true] call IVCS_Common_getBackpackCargo) isEqualTo [[],[],[]],"unknown backpack config has no cargo"] call _assert;

diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",IVCS_Backpack_TestPassed,IVCS_Backpack_TestFailed];
