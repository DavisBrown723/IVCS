// Fair discovery slices share the combat deadline and have their own smaller allowance.
params [["_deadline",-1]];
if (IVCS_SimulationPaused || { _deadline >= 0 && { diag_tickTime >= _deadline } }) exitWith {};
private _settings = (IVCS_VirtualSpace_Controller get "combat") get "ammoSharing";
private _searchQueue = _settings get "searchQueue";
private _searchCount = count _searchQueue min (_settings get "searchesPerFrame");
private _started = diag_tickTime;
private _budget = _settings get "searchBudgetMs";
for "_i" from 1 to _searchCount do {
    if (_searchQueue isEqualTo [] || { _deadline >= 0 && { diag_tickTime >= _deadline } } || { _i > 1 && { _budget > 0 } && { 1000 * (diag_tickTime - _started) >= _budget } }) exitWith {};
    private _id = _searchQueue deleteAt 0;
    private _entity = [_id] call IVCS_VirtualSpace_getEntity;
    if (!isNil "_entity") then {
        [_entity,IVCS_SimulationTime,_settings get "donorsPerSlice"] call IVCS_Ammo_advanceSearch;
        if ((_entity get "ammoSearch") isNotEqualTo []) then { _searchQueue pushBackUnique _id; };
    };
};
