params ["_group",["_clearState",true]];
{_x params ["_object","_stance"];if (!isNull _object) then {_object setUnitPos _stance}} forEach (_group get "airDefenseStances");
_group set ["airDefenseStances",[]];_group set ["airDefenseDestination",[]];
if (_clearState) then {_group set ["airDefense",[]]};
