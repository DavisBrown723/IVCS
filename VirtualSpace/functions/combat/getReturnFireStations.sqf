// Read current assignments/injuries; never cache a gunner or magazine record in a class profile.
params ["_vehicle"];
private _profile = [_vehicle get "class"] call IVCS_Combat_getVehicleProfile;
if ((_profile get "kind")!="land" && {(_vehicle get "vehicleType")!="helicopter"} || {(_vehicle get "damage")>=1}) exitWith {[]};
private _operators = createHashMap;
private _owners = [_vehicle get "commandingEntity"] + (_vehicle get "entitiesInCargo");
{
    private _group = [_x] call IVCS_VirtualSpace_getEntity;
    if (!isNil "_group") then {
        {
            private _assignment = _x get "vehicleAssignment";
            if ((_x get "damage")<1 && {_assignment isNotEqualTo []} && {(_assignment select 0)==(_vehicle get "id")}) then {
                private _path = (_assignment select 1) select 0;
                if (_path isEqualTo -1) then {_path=[-1]};
                _operators set [str _path,_x];
            };
        } forEach (_group get "units");
    };
} forEach (_owners arrayIntersect _owners);
private _remote = (_vehicle get "entityType")=="uav";
private _stations = [];
{
    private _path = str (_x select 0);
    private _disabled = ((_profile get "weaponDamage") getOrDefault [_path,[]]) findIf {((_vehicle get "hitpoints") select _x select 1)>=1} != -1;
    private _gunner = _operators getOrDefault [_path,[]];
    if (!_disabled && {((_x select 1) findIf {count (([_x] call IVCS_Combat_getTurretWeaponProfile) select 1)>0} != -1 || {(_x select 3) findIf {(_x select 1)!="" && {(_x select 2)>0}} != -1})} && {_remote || {_gunner isNotEqualTo []}}) then {_stations pushBack [_x,_gunner]};
} forEach (_vehicle get "turrets");
_stations
