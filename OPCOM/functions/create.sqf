params ["_name","_side","_faction","_position",["_debug", false]];

private _initMap = {
    _this setvariable ["group", []];
    _this setvariable ["car", []];
    _this setvariable ["truck", []];
    _this setvariable ["armored", []];
    _this setvariable ["tank", []];
    _this setvariable ["antiair", []];
    _this setvariable ["artillery", []];
    _this setvariable ["ship", []];
    _this setvariable ["helicopter", []];
    _this setvariable ["plane", []];
    _this setvariable ["staticWeapon", []];
};

private _idleForces = [] call CBA_fnc_createNamespace;
private _activeForces = [] call CBA_fnc_createNamespace;

_idleForces call _initMap;
_activeForces call _initMap;

private _opcom = [] call CBA_fnc_createNamespace;
_opcom setvariable ["debug", _debug];
_opcom setvariable ["name", _name];
_opcom setvariable ["side", _side];
_opcom setvariable ["faction", _faction];
_opcom setvariable ["position", _position];

_opcom setvariable ["entityInfoMap", [] call CBA_fnc_createNamespace]; // [idle/active, orders]
_opcom setvariable ["allEntities", []];
_opcom setvariable ["idleEntities", _idleForces];
_opcom setvariable ["activeEntities", _activeForces];

_opcom setvariable ["nextObjectiveID", 0];
_opcom setvariable ["objectives", [] call CBA_fnc_createNamespace];
_opcom setvariable ["sortedObjectives", []];

_opcom setvariable ["nextOrderIDNum", 0];
_opcom setvariable ["pendingOrders", []];
_opcom setvariable ["orders", [] call CBA_fnc_createNamespace];
_opcom setvariable ["entityOrders", [] call CBA_fnc_createNamespace];

_opcom setvariable ["messageQueue", []];

// customizable properties
private _garrisonGroupCounts = [] call CBA_fnc_createNamespace;
_garrisonGroupCounts setvariable ["town", 3];
_garrisonGroupCounts setvariable ["base", 4];
_garrisonGroupCounts setvariable ["airfield", 6];
_garrisonGroupCounts setvariable ["default", 2];

_opcom setvariable ["garrisonGroupCounts", _garrisonGroupCounts];
//

["IVCS_VirtualSpace_entityUnregistered", { [_thisArgs, _this] call IVCS_OPCOM_onEntityUnregistered }, _name] call CBA_fnc_addEventHandlerArgs;

private _opcomFSM = [_opcom] call IVCS_OPCOM_createFSM;
_opcom setvariable ["fsm", _opcomFSM];

IVCS_OPCOMs setvariable [_name, _opcom];

private _tacom = [_opcom] call IVCS_TACOM_create;
_opcom setvariable ["tacom", _tacom];

_opcom