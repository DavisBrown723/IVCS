params ["_entity"];

private _entityID = _entity get "id";
private _entityType = _entity get "entityType";
private _entityPosition = _entity get "position";
private _entitySide = _entity get "side";

private _sideMarkerColor = _entitySide;
if (_entityType in ["vehicle","uav"]) then {
    _sideMarkerColor = "NONE";
};

private _marker = createMarker [format ["%1_debug", _entityID], _entityPosition];
_marker setMarkerShape "ICON";
_marker setMarkerColor ([_sideMarkerColor] call IVCS_Common_sideStringToColor);

private _active = _entity get "active";

private _sidePrefix = switch (_entitySide) do {
    case "EAST": {
        "o"
    };
    case "WEST": {
        "b"
    };
    case "GUER": {
        "n"
    };
    case "CIV": {
        "n"
    };
};

switch (_entityType) do {
    case "group": {
        _marker setMarkerType (format ["%1_inf", _sidePrefix]);
        _marker setMarkerSize [0.7, 0.7];
    };
    case "uav": {
        _marker setMarkerSize [1, 0.75];
        _marker setMarkerType (format ["%1_uav", _sidePrefix]);
    };
    case "vehicle": {
        _marker setMarkerSize [1.25, 0.75];

        private _entityVehicleType = _entity get "vehicleType";
        switch (_entityVehicleType) do {
            case "truck";
            case "car": {
                _marker setMarkerType (format ["%1_motor_inf", _sidePrefix]);
            };
            case "armored": {
                _marker setMarkerType (format ["%1_mech_inf", _sidePrefix]);
            };
            case "antiair";
            case "tank": {
                _marker setMarkerType (format ["%1_armor", _sidePrefix]);
            };
            case "artillery": {
                _marker setMarkerType (format ["%1_art", _sidePrefix]);
            };
            case "ship": {
                _marker setMarkerType (format ["%1_ship", _sidePrefix]);
            };
            case "helicopter": {
                _marker setMarkerType (format ["%1_air", _sidePrefix]);
            };
            case "plane": {
                _marker setMarkerType (format ["%1_plane", _sidePrefix]);
            };
            case "staticweapon":{
                format ["%1_mortar", _sidePrefix];
            };
        };
    };
};

_marker setmarkertext (_entity get "id");

if (_active) then {
    _marker setMarkerAlpha 0.8;
} else {
    _marker setMarkerAlpha 0.45;
};

_marker