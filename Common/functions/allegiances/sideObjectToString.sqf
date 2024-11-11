params ["_sideObject"];

switch (_sideObject) do {
    case east: { "EAST" };
    case west: { "WEST" };
    case independent: { "GUER" };
    case civilian: { "CIV" };
    default { "EAST" };
};