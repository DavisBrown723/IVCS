private _vehicles = [] call CBA_fnc_createNamespace;

// find which magazines can fit to which hardpoints
// this also builds our full list of usable hardpoints

private _cfgVehicles = configfile >> "CfgVehicles";

for "_i" from 0 to (count _cfgVehicles - 1) do {
	private _vehicleClass = _cfgVehicles select _i;
	if (isclass _vehicleClass) then {
		private _vehicleName = configname _vehicleClass;
		private _pylonsConfig = _vehicleClass >> "Components" >> "TransportPylonsComponent" >> "Pylons";

        if (isclass _pylonsConfig) then {
            private _pylonsInfo = [];
            for "_i" from 0 to (count _pylonsConfig - 1) do {
                private _pylonClass = _pylonsConfig select _i;
                if (isclass _pylonClass) then {
                    private _pylonName = configname _pylonClass;
                    private _hardpoints = getarray (_pylonClass >> "hardpoints");
                    private _defaultMagazine = gettext (_pylonClass >> "attachment");

                    _pylonsInfo pushback [_pylonName, _defaultMagazine, _hardpoints];
                };
            };

            _vehicles setvariable [_vehicleName, _pylonsInfo];
        };
	};
};

_vehicles