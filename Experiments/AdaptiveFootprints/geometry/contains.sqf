// Inclusive containment; centimetre tolerance accounts for world-coordinate float precision.
params ["_footprint", "_position", ["_tolerance", 0.01]];
!(_footprint isEqualTo []) && {([_footprint, _position] call IVCS_AF_footprintDistance) <= (_tolerance max 0)}
