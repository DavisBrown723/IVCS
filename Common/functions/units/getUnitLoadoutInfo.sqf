// Compatibility interface: weapon-associated magazines only.
params ["_unitClass"];
([_unitClass] call IVCS_Common_getUnitInventoryInfo) select 0
