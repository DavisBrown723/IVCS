// Internal serializer shared by map exports and the authoring inventory.
params ["_value"];
if (_value isEqualType 0) exitWith { _value toFixed 8 };
if (_value isEqualType []) exitWith { "[" + ((_value apply { [_x] call IVCS_Locations_serializeMapValue }) joinString ",") + "]" };
str _value
