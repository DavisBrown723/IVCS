params ["_unitClasses", "_side", "_faction", ["_position", [0,0,0]]];

switch (true) do {
    case (_unitClasses isequaltype configNull): {
        private _groupConfig = _unitClasses;
        private _groupUnitSubClasses = _groupConfig call BIS_fnc_getCfgSubClasses;
        _unitClasses = _groupUnitSubClasses apply { getText (_groupConfig  >> _x >> "vehicle") };
    };
    // case (_unitClasses isequaltype ""): {
    //     private _configSide = if (_side == "GUER") then {"INDEP"} else {_side};
    //     private _groupConfig = configfile >> _configSide >> _unitClasses;
    //     private _groupUnitSubClasses = _groupConfig call BIS_fnc_getCfgSubClasses;
    //     _unitClasses = _groupUnitSubClasses apply { getText (_groupConfig  >> _x >> "vehicle") };
    // };
};

// sort unit classes by type
// create infantry units
// create vehicle entities

private _units = [];
private _vehicleEntities = [];
{
    private _unitClass = _x;

    if (_unitClass iskindof "Man") then {
        private _unit = [_unitClass] call IVCS_VirtualSpace_createEntityUnit;

        _units pushback _unit;
    } else {
        private _vehicleEntity = [_unitClass, _position] call IVCS_VirtualSpace_createVehicleEntity;

        _vehicleEntities pushback _vehicleEntity;
    };
} foreach _unitClasses;

// create group entity
// assign vehicles to group

private "_groupEntity";
if (count _units > 0) then {
    _groupEntity = [_side, _faction, _position, _units] call IVCS_VirtualSpace_createGroupEntity;
};

if (!isnil "_groupEntity") then {
    [_groupEntity, _vehicleEntities];
} else {
    [objNull, _vehicleEntities];
}