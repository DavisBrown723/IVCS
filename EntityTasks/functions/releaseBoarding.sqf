// Release only resources and seat assignments acquired by this task.
if (!isNull (_this get "smoke")) then { deleteVehicle (_this get "smoke"); };
_this set ["smoke", objNull];
_this set ["signalSent", false];
if ((_this getOrDefault ["result", ""]) != "completed") then {
    private _reserved = _this get "reservedUnits";
    private _vehicle = _this get "reservedVehicle";
    if (_reserved isNotEqualTo []) then {
        private _entity = [_this get "entityID"] call IVCS_VirtualSpace_getEntity;
        if (!isNil "_entity" && { _entity get "active" }) then {
            doStop (units (_entity get "group"));
            _entity set ["movementStopped", true];
        };
        private _vehicleID = _this get "vehicleID";
        private _unitsToRelease = [];
        {
            private _assignment = _x get "vehicleAssignment";
            if (_assignment isNotEqualTo [] && { (_assignment select 0) == _vehicleID }) then {
                (_assignment select 1) set [1, ""];
                _x set ["vehicleAssignment", []];
                private _object = _x get "object";
                if (!isNull _object && { alive _object }) then { _unitsToRelease pushBack _object; };
            };
        } forEach _reserved;
        private _links = _this get "cargoLinks";
        private _index = _links find _vehicleID;
        if (_index != -1) then { _links deleteAt _index; };
        private _cargo = _vehicle get "entitiesInCargo";
        _index = _cargo find (_this get "entityID");
        if (_index != -1) then { _cargo deleteAt _index; };
        {
            unassignVehicle _x;
            [_x] orderGetIn false;
            if (vehicle _x == (_vehicle get "object")) then { moveOut _x; };
        } forEach _unitsToRelease;
    };
};
(_this get "reservedUnits") resize 0;
_this set ["reservedVehicle", createHashMap];
_this set ["cargoLinks", []];
