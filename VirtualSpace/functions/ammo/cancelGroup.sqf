params ["_entity"];
{ [_entity, _x] call IVCS_Ammo_releaseRequest; } forEach (_entity get "ammoRequests");
(_entity get "ammoRequests") resize 0;
_entity set ["ammoNextScan", 0];
{ _x set ["ammoRetryAt", 0]; } forEach (_entity get "units");

private _queue = ((IVCS_VirtualSpace_Controller get "combat") get "ammoSharing") get "nativeQueue";
private _index = _queue find (_entity get "id");
if (_index != -1) then { _queue deleteAt _index; };

_entity set ["ammoSearch",[]];
private _searchQueue = ((IVCS_VirtualSpace_Controller get "combat") get "ammoSharing") get "searchQueue";
_index = _searchQueue find (_entity get "id");
if (_index != -1) then { _searchQueue deleteAt _index; };
