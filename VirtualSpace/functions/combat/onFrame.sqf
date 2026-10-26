private _combat = IVCS_VirtualSpace_Controller get "combat";
if (IVCS_SimulationPaused) exitWith {};
private _queue = _combat get "queue";
private _count = count _queue min (_combat get "engagementsPerFrame");
private _budget = _combat get "frameBudgetMs";
private _started = diag_tickTime;
private _deadline = if (_budget > 0) then { _started + _budget / 1000 } else { -1 };
// Alternate priority so a busy combat queue cannot starve donor discovery.
private _searchFirst = diag_frameNo mod 2 == 0;
if (_searchFirst) then { [_deadline] call IVCS_Ammo_searchOnFrame; };
for "_i" from 1 to _count do {
    if (_queue isEqualTo [] || { _i > 1 && { _budget > 0 } && { 1000 * (diag_tickTime - _started) >= _budget } }) exitWith {};
    private _id = _queue deleteAt 0;
    private _engagement = (_combat get "engagements") get _id;
    // Finish one complete exchange, then rotate; never drain catchup in one frame.
    [_engagement, IVCS_SimulationTime, 1, true] call IVCS_Combat_update;
    if ((_engagement get "mode") != "finished") then { _queue pushBack _id; };
};

if (!_searchFirst) then { [_deadline] call IVCS_Ammo_searchOnFrame; };
