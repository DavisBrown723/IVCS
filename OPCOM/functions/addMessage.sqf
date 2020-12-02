params ["_opcom","_message"];

private _messageQueue = _opcom getvariable "messageQueue";
_messageQueue pushback _message;