params ["_opcom","_objective"];

private _objectives = _opcom getvariable "objectives";
private _side = _opcom getvariable "side";

private _allegiances = [_side] call IVCS_Common_getSideAllegiances;
_allegiances params ["_friendlySides","_enemySides"];
_friendlySides pushback _side;

// determine objective state
// based on nearby entities
// if we don't have intel on nearby enemies
// state is unknown

private _position = _objective getvariable "position";
private _size = _objective getvariable "size";

private _checkRadius = _size * 1.2;
private _nearEntities = [_position, _checkRadius, ["group"]] call IVCS_VirtualSpace_getNearEntities;
private _nearFriendlies = [];
private _nearEnemies = [];

private _state = "";
if (_nearEntities isequalto []) then {
    _state = "unknown";
} else {
    private _nearEntitySides = _nearEntities apply { _x getvariable "side" };

    _nearFriendlies = { _x in _friendlySides } count _nearEntitySides;
    _nearEnemies = { _x in _enemySides } count _nearEntitySides;

    if (_nearFriendlies > 0) then {
        if (_nearEnemies > 0) then {
            _state = "contested";
        } else {
            _state = "friendly";
        };
    } else {
        _state = "unknown";
    };
};

private _debug = _opcom getvariable "debug";
if (_debug) then {
    private _debugMarker = _objective getvariable "debugMarker";
    switch (_state) do {
        case "friendly": {
            _debugMarker setMarkerBrush "Solid";
            _debugMarker setMarkerColor "ColorBlufor";
        };
        case "contested": {
            _debugMarker setMarkerBrush "BDiagonal";
            _debugMarker setMarkerColor "ColorYellow";
        };
        case "unknown": {
            _debugMarker setMarkerBrush "Solid";
            _debugMarker setMarkerColor "ColorBrown";
        };
    };
};

_objective setvariable ["timeLastScanned", diag_tickTime];
_objective setvariable ["controlState", _state];

[_objective getvariable "id", [_nearFriendlies, _nearEnemies], _state]