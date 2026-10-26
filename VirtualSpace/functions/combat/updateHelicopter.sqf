// Returns true only while combat flight temporarily owns movement. Waypoints remain intact.
params ["_crew","_vehicle","_dt"];
private _native = _vehicle get "active";
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _position = _vehicle get "position";
private _hp = _vehicle get "hitpoints";
private _profile = [_vehicle get "class"] call IVCS_Combat_getVehicleProfile;
private _pilot = if ((_vehicle get "entityType")=="uav") then {0} else {(_crew getOrDefault ["units",[]]) findIf {
    private _seat = _x get "vehicleAssignment";
    (_x get "damage")<1 && {_seat isNotEqualTo []} && {(_seat select 0)==(_vehicle get "id")} && {((_seat select 1) select 0) isEqualTo -1}
}};
private _rotors = _profile get "rotors";
private _crash = _pilot == -1 || {_rotors findIf {(_hp select _x select 1)>=1} != -1};
private _disabled = (_vehicle get "speedPerSecond") <= 0;
if (!_native && {(_crash || {_disabled})} && {(_position select 2)>0.2}) exitWith {
    // Forced descent owns virtual motion too; vehicle updates must preserve its downward velocity.
    _vehicle set ["airMovementOverride",true];
    _position=+_position;
    _position set [2,((_position select 2)-(_combat get "helicopterDescentSpeed")*_dt) max 0.2];
    [_vehicle,_position] call IVCS_VirtualSpace_setEntityPosition;
    if (count _crew>0) then {[_crew,+_position] call IVCS_VirtualSpace_setEntityPosition};
    _vehicle set ["flightVelocity",[0,0,-(_combat get "helicopterDescentSpeed")]];
    if ((_position select 2)<=0.2) then {
        _vehicle set ["engineOn",false]; _vehicle set ["flightVelocity",[0,0,0]];
        if (_crash) then {
            _vehicle set ["damage",1];
            private _ammo = createHashMapFromArray [["antiArmor",true]];
            [_vehicle,_ammo,1,true,0.5] call IVCS_Combat_damageCrew;
            [_vehicle] call IVCS_VirtualSpace_unregisterEntity;
        };
    };
    true
};
if (_crash || {_disabled}) exitWith {[_crew,_vehicle] call IVCS_Combat_releaseHelicopterMovement;false};
// Read the authoritative order once; helpers still read live settings each update.
private _orderCrew=[_vehicle get "commandingEntity"] call IVCS_VirtualSpace_getEntity;
private _waypoint=[];
if (isNil "_orderCrew") then {_orderCrew=[]} else {
    private _current=[_orderCrew] call IVCS_VirtualSpace_getEntityCurrentWaypoint;
    if (!isNil "_current") then {_waypoint=_current};
};
private _policy = [_vehicle,_orderCrew,_waypoint] call IVCS_Combat_getHelicopterPolicy;
private _threat = _vehicle get "airThreat";
private _evade = (_policy select 3) && {_threat isNotEqualTo []} && {IVCS_SimulationTime<(_threat select 1)};
private _destination = [];
if (_evade) then {
    _destination = _vehicle get "airEvasionPoint";
    if (_destination isEqualTo []) then {
        _destination = _position getPos [_combat get "helicopterEvasionDistance",((_threat select 0) getDir _position)+45];
        _destination set [2,_combat get "helicopterAltitude"]; _vehicle set ["airEvasionPoint",_destination];
    };
} else {_vehicle set ["airEvasionPoint",[]]};
private _id = _vehicle get "combatID";
private _attackTarget=nil;private _engagement=nil;private _hold=false;
if (_id!="" && {_policy select 2}) then {
    _engagement=(_combat get "engagements") get _id;
    _attackTarget=[(_engagement get "groups") select 0] call IVCS_VirtualSpace_getEntity;
};
private _area=if (!isNil "_attackTarget") then {[_vehicle,_waypoint] call IVCS_Combat_getHelicopterAttackArea} else {[]};
private _inArea=_area isNotEqualTo [] && {_position distance2D (_area select 0)<=(_area select 1)} && {(_attackTarget get "position") distance2D (_area select 0)<=(_area select 1)};
if (!isNil "_engagement" && {_engagement get "airOffensive"} && {!_inArea}) then {
    [_id,"area"] call IVCS_Combat_finish;
};
private _pass=[];
// Virtual evasion does not use the offensive pass; native hold-fire still does.
if (_inArea && {_native || {!_evade}} && {(_attackTarget get "entityType")=="group"}) then {
    _pass=[_engagement] call IVCS_Combat_getHelicopterPass;_hold=!(_pass select 1);
};
if (!_evade && {_inArea}) then {
    private _targetPos=_attackTarget get "position";
    private _standoff=_combat get "helicopterStandoff";
    private _angle=_targetPos getDir _position;
    if ((_attackTarget get "entityType")=="group") then {
        _standoff=_combat get (if (_hold) then {"helicopterRepositionDistance"} else {"helicopterInfantryStandoff"});
        // Fixed bearings per cycle avoid continuously moving orbit destinations.
        private _bearing=_engagement getOrDefault ["passBearing",[]];
        if (_bearing isEqualTo [] || {(_bearing select 0)!=(_pass select 2)}) then {_bearing=[_pass select 2,_angle];_engagement set ["passBearing",_bearing]};
        _angle=_bearing select 1;
        _angle=_angle+(if (_hold) then {110} else {0});
    };
    _destination=_targetPos getPos [_standoff,_angle];
    _destination set [2,_combat get "helicopterAltitude"];
    _vehicle set ["flightHeading",_position getDir _targetPos];
};
if (_inArea && {_destination isNotEqualTo []}) then {
    // Stay 10 cm inside the leash so projection/movement rounding cannot trigger an area exit.
    private _radius=((_area select 1)-0.1) max 0;
    if (_destination distance2D (_area select 0)>_radius) then {
        _destination=(_area select 0) getPos [_radius,(_area select 0) getDir _destination];
        _destination set [2,_combat get "helicopterAltitude"];
    };
};
if (_native) then {[_vehicle,_hold] call IVCS_Combat_setHelicopterPassHold};
if (_destination isEqualTo []) exitWith {
    [_crew,_vehicle] call IVCS_Combat_releaseHelicopterMovement;
    false
};
if !(_vehicle get "airMovementOverride") then {
    _vehicle set ["airMovementOverride",true];
    private _wp = [_crew] call IVCS_VirtualSpace_getEntityCurrentWaypoint;
    if (!isNil "_wp") then {[_wp] call IVCS_VirtualSpace_resetEntityWaypoint};
};
if (_native) exitWith {
    if ((_hold || {!_inArea}) && {!isNull (_vehicle get "nativeAirTarget")}) then {{_x doTarget objNull} forEach units (_crew get "group");_vehicle set ["nativeAirTarget",objNull]};
    private _object = _vehicle get "object";
    private _last = _vehicle get "nativeAirDestination";
    if (_last isEqualTo [] || {_last distance _destination>25}) then {
        _object land "NONE"; _object flyInHeight (_destination select 2); _object doMove _destination;
        _vehicle set ["nativeAirDestination",+_destination];
    };
    if (!_evade && {!_hold} && {_inArea}) then {
        private _enemy=if ((_attackTarget get "entityType")=="group") then {leader (_attackTarget get "group")} else {_attackTarget get "object"};
        if ((_vehicle get "nativeAirTarget") isNotEqualTo _enemy) then {
            { _x doTarget _enemy; } forEach units (_crew get "group");
            _vehicle set ["nativeAirTarget",_enemy];
        };
    };
    true
};
private _velocity=[0,0,0];
private _next=_position;
if (_destination isNotEqualTo _position) then {
    private _speed = _vehicle get "speedPerSecond";
    if ((_policy select 4)=="LIMITED") then {_speed=_speed*0.5};
    if ((_policy select 4)=="FULL" || {(_policy select 4)=="FAST"}) then {_speed=_speed*1.3};
    private _delta = _destination vectorDiff _position;
    private _distance = vectorMagnitude _delta;
    _velocity = if (_distance>0.001) then {_delta vectorMultiply ((_speed min (_distance/(_dt max 0.001)))/_distance)} else {[0,0,0]};
    _next = _position vectorAdd (_velocity vectorMultiply _dt);
    if (_evade && {_distance>1}) then {_vehicle set ["flightHeading",_position getDir _destination]};
};
_vehicle set ["engineOn",true]; _vehicle set ["flightVelocity",_velocity];
if (_next isNotEqualTo _position) then {[_vehicle,_next] call IVCS_VirtualSpace_setEntityPosition};
[_crew,+_next] call IVCS_VirtualSpace_setEntityPosition;
true
