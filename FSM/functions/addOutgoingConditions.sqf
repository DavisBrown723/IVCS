params ["_state","_conditionNames"];

private _outgoingConditions = _state select 4;

_outgoingConditions append _conditionNames;
