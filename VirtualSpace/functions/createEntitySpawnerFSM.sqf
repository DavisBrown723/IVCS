params ["_activeEntityIDs","_inactiveEntityIDs"];

// states

private _states = [
    ["LoopStart",{
    }, ["SpawnSourcesLeft","SpawnSourcesEmpty"]] call IVCS_FSM_createState,

    ["FillSpawnSources",{
        private _spawnSources = allPlayers + (allUnitsUAV select {isUavConnected _x});

        _this set ["spawnSources", _spawnSources];

        // since we've checked all spawn sources
        // lets determine our despawn queue

        private _activeEntityIDs = _this get "activeEntityIDs";
        private _entitiesInSpawnRange = _this get "entitiesInSpawnRange";

        // A directly engaged opponent stays spawned with any in-range participant.
        {
            private _entity = [_x] call IVCS_VirtualSpace_getEntity;
            if (!isNil "_entity" && { (_entity get "combatID") != "" }) then {
                { _entitiesInSpawnRange pushBackUnique (_x get "id"); } forEach ([_entity] call IVCS_Combat_getSpawnPartners);
            };
        } forEach +_entitiesInSpawnRange;
        private _profilesToDespawn = _activeEntityIDs - _entitiesInSpawnRange;
        _this set ["despawnQueue", _profilesToDespawn];

        private _spawnQueue = _this get "spawnQueue";
        private _entitiesStillInSpawnRange = _entitiesInSpawnRange arrayIntersect _spawnQueue;
        _this set ["spawnQueue", _entitiesStillInSpawnRange];

        _this set ["entitiesInSpawnRange", []];
    }, ["LoopDone"]] call IVCS_FSM_createState,

    ["CheckSpawnRadius",{
        private _spawnSources = _this get "spawnSources";
        private _spawnSource = _spawnSources deleteat 0;

        private _spawnPosition = getpos _spawnSource;
        private _spawnQueue = _this get "spawnQueue";
        private _entitiesInSpawnRange = _this get "entitiesInSpawnRange";

        private _spawnRadius = _this get "spawnRadius";
        private _despawnRadius = _this get "despawnRadius";
        private _nearEntities = [_spawnPosition, _despawnRadius] call IVCS_VirtualSpace_getNearEntities;
        {
            private _id = _x get "id";
            private _active = _x get "active";

            if (_active) then {
                _entitiesInSpawnRange pushbackunique _id;
            } else {
                private _entityPosition = _x get "position";
                if (_entityPosition distance2D _spawnPosition < _spawnRadius) then {
                    _spawnQueue pushbackunique _id;
                    _entitiesInSpawnRange pushbackunique _id;
                };
            };
        } foreach _nearEntities;
    }, ["LoopDone"]] call IVCS_FSM_createState,

    ["ProcessQueues",{
        private _spawnQueue = _this get "spawnQueue";
        private _despawnQueue = _this get "despawnQueue";

        if !(_spawnQueue isequalto []) then {
            private _entityID = _spawnQueue deleteat 0;
            private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;

            // Queued entities can disappear or be spawned by a connected group.
            if (!isNil "_entity" && { !(_entity get "active") }) then {
                [_entity] call (missionNamespace getVariable (_entity get "spawn"));
            };
        };

        if !(_despawnQueue isequalto []) then {
            private _entityID = _despawnQueue deleteat 0;
            private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
            if (!isNil "_entity" && { _entity get "active" }) then {
                // A stale queue must not despawn a newly spawned opponent whose
                // partner is still near a player/UAV.
                private _sources = allPlayers + (allUnitsUAV select { isUavConnected _x });
                private _partners = [_entity] call IVCS_Combat_getSpawnPartners;
                private _inRange = _partners findIf {
                    private _position = _x get "position";
                    _sources findIf { _position distance2D getPos _x <= (_this get "despawnRadius") } != -1
                } != -1;
                if (!_inRange) then { [_entity] call (missionNamespace getVariable (_entity get "despawn")); };
            };
        };
    }, ["Finished"]] call IVCS_FSM_createState
];


// conditions

private _conditions = [
    ["SpawnSourcesEmpty", { (_this get "spawnSources") isequalto [] }, {}, "FillSpawnSources"] call IVCS_FSM_createTransition,
    ["SpawnSourcesLeft", { !((_this get "spawnSources") isequalto []) }, {}, "CheckSpawnRadius"] call IVCS_FSM_createTransition,
    ["LoopDone", { true }, {}, "ProcessQueues"] call IVCS_FSM_createTransition,
    ["Finished", { true }, {}, "LoopStart"] call IVCS_FSM_createTransition
];


// build fsm

[
    "EntitySpawner",
    "LoopStart",
    [
        ["spawnRadius", 200], ["despawnRadius", 200],
        ["spawnSources", []],
        ["spawnQueue", []],
        ["despawnQueue", []],
        ["entitiesInSpawnRange", []],
        ["activeEntityIDs", _activeEntityIDs],
        ["inactiveEntityIDs", _inactiveEntityIDs]
    ],
    _states + _conditions
] call IVCS_FSM_create;
