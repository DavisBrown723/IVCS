// Loss of an attached crew/transport does not erase a surviving primary fight.
params ["_entity"];
private _id = _entity get "combatID";
_entity set ["combatID",""];
if (_id == "") exitWith {};
private _engagement = (((IVCS_VirtualSpace_Controller get "combat") get "engagements") get _id);
if (isNil "_engagement") exitWith {};
private _entityID = _entity get "id";
if (_entityID in (_engagement get "groups")) exitWith { [_id] call IVCS_Combat_finish; };
private _supporters=_engagement get "supporters";
private _supportIndex=_supporters find _entityID;
if (_supportIndex!=-1) then {_supporters deleteAt _supportIndex;(_engagement get "supportJoinedAt") deleteAt _entityID};
private _members = _engagement get "members";
private _index = _members find _entityID;
if (_index != -1) then { _members deleteAt _index; };
(_engagement get "nativeSettings") deleteAt _entityID;
