// Shared by suspension and terminal cleanup; completed LAND stays grounded.
private _object = _this get "approachObject";
if ((_this getOrDefault ["result", ""]) != "completed" && { !isNull _object }) then {
    _object land "NONE";
    private _entity = [_this get "entityID"] call IVCS_VirtualSpace_getEntity;
    if (isNil "_entity" || { (_entity get "waypoints") isEqualTo [] }) then {
        doStop driver _object;
        if (!isNil "_entity") then { _entity set ["movementStopped", true]; };
    };
};
if (!isNull (_this get "helipad")) then { deleteVehicle (_this get "helipad"); };
_this set ["helipad", objNull];
_this set ["approachObject", objNull];
_this set ["landingObject", objNull];
