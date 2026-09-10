package solarflare.aura.signal;

/** Reads only frozen observations. Failed reads must never become absence. */
class AuraStatusSignalReader {
	public static function read(frame:AuraSignalFrame, signal:String, subject:String, out:AuraResolvedValue):Void {
		out.reset();
		var descriptor = AuraSignalCatalog.find(signal);
		if (descriptor == null) { out.code = UNKNOWN_SIGNAL; return; }
		out.kind = descriptor.kind;
		if (signal == "status.count" || signal == "status.overflow") {
			out.known = frame.statusContainerKnown;
			out.code = out.known ? OK : UNKNOWN_DOMAIN;
			if (signal == "status.count") {
				out.intValue = frame.statusContainerCount; out.numberValue = out.intValue;
			} else {
				out.boolValue = frame.statusOverflow; out.present = out.boolValue;
			}
			return;
		}
		if (subject == null || StringTools.trim(subject).length == 0) { out.code = MISSING_SUBJECT; return; }
		var s = frame.findStatus(subject);
		if (s != null ? !s.known : !frame.statusDomainKnown) { out.code = UNKNOWN_DOMAIN; return; }
		var present = s != null && s.present;
		out.present = present;
		if (signal == "status.present") {
			out.boolValue = present; out.known = true; out.code = OK; return;
		}
		if (signal == "status.stacks") {
			out.intValue = present ? s.stacks : 0;
			if (present && s.durationKnown) { out.progress = s.durationProgress; out.timeLeft = s.durationLeft; }
			out.numberValue = out.intValue; out.known = true; out.code = OK; return;
		}
		if (!present) { out.code = MISSING_SUBJECT; return; }
		if (!s.durationKnown) { out.code = UNKNOWN_DOMAIN; return; }
		out.numberValue = signal == "status.durationLeft" ? s.durationLeft : s.durationProgress;
		out.timeLeft = s.durationLeft; out.progress = s.durationProgress;
		out.known = Math.isFinite(out.numberValue);
		out.code = out.known ? OK : NON_FINITE;
	}
}
