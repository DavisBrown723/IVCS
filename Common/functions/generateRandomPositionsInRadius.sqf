params ["_center","_radius","_countToGenerate"]; 

private _positions = [];

for "_i" from 0 to _countToGenerate - 1 do {
    _positions pushback ([_center, _radius] call IVCS_Common_generateRandomPosition);
};

_positions