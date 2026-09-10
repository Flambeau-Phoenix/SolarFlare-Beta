package solarflare.aura.signal;

enum abstract AuraDiagnosticCode(Int) from Int to Int {
	var OK = 0;
	var EMPTY_RULE = 1;
	var UNKNOWN_SIGNAL = 2;
	var INVALID_OPERATOR = 3;
	var UNKNOWN_DOMAIN = 4;
	var MISSING_SUBJECT = 5;
	var NON_FINITE = 6;
	var INVALID_RULE = 7;
}
