// Remove standalone completion calls without splitting user strings/blocks.
params ["_text"];
private _chars = toArray _text;
private _statements = [];
private _normalized = [];
private _start = 0;
private _index = 0;
private _depth = 0;
private _quote = -1;
private _lineComment = false;
private _blockComment = false;
while { _index < count _chars } do {
    private _char = _chars select _index;
    private _next = if (_index + 1 < count _chars) then { _chars select (_index + 1) } else { -1 };
    if (_lineComment) then {
        if (_char in [10, 13]) then { _lineComment = false; };
    } else {
        if (_blockComment) then {
            if (_char == 42 && { _next == 47 }) then {
                _blockComment = false;
                _index = _index + 1;
            };
        } else {
            if (_quote != -1) then {
                _normalized pushBack _char;
                if (_char == _quote) then {
                    if (_next == _quote) then {
                        _normalized pushBack _next;
                        _index = _index + 1;
                    } else { _quote = -1; };
                };
            } else {
                switch (true) do {
                    case (_char in [34, 39]): { _quote = _char; _normalized pushBack _char; };
                    case (_char == 47 && { _next == 47 }): { _lineComment = true; _index = _index + 1; };
                    case (_char == 47 && { _next == 42 }): { _blockComment = true; _index = _index + 1; };
                    case (_char in [40, 91, 123]): { _depth = _depth + 1; _normalized pushBack _char; };
                    case (_char in [41, 93, 125]): { _depth = _depth - 1; _normalized pushBack _char; };
                    case (_char == 59 && { _depth == 0 }): {
                        _statements pushBack [_text select [_start, _index - _start], toLower (toString _normalized)];
                        _normalized = [];
                        _start = _index + 1;
                    };
                    default { if !(_char in [9, 10, 13, 32]) then { _normalized pushBack _char; }; };
                };
            };
        };
    };
    _index = _index + 1;
};
_statements pushBack [_text select [_start], toLower (toString _normalized)];

// The recorded owner/name may belong to a different entity after import.
private _call = "callivcs_virtualspace_onwaypointcompleted";
private _userStatements = (_statements select {
    _x params ["_source", "_normalized"];
    private _callStart = count _normalized - count _call;
    private _internal = _callStart > 0 &&
        { (_normalized select [0, 1]) == "[" } &&
        { (_normalized select [_callStart - 1]) == ("]" + _call) };
    _normalized != "" && { !_internal }
}) apply { _x select 0 };
// Native statements form one scope; keep private variables shared across them.
if (_userStatements isEqualTo []) then { [] } else { [_userStatements joinString ";"] }
