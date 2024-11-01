params ["_state","_conditions"];

private _outgoingConditions = _state select 4;

_outgoingConditions append _conditions;
