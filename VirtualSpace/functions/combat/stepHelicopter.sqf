params ["_engagement","_participants","_dt"];
_participants params ["_target","_helicopter"];
private _supportHits=[];
{
    private _support=[_x] call IVCS_VirtualSpace_getEntity;
    private _supportTime=((_engagement get "stepTime")-((_engagement get "supportJoinedAt") get _x)) max 0 min _dt;
    if (_supportTime>0 && {!isNil "_support"} && {[_support,_helicopter] call IVCS_Combat_canSee}) then {
        if ((_support get "entityType")=="group") then {
            _supportHits append ([_engagement,[_support,_helicopter],_supportTime,true] call IVCS_Combat_stepVehicle);
        } else {
            _supportHits append ([_engagement,_support,_helicopter,(_support get "position") distance (_helicopter get "position"),_supportTime] call IVCS_Combat_stepMountedVehicle);
        };
    };
} forEach +(_engagement get "supporters");
if ([_target,_helicopter] call IVCS_Combat_canSee) then {
    if ((_target get "entityType")=="group") then {[_engagement,_participants,_dt] call IVCS_Combat_stepVehicle} else {
        private _range=(_target get "position") distance (_helicopter get "position");
        private _hits=[_engagement,_target,_helicopter,_range,_dt] call IVCS_Combat_stepMountedVehicle;
        if ([_target,_helicopter] call IVCS_Combat_canHelicopterFire) then {_hits append ([_engagement,_helicopter,_target,_range,_dt] call IVCS_Combat_stepMountedVehicle)};
        {_x call IVCS_Combat_damageVehicle} forEach _hits;
        _engagement set ["elapsed",(_engagement get "elapsed")+_dt];
    };
} else {_engagement set ["elapsed",(_engagement get "elapsed")+_dt]};
{if (((_x select 0) get "damage")<1) then {_x call IVCS_Combat_damageVehicle}} forEach _supportHits;
