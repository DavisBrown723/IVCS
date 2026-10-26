// Rebuild cumulative region weights only when settings change.
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _weights = _combat get "bodyWeights";
private _selection = _combat getOrDefault ["bodySelection",[]];
if (_selection isEqualTo [] || { !((_selection select 0) isEqualTo _weights) }) then {
    private _total = 0;
    private _cumulative = _weights apply { _total = _total + (_x select 1); [_x select 0,_total] };
    _selection = [_weights apply { +_x },_total,_cumulative];
    _combat set ["bodySelection",_selection];
};
_selection
