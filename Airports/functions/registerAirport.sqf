params ["_airportID"];

// this does not currently support carriers

private _airportConfig = confignull;
if (_airportID isequalto 0) then {
    _airportConfig = configfile >> "CfgWorlds" >> worldname;
} else {
    private _secondaryAirports = configfile >> "CfgWorlds" >> worldname >> "SecondaryAirports";
    _airportConfig = _secondaryAirports select (_airportID - 1); // secondary airport ids start at 1
};

private _ilsPos = getarray (_airportConfig >> "ilsPosition");
private _ilsDir = getarray (_airportConfig >> "ilsDirection");

private _ilsEndPosDir =  [
    (_ilsPos select 0) + (_ilsDir select 0),
    (_ilsPos select 1) + (_ilsDir select 2)
];

private _takeOffDir = _ilsPos getdir _ilsEndPosDir;
private _landDir = [_takeOffDir - 180] call IVCS_Common_normalizeDegrees;

private _ilsTaxiOff = getarray (_airportConfig >> "ilsTaxiOff");
private _ilsTaxiIn = getarray (_airportConfig >> "ilsTaxiIn");

private _taxiOffPositions = [];
private _TaxiInPositions = [];

while {!(_ilsTaxiOff isequalto [])} do {
    private _position = _ilsTaxiOff select [0,2];
    _ilsTaxiOff deleterange [0,2];

    _taxiOffPositions pushback _position;
};

while {!(_ilsTaxiIn isequalto [])} do {
    private _position = _ilsTaxiIn select [0,2];
    _ilsTaxiIn deleterange [0,2];

    _TaxiInPositions pushback _position;
};

private _airportInfo = [_airportID, _ilsPos, _ilsDir, _taxiOffPositions, _TaxiInPositions];

IVCS_Airports setvariable [str _airportID, _airportInfo];