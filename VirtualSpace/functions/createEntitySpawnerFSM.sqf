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

        private _profilesToDespawn = _activeEntityIDs - _entitiesInSpawnRange;
        _this set ["despawnQueue", _profilesToDespawn];

        private _spawnQueue = _this get "spawnQueue";
        private _entitiesStillInSpawnRange = _entitiesInSpawnRange arrayIntersect _spawnQueue;
        _this set ["spawnQueue", _entitiesStillInSpawnRange];

        _this set ["entitiesInSpawnRange", []];
    }, ["Finished"]] call IVCS_FSM_createState,

    ["CheckSpawnRadius",{
        private _spawnSources = _this get "spawnSources";
        private _spawnSource = _spawnSources deleteat 0;

        private _spawnPosition = getpos _spawnSource;
        private _spawnQueue = _this get "spawnQueue";
        private _entitiesInSpawnRange = _this get "entitiesInSpawnRange";

        //private _spawnRadius = 1500;
        //private _despawnRadius = 1700;
        private _spawnRadius = 500;
        private _despawnRadius = 700;
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

            private _spawnFnc = missionnamespace getvariable (_entity get "spawn");
            [_entity] call _spawnFnc;

            private _activeEntityIDs = _this get "activeEntityIDs";
            private _entityID = _entity get "id";
            _activeEntityIDs pushback _entityID;

            private _inactiveEntityIDs = _this get "inactiveEntityIDs";
            _inactiveEntityIDs deleteat (_inactiveEntityIDs find _entityID);
        };

        if !(_despawnQueue isequalto []) then {
            private _entityID = _despawnQueue deleteat 0;
            private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
            if (!isnil "_entity") then {
                private _despawnFunc = missionnamespace getvariable (_entity get "despawn");
                [_entity] call _despawnFunc;

                private _inactiveEntityIDs = _this get "inactiveEntityIDs";
                private _entityID = _entity get "id";
                _inactiveEntityIDs pushback _entityID;

                private _activeEntityIDs = _this get "activeEntityIDs";
                _activeEntityIDs deleteat (_activeEntityIDs find _entityID);
            };
        };
    }, ["Finished"]] call IVCS_FSM_createState
];


// conditions

private _conditions = [
    ["SpawnSourcesEmpty", { (_this get "spawnSources") isequalto [] }, {}, "FillSpawnSources"] call IVCS_FSM_createCondition,
    ["SpawnSourcesLeft", { !((_this get "spawnSources") isequalto []) }, {}, "CheckSpawnRadius"] call IVCS_FSM_createCondition,
    ["LoopDone", { true }, {}, "ProcessQueues"] call IVCS_FSM_createCondition,
    ["Finished", { true }, {}, "LoopStart"] call IVCS_FSM_createCondition
];


// build fsm

[
    "EntitySpawner",
    "LoopStart",
    [
        ["spawnSources", []],
        ["spawnQueue", []],
        ["despawnQueue", []],
        ["entitiesInSpawnRange", []],
        ["activeEntityIDs", _activeEntityIDs],
        ["inactiveEntityIDs", _inactiveEntityIDs]
    ],
    _states + _conditions
] call IVCS_FSM_create;