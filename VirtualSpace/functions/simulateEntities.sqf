private _entitiesToSimulate = IVCS_VirtualSpace_Controller getvariable "entitiesToSimulate";
private _simulationChunkSize = IVCS_VirtualSpace_Controller getvariable "simulationChunkSize";

private _entities = IVCS_VirtualSpace_Controller getvariable "entities";
private _allEntities = _entities getvariable "all";

// refresh simulation queue

if (_entitiesToSimulate isequalto []) then {
    _entitiesToSimulate append ((allvariables _allEntities) select { !isnil {_allEntities getvariable _x} });
};

// simulate limited number of entities each frame

private _entitiesSimulateThisFrame = _entitiesToSimulate select [0, _simulationChunkSize];
_entitiesToSimulate deleteRange [0, _simulationChunkSize];

private _currTickTime = diag_ticktime;
{
    private _entity = _allEntities getvariable _x;
    if (!isnil "_entity") then {
        private _updateFunc = missionnamespace getvariable (_entity getvariable "update");
        private _timeLastUpdate = _entity getvariable "timeLastUpdate";
        private _timeElapsed = _currTickTime - _timeLastUpdate;

        [_entity, _timeElapsed] call _updateFunc;

        _entity setvariable ["timeLastUpdate", _currTickTime];
    };
} foreach _entitiesSimulateThisFrame;