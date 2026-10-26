params ["_id",["_reason","complete"],["_now",IVCS_SimulationTime]];
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _engagement = (_combat get "engagements") get _id;
if (isNil "_engagement") exitWith {};
(_combat get "engagements") deleteAt _id;
private _queue = _combat get "queue";
private _index = _queue find _id;
if (_index != -1) then { _queue deleteAt _index; };
_engagement set ["mode", "finished"];
_engagement set ["reason",_reason];
{
    private _entity = [_x] call IVCS_VirtualSpace_getEntity;
    if (!isNil "_entity") then {
        _entity set ["combatID", ""];
        if ((_entity get "entityType")!="group") then {[_entity,false] call IVCS_Combat_setHelicopterPassHold};
        if ((_entity get "entityType")!="group" && {_reason in ["contact","ammunition","area","withdrawal","airSupport"]}) then {
            private _cooldowns = _entity get "combatCooldowns";
            {if (_x!=(_entity get "id")) then {_cooldowns set [_x,_now+(if (_reason=="withdrawal") then {_combat get "airWithdrawalCooldown"} else {_combat get "reengageDelay"})]}} forEach ((_engagement get "groups")+(_engagement get "supporters"));
        };
        if ((_entity get "entityType") == "group") then {
            [_entity] call IVCS_Ammo_cancelGroup;
            [_entity] call IVCS_Combat_clearAirDefense;
            { _x set ["planting",[]]; } forEach (_entity get "units");
            if (_reason in ["contact","ammunition","area","withdrawal","airSupport"]) then {
                private _cooldowns = _entity get "combatCooldowns";
                { if (_x != (_entity get "id")) then { _cooldowns set [_x,_now + (if (_reason=="withdrawal") then {_combat get "airWithdrawalCooldown"} else {_combat get "reengageDelay"})]; }; } forEach ((_engagement get "groups")+(_engagement get "supporters"));
            };
            // Task timeout clocks are simulation-time based; exclude the combat pause.
            private _task = _entity get "activeTask";
            if (!isNil "_task" && {(_entity get "vehiclesInCommandOf") findIf {private _v=[_x] call IVCS_VirtualSpace_getEntity; (_v get "vehicleType")=="helicopter"} == -1}) then {
                private _context = _task get "context";
                private _pause = IVCS_SimulationTime - ((_entity get "combatStartedAt") max (_context get "activatedAt"));
                if ("startedAt" in _context && { (_context get "startedAt") >= 0 }) then {
                    _context set ["startedAt", (_context get "startedAt") + _pause];
                };
            };
            if (_entity get "active") then {
                private _group = _entity get "group";
                private _settings = (_engagement get "nativeSettings") get _x;
                if (!isNil "_settings") then {
                    _group setCombatMode (_settings select 0);
                    _group setBehaviourStrong (_settings select 1);
                };
                { _x doFollow leader _group; } forEach units _group;
            };
            private _completions = +(_entity get "combatWaypointCompletions");
            (_entity get "combatWaypointCompletions") resize 0;
            { [_entity get "id", _x] call IVCS_VirtualSpace_onWaypointCompleted; } forEach _completions;
        };
    };
} forEach (_engagement getOrDefault ["members",_engagement get "groups"]);
