private _vehicleTurrets = createHashMap;
private _cfgVehicles = configFile >> "CfgVehicles";

for "_i" from 0 to (count _cfgVehicles - 1) do {
    private _vehicleConfig = _cfgVehicles select _i;
    if (isClass _vehicleConfig) then {
        private _turrets = createHashMap;
        private _turretsToProcess = [[_vehicleConfig, []]];

        while { _turretsToProcess isNotEqualTo [] } do {
            (_turretsToProcess deleteAt 0) params ["_turretConfig", "_turretPath"];
            private _weapons = getArray (_turretConfig >> "weapons");
            private _magazines = getArray (_turretConfig >> "magazines");
            if (_turretPath isNotEqualTo [] || { _weapons isNotEqualTo [] } || { _magazines isNotEqualTo [] }) then {
                private _path = if (_turretPath isEqualTo []) then { [-1] } else { _turretPath };
                _turrets set [_path, [_weapons, _magazines, createHashMap]];
            };

            private _childTurrets = _turretConfig >> "Turrets";
            for "_j" from 0 to (count _childTurrets - 1) do {
                private _childConfig = _childTurrets select _j;
                if (isClass _childConfig) then {
                    _turretsToProcess pushBack [_childConfig, _turretPath + [_j]];
                };
            };
        };

        {
            private _turretInfo = _turrets getOrDefault [_x, [[], [], createHashMap], true];
            _turretInfo set [2, _y];
        } forEach ([_vehicleConfig] call IVCS_Common_getPylonsFromVehicleConfig);

        if (count _turrets > 0) then {
            _vehicleTurrets set [configName _vehicleConfig, _turrets];
        };
    };
};

_vehicleTurrets
