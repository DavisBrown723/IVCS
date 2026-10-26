// Compatibility interface: weapon-associated magazines only.
params ["_unitObject"];
([_unitObject] call IVCS_Common_getUnitInventoryInfo) select 0
