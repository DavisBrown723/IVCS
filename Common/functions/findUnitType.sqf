params ["_unitClass"];

if (true) then {
    scopename "main";

    if (_unitClass isKindOf "Man") then {
        "man" breakout "main";
    } else {
        if (_unitClass isKindOf "Ship") then {
            "ship" breakout "main";
        };
        if (_unitClass isKindOf "Helicopter") then {
            "helicopter" breakout "main";
        };
        if (_unitClass isKindOf "Plane") then {
            "plane" breakout "main";
        };
        if (_unitClass isKindOf "StaticWeapon") then {
            "staticweapon" breakout "main";
        };
        // check uav

        private _type = if (true) then {
            scopename "possibleArty";
            if (_unitClass isKindOf "Tank") then {
                "tank" breakout "possibleArty";
            };
            if (_unitClass isKindOf "Armored" || _unitClass isKindOf "Wheeled_APC_F") then {
                "armored" breakout "possibleArty";
            };
            if (_unitClass isKindOf "Truck" || _unitClass isKindOf "Truck_F") then {
                "truck" breakout "possibleArty";
            };
            if (_unitClass isKindOf "Car") then {
                "car" breakout "possibleArty";
            };
        };

        // if we have car/tank/armored/truck
        // check if its artillery or antiair

        private _unitConfig = configfile >> "CfgVehicles" >> _unitClass;
        private _maxElev = getNumber (_unitConfig >> "Turrets" >> "MainTurret" >> "maxElev");
        private _hasArtyScanner = getnumber (_unitConfig >> "artilleryScanner") > 0;
        if (_maxElev > 65) then {
            if (_hasArtyScanner) then {
                "artillery" breakout "main";
            } else {
                "antiair" breakout "main";
            };
        };

        _type breakout "main";
    };

    "vehicle"
};