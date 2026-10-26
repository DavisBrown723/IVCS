// Returns local marker names; deleteMarkerLocal each name to remove the preview.
params ["_locations", ["_prefix", "IVCS_IndexPreview"]];
private _markers = [];
{
    private _style = switch (_x get "type") do {
        case "town": { ["Settlement", "ColorCIV"] };
        case "base": { ["Military base", "ColorEAST"] };
        case "radiotower": { ["Radio site", "ColorGUER"] };
        case "power": { ["Power facility", "ColorYellow"] };
        case "port": { ["Port / harbour", "ColorWEST"] };
        case "airfield": { ["Airfield", "ColorBLUFOR"] };
        case "fuel": { ["Fuel site", "ColorOrange"] };
        case "factory": { ["Industrial area", "ColorBrown"] };
        case "hospital": { ["Hospital", "ColorGUER"] };
        default { [_x get "type", "ColorGUER"] };
    };
    _style params ["_description", "_color"];
    private _secondary = (_x getOrDefault ["types", [_x get "type"]]) - [_x get "type", "heli", "air"];
    if !(_secondary isEqualTo []) then {
        private _names = _secondary apply {
            switch (_x) do {
                case "town": { "housing" };
                case "base": { "military" };
                case "factory": { "industry" };
                case "radiotower": { "radio" };
                default { _x };
            }
        };
        _description = _description + " (+ " + (_names joinString ", ") + ")";
    };
    private _types = _x getOrDefault ["types", [_x get "type"]];
    { if (_x in _types) then { _description = _description + " [" + _x + "]"; }; } forEach ["heli", "air"];
    private _name = format ["%1_%2", _prefix, _forEachIndex];
    deleteMarkerLocal _name;
    createMarkerLocal [_name, _x get "position"];
    _name setMarkerShapeLocal "ELLIPSE";
    _name setMarkerBrushLocal "Border";
    _name setMarkerSizeLocal [_x get "size", _x get "size"];
    _name setMarkerAlphaLocal 0.65;
    _name setMarkerColorLocal _color;
    _markers pushBack _name;
    private _label = _name + "_label";
    deleteMarkerLocal _label;
    createMarkerLocal [_label, _x get "position"];
    _label setMarkerTypeLocal "mil_dot";
    _label setMarkerColorLocal _color;
    _label setMarkerSizeLocal [0.7, 0.7];
    _label setMarkerTextLocal format ["%1 | %2 objects | radius %3 m", _description, _x getOrDefault ["objectCount", 0], round (_x get "size")];
    _markers pushBack _label;
} forEach _locations;
_markers
