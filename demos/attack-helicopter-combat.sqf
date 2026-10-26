// Run on the server: [] execVM "IVCS\demos\attack-helicopter-combat.sqf";
// Optional target position and helicopter approach heading:
// [[14500,16400,0],90] execVM "IVCS\demos\attack-helicopter-combat.sqf";
params [["_targetPosition", []], ["_heading", 90]];
if (!isServer) exitWith { hint "Run the IVCS attack helicopter demo on the server."; };
if (isNil "IVCS_VirtualSpace_Controller" || { isNil "IVCS_Paths_Generator" }) exitWith {
    hint "Start IVCS before running the attack helicopter demo.";
};
if (_targetPosition isEqualTo []) then {
    private _observer = if (!isNull player) then { player } else { allPlayers param [0, objNull] };
    if (!isNull _observer) then { _targetPosition = (getPosATL _observer) getPos [400, getDir _observer]; };
};
if (_targetPosition isEqualTo []) exitWith {
    diag_log "[IVCS DEMO] No player available: supply a target position.";
};
_targetPosition = [_targetPosition select 0, _targetPosition select 1, 0];
private _helicopterPosition = _targetPosition getPos [600, _heading + 180];
_helicopterPosition set [2, 100];
if (surfaceIsWater _targetPosition) exitWith {
    hint "Choose a land position for the OPFOR infantry group.";
};

call compile preprocessFileLineNumbers "IVCS\demos\stop-attack-helicopter-combat.sqf";
IVCS_Demo_AttackHelicopterCombatScript = _thisScript;
IVCS_Demo_AttackHelicopterCombatIDs = [];
IVCS_Demo_AttackHelicopterCombatMarkers = [];

private _redConfig = configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad";
private _redGroup = ([_redConfig, "EAST", "OPF_F", _targetPosition] call IVCS_VirtualSpace_createEntity) get "group";
private _redPosition = _redGroup get "position";
private _helicopter = ["B_Heli_Attack_01_dynamicLoadout_F", _helicopterPosition] call IVCS_VirtualSpace_Vehicle_createEntity;
private _crewUnits = [
    ["B_helicrew_F", "u_0"] call IVCS_VirtualSpace_Group_createUnit,
    ["B_helicrew_F", "u_1"] call IVCS_VirtualSpace_Group_createUnit
];
private _blueGroup = ["WEST", "BLU_F", _helicopterPosition, _crewUnits] call IVCS_VirtualSpace_Group_createEntity;
[_blueGroup, _helicopter] call IVCS_VirtualSpace_Group_assignVehicle;

private _attackWaypoint = [_redPosition, "MOVE", [
    ["airCombatRole", "ATTACK"], ["airAttackCenter", _redPosition],
    ["airAttackRadius", 600], ["behavior", "COMBAT"], ["combatMode", "RED"]
]] call IVCS_VirtualSpace_createEntityWaypoint;
[_blueGroup, _attackWaypoint] call IVCS_VirtualSpace_entityAddWaypoint;

IVCS_Demo_AttackHelicopterCombatIDs = [_blueGroup get "id", _helicopter get "id", _redGroup get "id"];
{
    _x params ["_entity", "_color", "_label"];
    private _marker = createMarker [format ["IVCS_Demo_AttackHelicopter_%1", _entity get "id"], _entity get "position"];
    _marker setMarkerType "mil_dot";
    _marker setMarkerColor _color;
    _marker setMarkerText _label;
    IVCS_Demo_AttackHelicopterCombatMarkers pushBack [_entity get "id", _marker, _label];
} forEach [[_helicopter, "ColorBLUFOR", "BLUFOR attack helicopter"], [_redGroup, "ColorOPFOR", "OPFOR infantry"]];

diag_log format ["[IVCS DEMO] Attack helicopter combat at %1; entities %2", _targetPosition, IVCS_Demo_AttackHelicopterCombatIDs];
hint "IVCS attack helicopter demo started. Watch the BLUFOR helicopter attack the OPFOR infantry.";
while { true } do {
    {
        _x params ["_id", "_marker", "_label"];
        private _entity = [_id] call IVCS_VirtualSpace_getEntity;
        if (isNil "_entity") then {
            _marker setMarkerAlpha 0;
        } else {
            _marker setMarkerPos (_entity get "position");
            private _state = if (_entity get "active") then { "live" } else {
                if ((_entity get "combatID") != "") then { "virtual combat" } else { "virtual" }
            };
            _marker setMarkerText format ["%1: %2", _label, _state];
        };
    } forEach IVCS_Demo_AttackHelicopterCombatMarkers;
    sleep 1;
};
