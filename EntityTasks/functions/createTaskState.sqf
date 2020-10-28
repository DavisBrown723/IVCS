params [
    "_initFunc",
    ["_isEndState", false],
    ["_isRepeatable", false],
    ["_outgoingConditions", []]
];

private _hasExecuted = false;
[_initFunc, _isEndState, _isRepeatable, _hasExecuted, _outgoingConditions]