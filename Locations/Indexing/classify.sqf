// Input identity can come from the terrain scanner or a saved inventory.
params ["_class", "_model", "_settings"];
_class = toLower _class;
_model = toLower _model;
private _classes = _settings get "classOverrides";
private _models = _settings get "modelOverrides";
if (_class in _classes) exitWith { +(_classes get _class) };
if (_model in _models) exitWith { +(_models get _model) };
private _tags = [];
{
    _x params ["_fragment", "_categories"];
    if ((_model find _fragment) >= 0) exitWith { _tags = +_categories; };
} forEach (_settings get "rules");
_tags
