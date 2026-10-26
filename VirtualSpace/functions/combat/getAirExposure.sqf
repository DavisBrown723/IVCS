params ["_group","_now"];
private _state=_group get "airDefense";
if (_state isEqualTo [] || {(_state select 0)!=(_group get "combatID")}) exitWith {1};
private _combat=IVCS_VirtualSpace_Controller get "combat";
private _progress=((_now-(_state select 1)-(_combat get "airReactionDelay"))/(_combat get "airCoverTime")) max 0 min 1;
1-(1-(_combat get "airMinimumExposure"))*_progress
