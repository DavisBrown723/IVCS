params ["_a","_b"];
if ([_a,_b] call IVCS_Combat_isHelicopterPair) exitWith {true};
if ((_b get "entityType") == "group") exitWith { [_a] call IVCS_Combat_isInfantry && { [_b] call IVCS_Combat_isInfantry } };
[_a] call IVCS_Combat_isAttackingGroup && { [_b] call IVCS_Combat_isVehicleTarget }
