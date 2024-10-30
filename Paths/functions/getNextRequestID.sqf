private _nextRequestIDNum = IVCS_Paths_Generator get "nextRequestIDNum";
IVCS_Paths_Generator set ["nextRequestIDNum", _nextRequestIDNum + 1];

format ["r_%1", _nextRequestIDNum]