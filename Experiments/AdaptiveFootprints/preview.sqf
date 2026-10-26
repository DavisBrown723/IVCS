// Returns local marker names; deleteMarkerLocal each name to remove the preview.
params ["_locations", ["_prefix", "IVCS_AF_IndexPreview"]];
private _markers = [];
{
    private _footprint = _x getOrDefault ["footprint", ["circle", _x get "position", [_x get "size", _x get "size"], 0]];
    _footprint params ["_shape", "_shapeCenter", "_axes", "_angle"];
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
    createMarkerLocal [_name, _shapeCenter];
    _name setMarkerShapeLocal (if (_shape == "rectangle") then { "RECTANGLE" } else { "ELLIPSE" });
    _name setMarkerBrushLocal "Border";
    _name setMarkerSizeLocal _axes;
    _name setMarkerDirLocal _angle;
    _name setMarkerAlphaLocal 0.65;
    _name setMarkerColorLocal _color;
    _markers pushBack _name;
    private _label = _name + "_label";
    deleteMarkerLocal _label;
    createMarkerLocal [_label, _shapeCenter];
    _label setMarkerTypeLocal "mil_dot";
    _label setMarkerColorLocal _color;
    _label setMarkerSizeLocal [0.7, 0.7];
    private _extentText = if (_shape == "rectangle") then {
        format ["%1 x %2 m | %3 deg", round (2 * (_axes select 0)), round (2 * (_axes select 1)), round _angle]
    } else { format ["radius %1 m", round (_axes select 0)] };
    _label setMarkerTextLocal format ["%1 | %2 objects | %3", _description, _x getOrDefault ["objectCount", 0], _extentText];
    _markers pushBack _label;
} forEach _locations;
_markers
