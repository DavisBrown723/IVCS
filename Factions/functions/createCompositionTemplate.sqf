private _composition = [] call CBA_fnc_createNamespace;

// settings

_composition setvariable ["faction", ""];
_composition setvariable ["isAsymmetric", false];

// groups

_composition setvariable ["infantry", []];
_composition setvariable ["reconInfantry", []];

_composition setvariable ["motorized", []];
_composition setvariable ["mechanized", []];
_composition setvariable ["tanks", []];
_composition setvariable ["artillery", []];
_composition setvariable ["boats", []];

_composition setvariable ["attackHelicopter", []];
_composition setvariable ["transportHelicopter", []];

_composition setvariable ["attackPlane", []];
_composition setvariable ["transportPlane", []];

_composition setvariable ["logistics_ammo", []];
_composition setvariable ["logistics_fuel", []];
_composition setvariable ["logistics_repair", []];

_composition setvariable ["mobile_antiair", []];
_composition setvariable ["sam", []];
_composition setvariable ["radar", []];

// objects

_composition