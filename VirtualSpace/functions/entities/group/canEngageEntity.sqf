params ["_entity","_targetEntity"];

// capabilities: infantry, vehicles, armor, air, mine, concealment, underwater, countermeasures, marking, light
private _engagementCapabilities = [_entity] call IVCS_VirtualSpace_Group_getEngagementCapabilities;

private _canEngage = false;

private _targetEntityType = _targetEntity get "entityType";
if (_targetEntityType == "group") then {
    _canEngage = "infantry" in _engagementCapabilities;
} else {
    private _vehicleType = _targetEntity get "vehicleType";
    private _validEngagementTypes = switch (_vehicleType) do {
        case "car";
        case "truck": { ["infantry","vehicles"] };
        case "armored";
        case "tank";
        case "antiair";
        case "ship";
        case "artillery": { ["vehicles","armor"] };
        case "helicopter";
        case "plane": { ["air"] };
        case "vehicle": { ["vehicles","armor"] };
        case "staticWeapon": { ["infantry"] };
        default { systemchat format ["IVCS_VirtualSpace_canEngageEntity: Unknown vehicle type - %1", _vehicleType] };
    };

    _canEngage = !((_validEngagementTypes arrayIntersect _engagementCapabilities) isequalto []);
};

_canEngage