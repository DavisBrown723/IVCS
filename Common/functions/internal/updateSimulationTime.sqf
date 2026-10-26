// Consume paused wall-clock time too, preventing catchup when play resumes.
params ["_tick","_paused","_scale"];
private _elapsed = _tick - IVCS_SimulationTime_LastTick;
IVCS_SimulationTime_LastTick = _tick;
IVCS_SimulationPaused = _paused;
if (!_paused) then {
    IVCS_SimulationTime = IVCS_SimulationTime + _elapsed * _scale;
};
