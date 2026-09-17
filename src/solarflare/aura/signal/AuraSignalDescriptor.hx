package solarflare.aura.signal;

class AuraSignalDescriptor {
	public var id:String;
	public var label:String;
	public var group:String;
	public var kind:AuraValueKind;
	public var subjectKind:String;
	public function new(id:String, label:String, group:String, kind:AuraValueKind, subjectKind:String = "") {
		this.id = id; this.label = label; this.group = group; this.kind = kind; this.subjectKind = subjectKind;
	}
}
