params ["_recipient", "_donor"];
// doMove's stopping tolerance can leave AI outside the one-metre interaction.
// Aim beyond the donor; the shared distance check stops the recipient on arrival.
_recipient forceWalk true;
_recipient doMove (_donor getPos [1.25, _recipient getDir _donor]);
