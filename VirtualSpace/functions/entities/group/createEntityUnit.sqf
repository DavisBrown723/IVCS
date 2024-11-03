params ["_unitClass", ["_id",""]];

private _unitWeapons = [_unitClass] call IVCS_Common_getUnitLoadoutInfo;

private _unit = createHashMapFromArray [
	["id", _id],
	["class", _unitClass],
	["object", objnull],
	["damage", 0],
	["weapons", _unitWeapons],
	["vehicleAssignment", []]
];

_unit