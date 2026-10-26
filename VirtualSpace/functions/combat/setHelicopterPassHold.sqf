params ["_helicopter","_hold"];
private _saved=_helicopter get "airPassModes";
private _crew=if (_hold) then {crew (_helicopter get "object") select {!isPlayer _x}} else {[]};
if (_crew isEqualTo (_helicopter get "airPassCrew")) exitWith {
    // Native group orders can overwrite per-unit BLUE without changing the crew.
    {if (unitCombatMode _x!="BLUE") then {_x setUnitCombatMode "BLUE"}} forEach _crew;
};
// Restore before recapturing if a crew member changed during the held phase.
{_x params ["_object","_mode","_groupMode"];if (!isNull _object) then {_object setUnitCombatMode (if (combatMode group _object!=_groupMode) then {combatMode group _object} else {_mode})}} forEach _saved;
_saved resize 0;
if (_hold) then {{_saved pushBack [_x,unitCombatMode _x,combatMode group _x];_x setUnitCombatMode "BLUE"} forEach _crew};
_helicopter set ["airPassCrew",_crew];
