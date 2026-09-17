package solarflare.target;

/**
 * Frozen current-target sample. Observe fills; draw reads only.
 * `kind` is the GameIcons key (`{kind}.png` / atlas frame) — unit kind basename.
 */
class TargetSnap {
	public var valid:Bool = false;
	public var name:String = "";
	/** Unit kind id for GameIcons portrait lookup (same path as skill icons). */
	public var kind:String = "";
	public var health:Float = 0;
	public var maxHealth:Float = 0;
	public var ratio:Float = 0;
	public var isBoss:Bool = false;
	public var isMiniboss:Bool = false;
	public var isElite:Bool = false;
	public var role:Int = 0;
	public var observedAt:Float = 0;

	public var healthValid:Bool = false;
	public var deadKnown:Bool = false;
	public var dead:Bool = false;
	public var targetLevelValid:Bool = false;
	public var playerLevelValid:Bool = false;
	public var targetLevel:Int = 0;
	public var playerLevel:Int = 0;

	public function new() {}

	public function clear():Void {
		valid = false;
		healthValid = false;
		deadKnown = false;
		dead = false;
		targetLevelValid = false;
		playerLevelValid = false;
		targetLevel = 0;
		playerLevel = 0;

		name = "";
		kind = "";
		health = 0;
		maxHealth = 0;
		ratio = 0;
		isBoss = false;
		isMiniboss = false;
		isElite = false;
		role = 0;
		observedAt = 0;
	}

	public function copyFrom(src:TargetSnap):Void {
		if (src == null) {
			clear();
			return;
		}
		valid = src.valid;
		healthValid = src.healthValid;
		deadKnown = src.deadKnown;
		dead = src.dead;
		targetLevelValid = src.targetLevelValid;
		playerLevelValid = src.playerLevelValid;
		targetLevel = src.targetLevel;
		playerLevel = src.playerLevel;

		name = src.name;
		kind = src.kind;
		health = src.health;
		maxHealth = src.maxHealth;
		ratio = src.ratio;
		isBoss = src.isBoss;
		isMiniboss = src.isMiniboss;
		isElite = src.isElite;
		role = src.role;
		observedAt = src.observedAt;
	}
}
