params ["_entity"];
private _combat = IVCS_VirtualSpace_Controller get "combat";

if (IVCS_SimulationTime < (_entity get "nextCombatScan")) exitWith {};
_entity set ["nextCombatScan", IVCS_SimulationTime + (_combat get "scanInterval")];
// Spawned or busy AA still sees engaged helicopters; scan only the small air index.
if (_entity get "active" || {(_entity get "combatID")!=""}) exitWith {
    if ((_entity get "vehicleType")=="helicopter") exitWith {};
    // Air-engagement members cannot transfer; reject once before probing every helicopter.
    // Read live ownership/mode so ground-combat transfers and newly released AA still scan.
    private _current=(_combat get "engagements") get (_entity get "combatID");
    if (!isNil "_current" && {
        !((_current get "mode") in ["virtual","native"]) || {
            private _participants=(_current get "groups") apply {[_x] call IVCS_VirtualSpace_getEntity};
            _participants call IVCS_Combat_isHelicopterPair
        }
    }) exitWith {};
    private _range=_combat get (if ((_entity get "entityType")=="group") then {"helicopterInfantryRange"} else {"helicopterVehicleRange"});
    {
        if ((_y get "combatID")!="" && {(_y get "combatID")!=(_entity get "combatID")} && {(_entity get "position") distance2D (_y get "position")<=_range}) then {
            private _joined=[_entity,_y] call IVCS_Combat_start;
            if (!isNil "_joined") exitWith {};
        };
    } forEach (_combat get "helicopters");
};
if ((_entity get "entityType")=="group" && {(_entity get "vehiclesInCommandOf") findIf {private _v=[_x] call IVCS_VirtualSpace_getEntity; (_v get "vehicleType")=="helicopter"} != -1} && {(_entity get "units") findIf {(_x get "vehicleAssignment") isEqualTo []} == -1}) exitWith {};
private _isGroup = (_entity get "entityType") == "group";
if (_isGroup) then {
    private _cooldowns = _entity get "combatCooldowns";
    { if (IVCS_SimulationTime >= (_cooldowns get _x)) then { _cooldowns deleteAt _x; }; } forEach keys _cooldowns;
};
if (if (_isGroup) then { !([_entity] call IVCS_Combat_isAttackingGroup) } else { ([_entity] call IVCS_Combat_getReturnFireStations) isEqualTo [] }) exitWith {};
// Ground discovery keeps its existing local radius. Only the small helicopter index gets the air radius.
private _helicopter = (_entity get "vehicleType")=="helicopter";
private _filters = if (_isGroup || {_helicopter}) then {[]} else {["group"]};
// A helicopter discovers both categories; pair visibility applies their separate 3D limits.
private _airRange = _combat get (if (_isGroup) then {"helicopterInfantryRange"} else {"helicopterVehicleRange"});
private _scanRange = if (_helicopter) then {(_combat get "helicopterInfantryRange") max (_combat get "helicopterVehicleRange")} else {_combat get "range"};
private _near = [_entity get "position",_scanRange,_filters] call IVCS_VirtualSpace_getNearEntities;
if (!_helicopter) then {
    {if ((_entity get "position") distance2D (_y get "position")<=_airRange) then {_near pushBackUnique _y}} forEach (_combat get "helicopters");
};
private _ordered = _near apply { [(_entity get "position") distance2D (_x get "position"), _x get "id"] };
_ordered sort true;
{
    private _target = [_x select 1] call IVCS_VirtualSpace_getEntity;
    private _started = [_entity, _target] call IVCS_Combat_start;
    if (!isNil "_started") exitWith {};
} forEach _ordered;
