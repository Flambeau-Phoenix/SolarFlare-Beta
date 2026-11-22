import solarflare.combatlog.CombatLogLine;

class DamagePacketJsonTest {
    static function check(value:Bool, message:String):Void {
        if (!value) throw message;
    }
    static function main():Void {
        var line = new CombatLogLine();
        line.kind = 1;
        line.networkDamageInfo = true;
        line.amount = 470;
        line.crit = true;
        line.sourceUid = "9007199254740993";
        line.targetUid = "4123";
        line.blockerId = "DamageDodge";
        var row:Dynamic = haxe.Json.parse(line.toJson());
        check(row.amount == 470 && row.crit == true, "Known damage facts were lost");
        check(row.sourceUid == "9007199254740993", "UID must remain an exact string");
        check(row.blocker == "DamageDodge", "Preserve blocker identity without guessing a block amount");
        for (field in ["block", "blocked", "kill", "hitCount", "shield", "physical", "magic"])
            check(Reflect.hasField(row, field) && Reflect.field(row, field) == null, field + " must remain unknown");
        check(row.skill == "", "Missing skill must not be inferred from a nearby cast");
        line.amount = 0;
        row = haxe.Json.parse(line.toJson());
        check(row.amount == 0 && row.block == null, "Known zero differs from missing data");
        line.networkDamageInfo = false;
        line.kind = 0;
        row = haxe.Json.parse(line.toJson());
        check(row.kind == "cast" && row.block == 0 && row.kill == false, "Existing cast export changed");
        Sys.println("Damage packet JSON checks passed");
    }
}
