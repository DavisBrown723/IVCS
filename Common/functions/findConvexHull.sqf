params ["_points"];

// points: [position, data]

private _result = [];

private _start = _points select 0;
{
    private _position = _x select 0;
    private _positionX = _position select 0;
    if (_positionX < ((_start select 0) select 0)) then {
        _start = _x;
    };
} foreach _points;

private _curr = _start;
_result pushback _start;

private _pointsOnSameLine = [];

scopename "main";
while {true} do {
    private _next = _points select 0;

    {
        private _iterPoint = _points select _foreachindex;

        if !((_iterPoint select 0) isequalto (_curr select 0)) then {
            private _dir = [_curr select 0, _next select 0, _iterPoint select 0] call IVCS_Common_findOffsetFromSegment;
            if (_dir == 0) then {
                if ((_curr select 0) distance2D (_next select 0) < (_curr select 0) distance2D (_iterPoint select 0)) then {
                    _pointsOnSameLine pushback _next;
                    _next = _iterPoint;
                } else {
                    _pointsOnSameLine pushback _iterPoint;
                };
            } else {
                if (_dir < 0) then {
                    _next = _iterPoint;
                    _pointsOnSameLine resize 0;
                };
            }
        };
    } foreach _points;

    _result append _pointsOnSameLine;

    if ((_next select 0) isequalto (_start select 0)) then {
        breakTo "main";
    };

    _result pushback _next;
    _curr = _next;
};

_result