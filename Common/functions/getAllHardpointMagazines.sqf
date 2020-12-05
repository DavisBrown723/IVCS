private _hardpoints = [] call CBA_fnc_createNamespace;

// find which magazines can fit to which hardpoints
// this also builds our full list of usable hardpoints

private _cfgVehicles = configfile >> "CfgVehicles";
private _cfgMagazines = configfile >> "CfgMagazines";

for "_i" from 0 to (count _cfgMagazines - 1) do {
	private _magazineClass = _cfgMagazines select _i;
	if (isclass _magazineClass) then {
		private _magazineName = configname _magazineClass;
		private _compatibleHardpoints = getarray (_magazineClass >> "hardpoints");

		{
            private _hardpoint = _x;
			private _hardpointMagazines = _hardpoints getvariable _hardpoint;
			if (isnil "_hardpointMagazines") then {
				_hardpointMagazines = [];
				_hardpoints setvariable [_hardpoint, _hardpointMagazines];
			};

			_hardpointMagazines pushback _magazineName; 
		} foreach _compatibleHardpoints;
	};
};

_hardpoints