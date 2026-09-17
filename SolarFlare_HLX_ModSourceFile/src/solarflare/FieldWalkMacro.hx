package solarflare;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
#end

/**
 * Compile-time GameLib inheritance walk (`ClassType.superClass` / abstract this-type).
 * Emits parentOf + typed 0-arg dispatch. No runtime Type.resolveClass.
 */
class FieldWalkMacro {
	#if macro
	static var seeds:Array<String> = [
		"ent.Hero", "ent.Foe", "ent.Unit", "ent.GameObject", "ent.Entity",
		"ent.HeroAttributes", "ent.UnitAttributes",
		"ent.hero.PriestComponent", "ent.hero.MageComponent",
		"st.skill.Skill", "st.skill.BaseSkill", "st.skill.Status", "st.skill.HitData",
		"st.skill.ScriptHitData", "st.skill.DamageResult", "st.skill.BaseSkillAccess",
		"st.Player", "st.GameLayer", "st.State", "st.BaseState",
		"GameApp", "App",
		"script.SkillScript", "script.ScriptBase",
		"ui.hud.SkillSlotButton", "ui.hud.SkillPickButton", "ui.hud.SkillButton",
		"ui.hud.WeaponSkillSlotButton",
		"ui.GameUI", "ui.BaseUI", "ui.UIElement", "ui.BaseElement",
		"ui.comp.FmtText",
		"hxbit.ArrayProxyData", "hxbit.BaseProxy"
	];

	/** Observation 0-arg GameLib methods — typed closures, not speculative callResolved. */
	static var typed:Map<String, Array<String>> = [
		"ent.Unit" => ["get_health", "get_maxHealth", "get_healthRatio"],
		"ent.Hero" => ["isMyHero"],
		"st.skill.Skill" => [
			"getCooldownLeft", "getCooldown", "getEffectiveCooldown", "getCooldownProgress",
			"getCooldownModifier", "getBaseCooldown", "isInCooldown", "hasCooldown",
			"isEnabled", "getCurrentCharges", "getMaxCharges", "isCooldownBlocked",
			"canCooldownProgress"
		],
		"st.skill.BaseSkill" => [
			"isSignature", "isClassSkill", "isDash", "isPassive", "isWeaponSkill",
			"isRunning", "isVisible"
		],
		"ui.hud.SkillButton" => ["getOverrideSkill"],
		"ui.hud.SkillSlotButton" => ["getOverrideSkill"]
	];

	public static function build():Array<Field> {
		var fields = Context.getBuildFields();
		var parents = new Map<String, String>();
		for (s in seeds)
			walk(s, parents);

		var parentCases:Array<Case> = [];
		for (child in parents.keys()) {
			var p = parents.get(child);
			parentCases.push({
				values: [macro $v{child}],
				expr: macro return $v{p}
			});
		}

		fields.push({
			name: "parentOf",
			access: [APublic, AStatic],
			kind: FFun({
				args: [{name: "typeName", type: macro :String}],
				ret: macro :String,
				expr: {
					expr: ESwitch(macro typeName, parentCases, macro return ""),
					pos: Context.currentPos()
				}
			}),
			pos: Context.currentPos(),
			doc: "GameLib parent type path from compile-time superClass / abstract this-type."
		});

		var typedCases:Array<Case> = [];
		for (tn in typed.keys()) {
			var methods = typed.get(tn);
			var inner:Array<Case> = [];
			for (m in methods) {
				inner.push({
					values: [macro $v{m}],
					expr: callExpr(tn, m)
				});
			}
			var innerSwitch:Expr = {
				expr: ESwitch(macro method, inner, macro return null),
				pos: Context.currentPos()
			};
			typedCases.push({
				values: [macro $v{tn}],
				expr: innerSwitch
			});
		}

		fields.push({
			name: "typedZero",
			access: [APublic, AStatic],
			kind: FFun({
				args: [
					{name: "obj", type: macro :Dynamic},
					{name: "typeName", type: macro :String},
					{name: "method", type: macro :String}
				],
				ret: macro :Dynamic,
				expr: macro {
					if (obj == null || typeName == null || method == null)
						return null;
					try {
						${{
							expr: ESwitch(macro typeName, typedCases, macro return null),
							pos: Context.currentPos()
						}};
					} catch (_:Dynamic) {
						return null;
					}
					return null;
				}
			}),
			pos: Context.currentPos(),
			doc: "Live HashLink type name must match; then GameLib typed 0-arg method (cached ResolvedMember inside GameLib)."
		});

		var pairExprs:Array<Expr> = [];
		for (child in parents.keys())
			pairExprs.push(macro $v{child + ">" + parents.get(child)});
		fields.push({
			name: "parentPairs",
			access: [APublic, AStatic],
			kind: FVar(macro :Array<String>, macro $a{pairExprs}),
			pos: Context.currentPos()
		});

		return fields;
	}

	static function callExpr(typeName:String, method:String):Expr {
		var tp = pathToTypePath(typeName);
		var ident = {expr: EConst(CIdent("obj")), pos: Context.currentPos()};
		var typed = {expr: ECheckType(ident, TPath(tp)), pos: Context.currentPos()};
		var call = {expr: ECall({expr: EField(typed, method), pos: Context.currentPos()}, []), pos: Context.currentPos()};
		return macro return $call;
	}

	static function pathToTypePath(typeName:String):TypePath {
		var parts = typeName.split(".");
		var name = parts.pop();
		return {pack: parts, name: name};
	}

	static function walk(typeName:String, parents:Map<String, String>):Void {
		if (typeName == null || typeName.length == 0 || parents.exists(typeName))
			return;
		var t = try Context.getType(typeName) catch (_:Dynamic) return;
		var parent = parentPath(t);
		if (parent != null && parent.length > 0 && parent != typeName) {
			parents.set(typeName, parent);
			walk(parent, parents);
		}
	}

	static function parentPath(t:Type):String {
		t = Context.follow(t, true);
		return switch (t) {
			case TInst(c, _):
				var ct = c.get();
				if (ct.superClass == null)
					return "";
				classPath(ct.superClass.t.get());
			case TAbstract(a, _):
				var at = a.get();
				if (at.type == null)
					return "";
				typePath(at.type);
			case TType(td, _):
				parentPath(td.get().type);
			case TLazy(f):
				parentPath(f());
			default:
				"";
		};
	}

	static function typePath(t:Type):String {
		return switch (Context.follow(t, true)) {
			case TInst(c, _): classPath(c.get());
			case TAbstract(a, _): absPath(a.get());
			case TEnum(e, _):
				var et = e.get();
				packName(et.pack, et.name);
			case TType(td, _): typePath(td.get().type);
			default: "";
		};
	}

	static function classPath(c:ClassType):String {
		return packName(c.pack, c.name);
	}

	static function absPath(a:AbstractType):String {
		return packName(a.pack, a.name);
	}

	static function packName(pack:Array<String>, name:String):String {
		if (pack == null || pack.length == 0)
			return name;
		return pack.join(".") + "." + name;
	}
	#end
}
