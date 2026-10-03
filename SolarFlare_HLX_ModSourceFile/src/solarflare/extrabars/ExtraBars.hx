package solarflare.extrabars;

import imgui.ref.BoolRef;
import solarflare.ui.ConfigPanel;
import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import solarflare.ui.CursorCaptureFix;
import solarflare.cdb.ConsumableCatalog;
import solarflare.aura.ConsumableCache;
import solarflare.extrabars.ExtraBarsConfig.ExtraBarsBarConfig;
import solarflare.extrabars.ExtraBarsConfig.ExtraBarsSlotConfig;
import solarflare.extrabars.ExtraBarsUsePolicy.ExtraBarsUseCandidate;

typedef ExtraBarsRequest = {var barId:String; var index:Int; var kind:String; var generation:Int; var click:Bool;}

/** Runtime coordinator: live state is observed here; renderers only consume frozen slots. */
class ExtraBars {
	public var model = new ExtraBarsConfig();
	public var open = new BoolRef(false);
	public var builder:ExtraBarsBuilder;
	public var gate(default, null):String = "Waiting for gameplay.";
	public var lastResult(default, null):String = "No request yet.";
	public var generation(default, null):Int = 0;
	public var inputActive(default, null):Bool = false;
	public var views(default, null):Map<String, Array<ExtraBarsPrototypeSlot>> = new Map();
	public var catalog(default, null):Array<{id:String, name:String, category:String, icon:String, count:Int, known:Bool, owned:Bool}> = [];
	public var spark = new SparkCubeTracker();
	var host:ConfigPanel;
	public function closeEditors():Void host.closeInteractiveWindows();
	var bindings = new ExtraBarsNativeBindings();
	var assignments = new ExtraBarsAssignmentIndex();
	var capture = new ExtraBarsCaptureState();
	var captureOwner:String = "";
	var captureIndex:Int = -1;
	public var captureMessage:String = "";
	var previousHero:Dynamic;
	var wasEditorOpen=false;
	var signature:String = "";
	var previousGate:String = "Waiting for gameplay.";
	public var suggestions(default,null):String = "";
	var lastSuggestions:Float = -1;
	var keyTable = new hl.Bytes(1024);
	var routes:Array<ExtraBarsRequest> = [];
	var clicks:Array<ExtraBarsRequest> = [];
	var flashes:Map<String, Float> = new Map();
	var placements:Map<String, HudChrome> = new Map();
	var overlay = new ExtraBarsOverlay();
	var lastSample:Float = -1;
	var countChecks:Array<{kind:String, before:Int, at:Float}> = [];
	public function new(host:ConfigPanel) {
		this.host = host; builder = new ExtraBarsBuilder(this);
		for (entry in ConsumableCatalog.entries) catalog.push({id:entry.id, name:entry.name, category:entry.type, icon:ConsumableCatalog.iconKey(entry.id), count:0, known:false, owned:false});
	}
	public function applyConfig(data:Dynamic, legacy:Dynamic = null):Void {
		clearTransientState(); builder.clearHistory(); spark.reset();
		if (data == null) model.applyLegacy(legacy); else model.apply(data);
		solarflare.ObserveDemand.markStatusDemandDirty();
	}
	public function chromeFor(id:String):HudChrome {
		if (!placements.exists(id)) {
			var index = 0; for (bar in model.bars) { if (bar.id == id) break; index++; }
			placements.set(id, new HudChrome(id=="spark" ? 620 : 80+(index%4)*140, id=="spark" ? 320 : 320+Std.int(index/4)*150));
		}
		return placements.get(id);
	}
	public function dumpPlacement():Dynamic {
		var rows:Array<Dynamic> = [];
		for (id in placements.keys()) { var c = placements.get(id); rows.push({id:id, x:c.x.get(), y:c.y.get(), collapsed:c.collapsed.get(), hudLayoutVersion:c.hudLayoutVersion}); }
		return rows;
	}
	public function applyPlacement(data:Dynamic, legacy:Dynamic = null):Void {
		if (Std.isOfType(data, Array)) {
			var rows:Array<Dynamic> = cast data;
			for (row in rows) {
				var id = ExtraBarsConfig.text(row, "id", ""); if (id.length == 0) continue;
				var c = chromeFor(id); c.x.set(ExtraBarsConfig.number(row,"x",80,-10000,10000)); c.y.set(ExtraBarsConfig.number(row,"y",320,-10000,10000));
				c.collapsed.set(Reflect.field(row,"collapsed") == true); c.hudLayoutVersion = ExtraBarsConfig.integer(row,"hudLayoutVersion",0,0,100); c.posDirty = true;
			}
		} else if (legacy != null) {
			var c = chromeFor("bar1"); c.x.set(ExtraBarsConfig.number(legacy,"x",80,-10000,10000)); c.y.set(ExtraBarsConfig.number(legacy,"y",320,-10000,10000)); c.posDirty = true;
			var bar = model.find("bar1"); if (bar != null) { bar.locked = Reflect.field(legacy,"lock") == true; bar.transparent = Reflect.field(legacy,"trans") == true; }
		}
	}
	public function clearTransientState():Void {
		capture.clear(); captureOwner = ""; captureIndex = -1;
		ExtraBarsNativeInput.reset(); generation++; clicks = []; flashes.clear(); inputActive = false;
		for (slots in views) for (slot in slots) { slot.setInputState(false, model.mode); slot.triggerStrength = 0; }
		builder.clearTransientState();
	}
	public function clearSession():Void {
		clearTransientState(); ExtraBarsNativeInput.shutdown(); previousHero = null; signature = ""; views.clear(); countChecks = []; spark.reset();
		for (item in catalog) { item.count = 0; item.known = false; item.owned = false; }
	}
	public function startCapture(barId:String, index:Int):Void {
		clearTransientState(); captureOwner = barId; captureIndex = index; capture.start(); captureMessage = capture.message;
	}
	public function drawCapture():Void {
		if (!capture.waitingRelease) return;
		var down = ExtraBarsKeyMap.uiModifiers() != 0 || imgui.ImGui.isKeyDown(imgui.Enums.ImGuiKey.Escape);
		var pressed = 0;
		for (key in ExtraBarsKeyMap.keys) { if (imgui.ImGui.isKeyDown(key.imgui)) down = true; if (pressed == 0 && imgui.ImGui.isKeyPressed(key.imgui, false)) pressed = key.code; }
		capture.step(down, imgui.ImGui.isKeyPressed(imgui.Enums.ImGuiKey.Escape, false), pressed, ExtraBarsKeyMap.uiModifiers()); captureMessage = capture.message;
	}
	public function bindingIssue(barId:String, index:Int, key:Int, mods:Int):String {
		var details = " [Base " + bindings.describe(key) + "; prefix " + ExtraBarsActivationConfig.prefixLabel(model.prefix) + "; mode " + ExtraBarsActivationConfig.modeLabel(model.mode) + "]";
		if (key <= 0) return "";
		if (mods != 0) return "Ctrl/Alt/Shift remain native. Record a plain bar key." + details;
		if (model.mode == "long_press") return "Long-press retired; choose Hold or Toggle." + details;
		var mapped = ExtraBarsKeyMap.find(key);
		if (mapped == null) return "Unresolved key." + details;
		if (key == ExtraBarsKeyMap.prefixCode(model.prefix) || mapped.nativeCode == 13) return "Choose a different key; prefix/chat input is reserved." + details;
		var native = bindings.conflict(key, 0, true); if (native.length > 0) return native + details;
		var duplicate=assignments.conflict(barId,index,key);
		return duplicate.length>0 ? duplicate+details : "";
	}
	public function queueClick(barId:String, index:Int):Void {
		if (!CursorCaptureFix.cursorFree || gate.length > 0 || host.anyInteractiveOpen() || clicks.length >= 32) return;
		var kind = barId == "spark" ? SparkCubeTracker.ITEM_ID : (model.find(barId) != null && index >= 0 && index < 10 ? model.find(barId).slots[index].itemKind : "");
		clicks.push({barId:barId,index:index,kind:kind,generation:generation,click:true});
	}
	public function observe(app:GameApp):Void {
		if (wasEditorOpen && !open.get()) clearTransientState(); wasEditorOpen=open.get();
		var now = haxe.Timer.stamp(); ExtraBarsKeyMap.initialize(); bindings.refresh(now);
		if (now-lastSuggestions >= 1) {
			lastSuggestions=now; var free:Array<String>=[];
			for (key in ExtraBarsKeyMap.keys) if (["F7","F8","F9","F10","F11","K","L","P"].indexOf(key.label)>=0 && key.code!=ExtraBarsKeyMap.prefixCode(model.prefix) && bindings.conflict(key.code,0).length==0) {
				var used=false; for (bar in model.bars) for (slot in bar.slots) if(slot.keyCode==key.code) used=true;
				if(!used && free.length<3) free.push(key.label);
			} suggestions=free.join(", ");
		}
		var hero:ent.Hero = null; var controller:client.PlayerController = null;
		try { controller = client.PlayerController.inst; if (controller != null) hero = controller.get_hero(); } catch (_:Dynamic) {}
		var current = model.activationSignature();
		if (hero != previousHero || current != signature) {
			var retired=[for(id in views.keys()) if(model.find(id)==null) id]; for(id in retired) views.remove(id);
			clearTransientState(); if (hero != previousHero) spark.reset(); previousHero = hero; signature = current; countChecks = []; }
		assignments.rebuild(model);
		var captured = capture.takeKey();
		if (captured > 0) {
			bindings.refresh(now, true); var bar = model.find(captureOwner);
			var issue = bindingIssue(captureOwner, captureIndex, captured, capture.modifiers);
			if (bar != null && captureIndex >= 0 && captureIndex < bar.slotCount && issue.length == 0) {
				var selected = bar.slots[captureIndex]; builder.change("Bind cell", function() { selected.keyCode = captured; selected.modifiers = 0; }); captureMessage = "Assigned " + ExtraBarsKeyMap.label(captured,0) + ".";
			} else captureMessage = "Rejected: " + issue + " Make sure this binding is free before assigning it. Try a different plain key.";
			log({event:"binding",key:captured,prefix:model.prefix,mode:model.mode,baseState:bindings.describe(captured),message:captureMessage});
		}
		assignments.rebuild(model);
		gate = blockReason(app, controller, hero); if (ExtraBarsKeyMap.error.length > 0) gate = "Key resolution failed: " + ExtraBarsKeyMap.error;
		ConsumableCache.sample(hero, now);
		if (now - lastSample >= 0.25) {
			lastSample = now; for (item in catalog) { var snap = ConsumableCache.find(item.id); item.count = snap != null ? snap.count : 0; item.known = snap != null && snap.known; item.owned = item.known && snap.owned; }
			var remaining = [];
			for (check in countChecks) { var snap = ConsumableCache.find(check.kind); if (snap != null && snap.known && (snap.count != check.before || now - check.at > 2)) log({event:"observation",item:check.kind,before:check.before,after:snap.count}); else remaining.push(check); }
			countChecks = remaining;
		}
		if (gate != previousGate) { clearTransientState(); previousGate=gate; }
		routes = []; for (i in 0...256) keyTable.setI32(i*4,0);
		for (bar in model.bars) {
			if (!views.exists(bar.id)) views.set(bar.id, [for (i in 0...10) new ExtraBarsPrototypeSlot()]);
			var slots = views.get(bar.id);
			for (i in 0...10) {
				var assignment = bar.slots[i]; var entry = ConsumableCatalog.find(assignment.itemKind);
				var issue = bindingIssue(bar.id,i,assignment.keyCode,assignment.modifiers);
				if (entry == null && assignment.itemKind.length > 0) issue = "Unresolved item: " + assignment.itemKind;
				var frozen = slots[i]; frozen.update(bar.enabled, entry != null ? entry.name : (assignment.itemKind.length > 0 ? assignment.itemKind + " (unresolved)" : "Empty cell " + (i+1)), entry != null ? ConsumableCatalog.iconKey(entry.id) : "",
					ExtraBarsActivationConfig.prefixLabel(model.prefix) + " / " + ExtraBarsActivationConfig.modeLabel(model.mode) + " / " + ExtraBarsKeyMap.label(assignment.keyCode,0), issue.length > 0 ? issue : gate,
					ConsumableCache.find(assignment.itemKind), ExtraBarsActivationConfig.badge(model.prefix,model.mode,ExtraBarsKeyMap.keyHint(assignment.keyCode)));
				frozen.setInputState(false,model.mode); var until = flashes.get(bar.id + ":" + i); frozen.triggerStrength = gate.length == 0 && until != null ? Math.max(0, Math.min(1,(until-now)/0.30)) : 0;
				var mapped = ExtraBarsKeyMap.find(assignment.keyCode);
				if (bar.enabled && i < bar.slotCount && assignment.itemKind.length > 0 && entry != null && mapped != null && issue.length == 0) {
					routes.push({barId:bar.id,index:i,kind:assignment.itemKind,generation:generation,click:false}); keyTable.setI32(mapped.nativeCode*4,routes.length);
				}
			}
		}
		spark.observe(hero, model.sparkEnabled, now);
		var allowed = gate.length == 0 && model.enabled && model.prefix != "off" && model.mode != "long_press" && routes.length > 0;
		var requests:Array<ExtraBarsRequest> = [];
		try {
			var result = ExtraBarsNativeInput.configureMany(ExtraBarsNativeInput.prefixCode(model.prefix),model.mode == "hold" ? 1 : 2,allowed,generation,keyTable,1024);
			if (result < 0) { gate = "Native filter unavailable: " + (result == -1 ? "SFImGui capture API missing" : result == -2 ? "window thread mismatch" : result == -4 ? "invalid key table" : "subclass installation failed"); ExtraBarsNativeInput.reset(); }
			if (gate.length == 0) for (_ in 0...32) { var token = ExtraBarsNativeInput.take(generation); if (token == 0) break; if (token > 0 && token <= routes.length) requests.push(routes[token-1]); }
			inputActive = gate.length == 0 && (ExtraBarsNativeInput.status() & 1) != 0;
		} catch (e:Dynamic) { gate = "Input unavailable: " + Std.string(e); inputActive = false; ExtraBarsNativeInput.reset(); }
		for (bar in model.bars) for (slot in views.get(bar.id)) slot.setInputState(inputActive && bar.enabled,model.mode);
		if (gate.length > 0) { clicks = []; flashes.clear(); for (slots in views) for (slot in slots) slot.triggerStrength = 0; }
		for (click in clicks) requests.push(click); clicks = [];
		for (request in requests) dispatch(request,app,controller,hero,now);
	}
	function dispatch(request:ExtraBarsRequest, app:GameApp, controller:client.PlayerController, hero:ent.Hero, now:Float):Void {
		if (!ExtraBarsRequestPolicy.valid(model,request.barId,request.index,request.kind,request.generation,generation,request.click,gate.length==0 && blockReason(app,controller,hero).length==0,CursorCaptureFix.cursorFree)) return;
		var bar = model.find(request.barId);
		if (request.barId == "spark") { if (!model.sparkEnabled || request.kind != SparkCubeTracker.ITEM_ID) return; }
		else {
			if (!model.enabled || model.prefix == "off" || bar == null || !bar.enabled || (request.click && bar.hidden) || request.index < 0 || request.index >= bar.slotCount || bar.slots[request.index].itemKind != request.kind) return;
			if (!request.click) { bindings.refresh(now,true); if (bindingIssue(bar.id,request.index,bar.slots[request.index].keyCode,bar.slots[request.index].modifiers).length > 0) { clearTransientState(); return; } }
		}
		var outcome = ExtraBarsUsePolicy.request(request.kind,ConsumableCatalog.find(request.kind) != null,request.generation,generation,true,
			function(kind) return collect(hero,kind),function(item:Dynamic) { var live:st.Item = item; live.requestUse(hero); });
		lastResult = outcome.message;
		if (outcome.submitted) {
			flashes.set(request.barId+":"+request.index,now+0.30);
			if (bar != null) views.get(bar.id)[request.index].triggerStrength = 1; else spark.trigger(now);
			if (countChecks.length < 32) countChecks.push({kind:request.kind,before:outcome.countBefore,at:now});
		}
		log({event:"request",bar:request.barId,cell:request.index,item:request.kind,click:request.click,key:bar != null ? bar.slots[request.index].keyCode : 0,prefix:model.prefix,mode:model.mode,generation:generation,nativeState:request.click ? "click" : "filtered",submitted:outcome.submitted,before:outcome.countBefore,message:outcome.message});
	}
	function blockReason(app:GameApp, controller:client.PlayerController, hero:ent.Hero):String {
		if (hero == null || controller == null || app == null) return "No local hero.";
		if (capture.waitingRelease || CursorCaptureFix.keyboardCaptureActive || host.anyInteractiveOpen()) return "Editing: close SolarFlare tools to use items.";
		try {
			if (!hxd.Window.getInstance().get_isFocused()) return "Game is not focused.";
			if (app.get_isLoading()) return "Loading.";
			if (app.isInCutscene() || lib.Input.cinematicCapturesKbd()) return "Cutscene input is blocked.";
			if (hero.isDead()) return "Hero is dead.";
			if (controller.isInputBlocked()) return "Chat or a native window owns input.";
		} catch (_:Dynamic) { return "Gameplay eligibility unavailable."; }
		return "";
	}
	static function collect(hero:ent.Hero, kind:String):Array<ExtraBarsUseCandidate> {
		var out:Array<ExtraBarsUseCandidate> = []; var loadout = hero.loadout;
		if (loadout == null || loadout.inventory == null || loadout.equipment == null) throw "Carried inventory unavailable.";
		function scan(inv:st.Inventory, equipped:Bool):Void {
			var n = inv.getSize(); if (n < 0 || n > 1024) throw "Invalid inventory size.";
			for (i in 0...n) {
				if (equipped) { var eq:st.Equipment = inv; if (eq.isShortcut(i)) continue; }
				var stack = inv.getStack(i); if (stack == null || stack.item == null || solarflare.EngineText.cleanId(stack.item.kind) != kind) continue;
				out.push({item:stack.item,count:loadout.getDisplayStackCount(inv,stack),shortcut:false,usable:stack.item.canBeUsed(hero)});
			}
		} scan(loadout.inventory,false); scan(loadout.equipment,true); return out;
	}
	function log(event:Dynamic):Void {
		try { Reflect.setField(event,"at",haxe.Timer.stamp()); var dir = solarflare.ui.ModPaths.child("logs"); if (!sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
			var file = sys.io.File.append(haxe.io.Path.join([dir,"extrabars-prototype.jsonl"]),false); try { file.writeString(haxe.Json.stringify(event)+"\n"); file.close(); } catch(e:Dynamic) { file.close(); throw e; }
		} catch (_:Dynamic) {}
	}
	public function draw():Void { builder.draw(); }
	public function drawBar():Void {
		for (bar in model.bars) if (model.enabled && model.prefix != "off" && bar.enabled && !bar.hidden && views.exists(bar.id)) {
			var chrome = chromeFor(bar.id); chrome.locked.set(bar.locked); chrome.transparent.set(bar.transparent);
			overlay.draw(bar,views.get(bar.id),chrome,function() { builder.selectBar(bar.id); open.set(true); },function() { bar.hidden = true; SettingsStore.markDirty(); },function(index) queueClick(bar.id,index));
			bar.locked = chrome.locked.get(); bar.transparent = chrome.transparent.get();
		}
		if (model.sparkEnabled) { var chrome = chromeFor("spark"); chrome.locked.set(model.sparkLocked); chrome.transparent.set(model.sparkTransparent);
			spark.draw(chrome,model.sparkSize,function() open.set(true),function() queueClick("spark",0),function() { model.sparkEnabled = false; SettingsStore.markDirty(); solarflare.ObserveDemand.markStatusDemandDirty(); },function(size) { model.sparkSize=size; SettingsStore.markDirty(); },model.sparkShowHotkey,model.sparkHotkeyLabel);
			model.sparkLocked = chrome.locked.get(); model.sparkTransparent = chrome.transparent.get();
		}
	}
}
