params ["_fsm"];

private _fsmComplete = false;
private _fsmStateData = _fsm get "data";
private _fsmState = _fsm get "currentState";

_fsmState params ["_stateName","_initFunc","_outgoingConditions","_isEndState","_isRepeatable","_hasExecuted"];

if (!_hasExecuted) then {
    _fsmStateData call _initFunc;

    if (_isEndState) then {
        private _callback = _fsm get "callback";
        private _callbackArgs = _fsm get "callbackArgs";
        ([_fsm] + _callbackArgs) call _callback;
        
        _fsmComplete = true;
    } else {
        _fsmState set [5, true];
    };
} else {
    private _nodes = _fsm get "nodes";
    {
        _x params ["_nodeName","_conditionFunc","_onChosenFunc","_nextState"];

        if (_fsmStateData call _conditionFunc) exitwith {
            _fsmStateData call _onChosenFunc;
            _fsmState set [5, false];
            _fsm set ["currentState", _nodes get _nextState];
        };
    } foreach (_outgoingConditions apply { _nodes get _x });
    if (_isRepeatable) then {
        _fsmState set [5, false];
    };
};

_fsmComplete