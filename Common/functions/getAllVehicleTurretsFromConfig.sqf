private _vehicleTurrets = createHashMap;

private _cfgVehicles = configfile >> "CfgVehicles";

for "_i" from 0 to (count _cfgVehicles - 1) do {
	private _vehicleConfig = _cfgVehicles select _i;
	if (isclass _vehicleConfig) then {
        private _turrets = createHashMap;

		private _turretsToProcess = [
            [_vehicleConfig, []]
        ];

        while {_turretsToProcess isnotequalto []} do {
            (_turretsToProcess deleteat 0) params ["_turretConfig","_turretPath"];

            if (_turretPath isnotequalto []) then {
                private _turretWeapons = getarray (_turretConfig >> "weapons");
                private _turretMagazines = getarray (_turretConfig >> "magazines");

                _turrets set [_turretPath, [_turretWeapons, _turretMagazines]];
            };

            private _childTurrets = _turretConfig >> "Turrets";
            for "_j" from 0 to (count _childTurrets - 1) do {
                private _childTurretConfig = _childTurrets select _j;
                if (isclass _childTurretConfig) then {
                    _turretsToProcess pushback [_childTurretConfig, _turretPath + [_j]];
                };
            };
        };

        if ((keys _turrets) isnotequalto []) then {
            private _vehicleClass = configname _vehicleConfig;
            _vehicleTurrets set [_vehicleClass, _turrets];
        };

        private _pylonsByTurret = [_vehicleConfig] call IVCS_Common_getPylonsFromVehicleConfig;
        {
            private _turretInfo = _turrets getOrDefault [_x, [[], []]];
            _turretInfo pushback _y;
        } foreach _pylonsByTurret;
    };
};

_vehicleTurrets