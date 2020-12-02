params ["_tacom","_message"];

private _messageQueue = _tacom getvariable "messageQueue";
_messageQueue pushback _message;