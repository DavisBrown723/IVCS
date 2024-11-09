params ["_vehicleConfig"];

private _pylonsByTurret = createHashMap;

private _pylonsConfig = _vehicleConfig >> "Components" >> "TransportPylonsComponent" >> "Pylons";
if (isclass _pylonsConfig) then {
    for "_i" from 0 to (count _pylonsConfig - 1) do {
        private _pylonClass = _pylonsConfig select _i;
        if (isclass _pylonClass) then {
            private _pylonName = configname _pylonClass;
            private _pylonTurret = getarray (_pylonClass >> "turret" );
            private _hardpoints = getarray (_pylonClass >> "hardpoints");
            private _defaultMagazine = gettext (_pylonClass >> "attachment");

            if (_pylonTurret isequalto []) then {
                _pylonTurret = [-1];
            };

            private _turretPylons = _pylonsByTurret getOrDefault [_pylonTurret, createHashMap, true];
            _turretPylons set [_pylonName, [_defaultMagazine, _hardpoints]];
        };
    };
};

_pylonsByTurret