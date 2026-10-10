package solarflare.barter;

/** Frozen cell for draw — never holds engine pointers. */
class BarTerSnap {
	public var skillId:String = "";
	public var statusId:String = "";
	public var iconKey:String = "";
	public var nativeActionId:String = "";
	public var bindingKnown:Bool = false;
	public var kind:String = "empty";
	public var available:Bool = false;
	public var status = new solarflare.aura.AuraStatusSnap();
	public var itemKind:String = "";
	public var isItem:Bool = false;
	public var iconId:String = "";
	public var label:String = "";
	public var keyLabel:String = "";
	public var present:Bool = false;
	public var ready:Bool = false;
	public var affordable:Bool = true;
	public var procReady:Bool = false;
	/** Monotonic stamp when procReady last turned on; drives the glimmer. */
	public var procStart:Float = 0;
	public var onCd:Bool = false;
	public var cdLeft:Float = 0;
	public var remaining:Float = 0;
	public var charges:Int = 0;
	public var chargesMax:Int = 0;
	/** SkillScript / AuraStatus stacks; badge when > 1 and no charge pool. */
	public var stacks:Int = 0;
	public var count:Int = 0;
	public var usable:Bool = false;
	/** Geaux ReadyFlashState deadline (CD completion attention). */
	public var readyFlashUntil:Float = 0;
	/** Pending click acknowledgment flash. */
	public var flashUntil:Float = 0;

	public function new() {}

	public function clear():Void {
		iconKey=""; nativeActionId=""; bindingKnown=false;
		skillId = itemKind = iconId = label = keyLabel = "";
		statusId = ""; kind = "empty"; available = false; status.clear();
		isItem = present = ready = procReady = usable = false;
		affordable = true;
		onCd = false;
		cdLeft = remaining = flashUntil = readyFlashUntil = procStart = 0;
		charges = chargesMax = stacks = count = 0;
	}
}
