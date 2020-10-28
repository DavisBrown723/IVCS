private _entitiesToSimulate = IVCS_VirtualSpace_Controller getvariable "entitiesToSimulate";
private _simulationChunkSize = IVCS_VirtualSpace_Controller getvariable "simulationChunkSize";

private _entities = IVCS_VirtualSpace_Controller getvariable "entities";
private _allEntities = _entities getvariable "all";

// refresh simulation queue

if (_entitiesToSimulate isequalto []) then {
    _entitiesToSimulate append (allvariables _allEntities);
};

// simulate limited number of entities each frame

private _entitiesSimulateThisFrame = _entitiesToSimulate select [0, _simulationChunkSize];
_entitiesToSimulate deleteRange [0, _simulationChunkSize];

private _spawnAnchor = getpos player;

{
    private _entity = _allEntities getvariable _x;
    if (!isnil "_entity") then {
        private _isActive = _entity getvariable "active";
        private _position = _entity getvariable "position";

        private _inSpawnRange = _position distance _spawnAnchor < 1500;

        if (_isActive) then {
            if (!_inSpawnRange) then {
                // despawn entity

                private _despawnFunc = missionnamespace getvariable (_entity getvariable "despawn");
                [_entity] call _despawnFunc;

                _entity setvariable ["active", false];
            };
        } else {
            if (_inSpawnRange) then {
                // spawn entity

                private _spawnFunc = missionnamespace getvariable (_entity getvariable "spawn");
                [_entity] call _spawnFunc;

                _entity setvariable ["active", true];
            }
        };

        // update

        private _updateFunc = missionnamespace getvariable (_entity getvariable "update");
        private _timeLastUpdate = _entity getvariable "timeLastUpdate";
        private _timeElapsed = diag_tickTime - _timeLastUpdate;

        [_entity, _timeElapsed] call _updateFunc;

        _entity setvariable ["timeLastUpdate", diag_tickTime];
    };
} foreach _entitiesSimulateThisFrame;