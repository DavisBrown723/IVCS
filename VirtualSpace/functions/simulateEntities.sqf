private _entitiesToSimulate = IVCS_VirtualSpace_Controller get "entitiesToSimulate";
private _simulationChunkSize = IVCS_VirtualSpace_Controller get "simulationChunkSize";

private _entities = IVCS_VirtualSpace_Controller get "entities";
private _allEntities = _entities get "ALL";

// refresh simulation queue

if (_entitiesToSimulate isequalto []) then {
    _entitiesToSimulate append ((keys _allEntities) select { !isnil {_allEntities get _x} });
};

// simulate limited number of entities each frame

private _entitiesSimulateThisFrame = _entitiesToSimulate select [0, _simulationChunkSize];
_entitiesToSimulate deleteRange [0, _simulationChunkSize];

private _currTickTime = diag_ticktime;
{
    private _entity = _allEntities get _x;
    if (!isnil "_entity") then {
        private _updateFunc = missionnamespace getvariable (_entity get "update");
        private _timeLastUpdate = _entity get "timeLastUpdate";
        private _timeElapsed = (_currTickTime - _timeLastUpdate) * accTime;

        [_entity, _timeElapsed] call _updateFunc;

        _entity set ["timeLastUpdate", _currTickTime];
    };
} foreach _entitiesSimulateThisFrame;