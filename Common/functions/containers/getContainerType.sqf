params ["_container"];

if (_container isequaltype objnull) then {
    _container = typeof _container;
};

if (_container iskindof ["Bag_Base", configfile >> "CfgVehicles"]) then {
    "backpack"
} else {
    private _cfgWeapons = configfile >> "CfgWeapons";
    if (_container iskindof ["Vest_Camo_Base", _cfgWeapons] || {_container iskindof ["Vest_NoCamo_Base", _cfgWeapons]}) then {
        "vest"
    } else {
        if (_container iskindof ["Uniform_Base", _cfgWeapons]) then {
            "uniform"
        } else {
            "box"
        };
    };
};