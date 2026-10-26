// Run on the server: [] execVM "IVCS\demos\infantry-combat.sqf";
// Optional battlefield centre and direction of the BLUFOR approach:
// [[14500,16400,0],90] execVM "IVCS\demos\infantry-combat.sqf";
params [["_center", []], ["_heading", 90]];
if (!isServer) exitWith { hint "Run the IVCS combat demo on the server."; };
if (isNil "IVCS_VirtualSpace_Controller" || { isNil "IVCS_Paths_Generator" }) exitWith {
    hint "Start IVCS before running the combat demo.";
};
if (_center isEqualTo []) then {
    private _observer = if (!isNull player) then { player } else { allPlayers param [0, objNull] };
    if (!isNull _observer) then { _center = (getPosATL _observer) getPos [400, getDir _observer]; };
};
if (_center isEqualTo []) exitWith {
    diag_log "[IVCS DEMO] No player available: supply a battlefield centre.";
};
_center = [_center select 0, _center select 1, 0];
private _starts = [_center getPos [250, _heading + 180], _center getPos [250, _heading]];
if ((_starts + [_center]) findIf { surfaceIsWater _x } != -1) exitWith {
    hint "Choose an open land position for the IVCS combat demo.";
};
call compile preprocessFileLineNumbers "IVCS\demos\stop-infantry-combat.sqf";
IVCS_Demo_InfantryCombatScript = _thisScript;
IVCS_Demo_InfantryCombatIDs = [];
IVCS_Demo_InfantryCombatMarkers = [];
private _squads = [
    ["WEST", "BLU_F", "West", "BUS_InfSquad", "ColorBLUFOR", "BLUFOR"],
    ["EAST", "OPF_F", "East", "OIA_InfSquad", "ColorOPFOR", "OPFOR"]
];
{
    _x params ["_side", "_faction", "_configSide", "_squad", "_color", "_label"];
    private _config = configFile >> "CfgGroups" >> _configSide >> _faction >> "Infantry" >> _squad;
    private _entity = ([_config, _side, _faction, _starts select _forEachIndex] call IVCS_VirtualSpace_createEntity) get "group";
    private _waypoint = [_center, "MOVE", [
        ["speed", "NORMAL"], ["completionRadius", 7],
        ["behavior", "AWARE"], ["combatMode", "RED"]
    ]] call IVCS_VirtualSpace_createEntityWaypoint;
    [_entity, _waypoint] call IVCS_VirtualSpace_entityAddWaypoint;
    IVCS_Demo_InfantryCombatIDs pushBack (_entity get "id");
    private _marker = createMarker [format ["IVCS_Demo_Combat_%1", _entity get "id"], _entity get "position"];
    _marker setMarkerType "mil_dot";
    _marker setMarkerColor _color;
    _marker setMarkerText _label;
    IVCS_Demo_InfantryCombatMarkers pushBack _marker;
} forEach _squads;
diag_log format ["[IVCS DEMO] Infantry combat at %1; groups %2", _center, IVCS_Demo_InfantryCombatIDs];
hint "IVCS combat demo started. Watch the BLUFOR/OPFOR map markers. Approach a fighting group to spawn both opponents.";
while { true } do {
    {
        private _entity = [_x] call IVCS_VirtualSpace_getEntity;
        private _marker = IVCS_Demo_InfantryCombatMarkers select _forEachIndex;
        if (isNil "_entity") then {
            _marker setMarkerAlpha 0;
        } else {
            _marker setMarkerPos (_entity get "position");
            private _state = if (_entity get "active") then { "live" } else {
                if ((_entity get "combatID") != "") then { "virtual combat" } else { "moving" }
            };
            _marker setMarkerText format ["%1: %2 (%3 units)", (_squads select _forEachIndex) select 5, _state, count (_entity get "units")];
        };
    } forEach IVCS_Demo_InfantryCombatIDs;
    sleep 1;
};
