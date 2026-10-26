// One seeded event per occupant: shelter, injury, lethal damage and survivors.
params ["_vehicle","_ammo","_increment","_lethal","_roll"];
private _owners = ([_vehicle get "commandingEntity"] + (_vehicle get "entitiesInCargo")) - [""];
_owners = _owners arrayIntersect _owners;
if (_owners isEqualTo []) exitWith {0};
private _profile = [_vehicle get "class"] call IVCS_Combat_getVehicleProfile;
private _seed = floor (_roll * 65536);
private _random = { _seed = (_seed * 75 + 74) mod 65537; _seed / 65537 };
private _catastrophic = _lethal && { (_profile get "kind") == "air" && { ((_vehicle get "position") param [2,0]) > 10 } };
private _penetrating = _ammo get "antiArmor";
private _chance = if (_lethal) then { if (_catastrophic) then {1} else {if (_penetrating) then {0.85} else {0.65}} } else {
    if (_profile get "armored") then { if (_penetrating) then {0.6} else {0.03} } else {0.35}
};
private _selection = [] call IVCS_Combat_getBodySelection;
private _cumulative = _selection select 2;
private _casualties = 0;
private _vehicleID = _vehicle get "id";
{
    private _group = [_x] call IVCS_VirtualSpace_getEntity;
    if (!isNil "_group") then {
        {
            private _unit = _x;
            private _assignment = _unit get "vehicleAssignment";
            if (_assignment isNotEqualTo [] && { (_assignment select 0) == _vehicleID }) then {
                private _hit = call _random;
                private _injury = if (_lethal) then { if (_hit < _chance) then {1} else {0.25 + (call _random) * 0.4} } else { if (_hit < _chance) then {(_increment * 1.5) min 0.8} else {0} };
                if (_injury > 0) then {
                    private _hp = _unit get "hitpoints";
                    private _layout = [_unit] call IVCS_Combat_getHitpointLayout;
                    private _regionRoll = (call _random) * (_selection select 1);
                    private _region = (_cumulative select (count _cumulative - 1)) select 0;
                    { if (_regionRoll < (_x select 1)) exitWith { _region = _x select 0; }; } forEach _cumulative;
                    private _targets = (_layout select 3) get _region;
                    if (_targets isEqualTo []) then { _targets = _layout select 4; };
                    if (_targets isNotEqualTo []) then {
                        private _target = _targets select floor ((call _random) * count _targets);
                        private _index = _target select 0;
                        private _point = _hp select _index;
                        _point set [1,((_point select 1) + _injury) min 1];
                        if (((_target select 1) select 2) in ["head","torso"] && {(_point select 1)>=1}) then {_injury=1};
                    };
                    _unit set ["damage",((_unit get "damage") + _injury) min 1];
                    if ((_unit get "damage") >= 1) then {
                        _casualties = _casualties + 1;
                        [_group,_unit] call IVCS_VirtualSpace_Group_RemoveUnit;
                    };
                };
            };
        } forEach ((_group get "units") select [0]);
    };
} forEach _owners;
_casualties
