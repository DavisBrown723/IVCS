params ["_sideStr"];

switch (_sideStr) do {
    case "EAST": { east };
    case "WEST": { west };
    case "GUER": { independent };
    case "CIV": { civilian };
    default { east };
};