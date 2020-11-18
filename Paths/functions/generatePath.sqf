params ["_pathType","_behavior","_startPos","_endPos","_callbackArgs","_callback"];

private _requestQueue = IVCS_Paths_Generator getvariable "requestQueue";
_requestQueue pushback _this;