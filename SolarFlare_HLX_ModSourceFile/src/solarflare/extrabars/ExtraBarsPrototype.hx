package solarflare.extrabars;

import imgui.ImGui;
import imgui.Enums.ImGuiKey;
import imgui.ref.BoolRef;
import imgui.ref.IntRef;
import solarflare.cdb.ConsumableCatalog;
import solarflare.aura.ConsumableCache;
import solarflare.ui.ConfigPanel;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.EditorWindow;
import solarflare.ui.GameIcons;
import solarflare.ui.ModPaths;
import solarflare.ui.SearchBar;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiLayout;
import solarflare.ui.UiScope;
import solarflare.extrabars.ExtraBarsUsePolicy.ExtraBarsUseCandidate;

/** Runtime-gated one-slot prototype. Native objects are touched only in observe/use. */
class ExtraBarsPrototype {
	public var open = new BoolRef(false);
	public var model = new ExtraBarsPrototypeModel();
	public var chrome = new solarflare.ui.HudChrome(80, 320);
	var slot = new ExtraBarsPrototypeSlot();
	var bar = new ExtraBarsPrototypeBar();
	public var gate(default, null):String = "Waiting for gameplay.";
	public var bindingIssue(default, null):String = "Unbound.";
	public var lastResult(default, null):String = "No request yet.";
	public var requestCount(default, null):Int = 0;
	public var countBefore(default, null):Int = 0;
	public var countAfter(default, null):Int = 0;
	var activation = new ExtraBarsActivationState();
	var rowsRef = new IntRef(2);
	var columnsRef = new IntRef(4);
	var slotSizeRef = new IntRef(48);
	var rawPrefixDown = false;
	var lastActivation = "";
	var nativeState = "unknown";
	var routeState = "Native";
	var bindings = new ExtraBarsNativeBindings();
	var enabledRef = new BoolRef(false);
	var search = new SearchBar("Search consumables");
	var previousHero:Dynamic;
	var generation:Int = 0;
	var lastKind = "";
	var lastKey = 0;
	var lastMods = 0;
	var lastEnabled = false;
	var rawBoundDown = false;
	var capture = new ExtraBarsCaptureState();
	var captureMessage = "";
	var suggestedChords = "";
	var suggestionsAt:Float = -1;
	var requestAt:Float = -1;
	var triggerUntil:Float = 0;
	static inline var TRIGGER_FLASH_SECONDS:Float = 0.30;
	var requestItem = "";
	var logFailure = "";
	var catalogViews:Array<{id:String, name:String, type:String, icon:String, count:Int, known:Bool}> = [];
	var sampledAt:Float = -1;
	var host:ConfigPanel;

	public function new(host:ConfigPanel) {
		this.host = host;
		for (entry in ConsumableCatalog.entries)
			catalogViews.push({id:entry.id, name:entry.name, type:entry.type, icon:ConsumableCatalog.iconKey(entry.id), count:0, known:false});
	}
	public function clearTransientState():Void {
		capture.clear();
		activation.reset(); ExtraBarsNativeInput.reset(); generation++; slot.progress = 0; routeState = "Native";
		slot.setInputState(false, model.mode);
		triggerUntil = 0; slot.triggerStrength = 0;
	}
	public function clearSession():Void {
		clearTransientState(); ExtraBarsNativeInput.shutdown(); previousHero = null; gate = "Waiting for gameplay.";
		rawBoundDown = false; rawPrefixDown = false; requestAt = -1; slot.clear();
		suggestedChords = ""; suggestionsAt = -1;
		for (view in catalogViews) { view.known = false; view.count = 0; }
	}
	public function observe(app:GameApp):Void {
		if (!model.enabled && !open.get()) { slot.enabled = false; activation.reset(); ExtraBarsNativeInput.reset(); triggerUntil = 0; slot.triggerStrength = 0; return; }
		var now = haxe.Timer.stamp();
		ExtraBarsKeyMap.initialize();
		bindings.refresh(now);
		var pendingKey = capture.takeKey();
		var pendingMods = capture.modifiers;
		if (pendingKey > 0) {
			bindings.refresh(now, true);
			var issue = validateBarKey(pendingKey, pendingMods);
			if (issue.length == 0) {
				model.keyCode = pendingKey; model.modifiers = pendingMods;
				SettingsStore.markDirty(); captureMessage = "Assigned " + ExtraBarsKeyMap.label(pendingKey, pendingMods) + ".";
			} else captureMessage = "Rejected " + ExtraBarsKeyMap.label(pendingKey, pendingMods) + ": " + issue;
			log({event:"binding", key:pendingKey, modifiers:pendingMods, prefix:model.prefix, mode:model.mode,
				baseState:bindings.describe(pendingKey), nativeState:"pass-through", accepted:issue.length == 0, message:captureMessage});
		}
		if (now - suggestionsAt >= 1) {
			suggestionsAt = now;
			var candidates:Array<Int> = [];
			for (label in ["F7", "F8", "F9", "F10", "F11", ";", "Quote", "K", "L", "P"]) {
				for (key in ExtraBarsKeyMap.keys) if (key.label == label) { candidates.push(key.code); break; }
			}
			var labels:Array<String> = [];
			for (code in candidates) {
				if (code == ExtraBarsKeyMap.prefixCode(model.prefix) || bindings.conflict(code, 0) != "") continue;
				labels.push(ExtraBarsKeyMap.label(code, 0));
				if (labels.length >= 3) break;
			}
			suggestedChords = labels.join(", ");
		}
		var hero:ent.Hero = null;
		var controller:client.PlayerController = null;
		try {
			controller = client.PlayerController.inst;
			if (controller != null) hero = controller.get_hero();
		} catch (_:Dynamic) {}
		if (hero != previousHero || model.itemKind != lastKind || model.keyCode != lastKey
				|| model.modifiers != lastMods || model.enabled != lastEnabled || model.signature() != lastActivation) {
			previousHero = hero; lastKind = model.itemKind; lastKey = model.keyCode;
			lastMods = model.modifiers; lastEnabled = model.enabled; lastActivation = model.signature();
			generation++; activation.reset(); ExtraBarsNativeInput.reset(); requestAt = -1; slot.progress = 0; routeState = "Native";
			triggerUntil = 0; slot.triggerStrength = 0;
		}
		ConsumableCache.sample(hero, now);
		if (now - sampledAt >= 0.25) {
			sampledAt = now;
			for (view in catalogViews) {
				var snap = ConsumableCache.find(view.id);
				view.count = snap != null ? snap.count : 0;
				view.known = snap != null && snap.known;
			}
			if (requestAt >= 0 && now > requestAt + 0.25) {
				var snap = ConsumableCache.find(requestItem);
				if (snap != null && snap.known) {
					countAfter = snap.count;
					if (countAfter != countBefore || now - requestAt >= 2) {
						lastResult = countAfter != countBefore
							? "Carried count changed " + countBefore + " → " + countAfter + "; verify the effect."
							: "Count unchanged after the request; inspect the effect or native rejection.";
						log({event:"observation", item:requestItem, before:countBefore, after:countAfter, message:lastResult});
						requestAt = -1;
					}
				}
			}
		}
		nativeState = bindings.describe(model.keyCode);
		bindingIssue = model.keyCode > 0 ? validateBarKey(model.keyCode, model.modifiers) : "Unbound.";
		gate = blockReason(app, controller, hero);
		if (ExtraBarsKeyMap.error.length > 0) gate = "Key resolution failed: " + ExtraBarsKeyMap.error;
		var allowed = gate.length == 0 && bindingIssue.length == 0;
		var entry = ConsumableCatalog.find(model.itemKind);
		var label = entry != null ? entry.name : (model.itemKind.length > 0 ? model.itemKind + " (unresolved)" : "Unassigned");
		slot.update(model.enabled && model.prefix != "off", label, entry != null ? ConsumableCatalog.iconKey(entry.id) : "",
			activationLabel(), bindingIssue.length > 0 ? bindingIssue : gate,
			ConsumableCache.find(model.itemKind), ExtraBarsActivationConfig.badge(model.prefix, model.mode, ExtraBarsKeyMap.keyHint(model.keyCode)),
			"");
		slot.setInputState(false, model.mode);
		if (!allowed) triggerUntil = 0;
		slot.triggerStrength = Math.max(0, Math.min(1, (triggerUntil - now) / TRIGGER_FLASH_SECONDS));
		var mappedKey = ExtraBarsKeyMap.find(model.keyCode);
		if (model.keyCode <= 0 || mappedKey == null) { activation.reset(); ExtraBarsNativeInput.reset(); return; }
		try {
			var filter = ExtraBarsNativeInput.configure(ExtraBarsNativeInput.prefixCode(model.prefix), mappedKey.nativeCode,
				model.mode == "hold" ? 1 : model.mode == "toggle" ? 2 : 0, allowed, generation);
			if (filter < 0) {
				ExtraBarsNativeInput.reset();
				gate = "Native input filter unavailable: " + (filter == -1 ? "SFImGui capture API missing." : filter == -2 ? "Window/input thread mismatch." : "Subclass installation failed.");
				slot.reason = gate; slot.progress = 0; triggerUntil = 0; slot.triggerStrength = 0; return;
			}
			var nativePressed = hxd.Key.isPressed(model.keyCode);
			var fire = ExtraBarsNativeInput.take(generation) > 0;
			var inputStatus = ExtraBarsNativeInput.status();
			var prefixDown = (inputStatus & 8) != 0;
			slot.setInputState(allowed && (inputStatus & 1) != 0, model.mode);
			slot.progress = 0;
			var currentRoute = (inputStatus & 1) != 0 ? "ExtraBars: native bar key filtered" : "Native";
			if (currentRoute != routeState) {
				routeState = currentRoute;
				log({event:"routing", key:model.keyCode, prefix:model.prefix, prefixDown:prefixDown, mode:model.mode,
					nativeState:(inputStatus & 1) != 0 ? "filtered" : "pass-through", baseState:nativeState, route:routeState});
			}
			if (fire) {
				bindings.refresh(now, true);
				bindingIssue = validateBarKey(model.keyCode, model.modifiers);
				if (bindingIssue.length > 0) { lastResult = bindingIssue; activation.reset(); ExtraBarsNativeInput.reset(); slot.setInputState(false, model.mode); triggerUntil = 0; slot.triggerStrength = 0; return; }
				var expectedGeneration = generation;
				var outcome = ExtraBarsUsePolicy.request(model.itemKind, ConsumableCatalog.find(model.itemKind) != null,
					expectedGeneration, generation, blockReason(app, controller, hero).length == 0,
					function(kind) return collect(hero, kind), function(item:Dynamic) {
						var live:st.Item = item;
						live.requestUse(hero);
					});
				lastResult = outcome.message;
				if (outcome.submitted) {
					triggerUntil = now + TRIGGER_FLASH_SECONDS; slot.triggerStrength = 1;
					requestCount++; countBefore = outcome.countBefore; countAfter = countBefore;
					requestAt = now; requestItem = model.itemKind;
				}
				log({event:"request", item:model.itemKind, key:model.keyCode, prefix:model.prefix, prefixDown:prefixDown,
					mode:model.mode, nativeState:"filtered", nativePressed:nativePressed, baseState:nativeState,
					inputStatus:inputStatus, nativeKey:mappedKey.nativeCode, generation:generation,
					submitted:outcome.submitted, before:outcome.countBefore, message:outcome.message});
			}
		} catch (e:Dynamic) { gate = "Input unavailable: " + Std.string(e); activation.reset(); ExtraBarsNativeInput.reset(); slot.setInputState(false, model.mode); triggerUntil = 0; slot.triggerStrength = 0; }
	}
	function activationLabel():String {
		var key = ExtraBarsKeyMap.label(model.keyCode, 0);
		return model.mode == "long_press" ? "Long-press retired; choose Hold or Toggle"
			: ExtraBarsActivationConfig.prefixLabel(model.prefix) + " / " + ExtraBarsActivationConfig.modeLabel(model.mode) + " / " + key;
	}
	function validateBarKey(code:Int, mods:Int):String {
		var details = " [Base " + bindings.describe(code) + "; prefix " + ExtraBarsActivationConfig.prefixLabel(model.prefix)
			+ "; mode " + ExtraBarsActivationConfig.modeLabel(model.mode) + "]";
		if (model.mode == "long_press") return "Long-press retired. Choose Hold or Toggle." + details;
		if (ExtraBarsKeyMap.find(code) != null && (ExtraBarsKeyMap.find(code).label == "Enter" || code == 91 || code == 92)) return "Reserved for chat/system input." + details;
		if (mods != 0) return "Ctrl/Alt/Shift remain native (dash/cursor/mount). Record a plain bar key." + details;
		if (model.mode != "long_press" && code == ExtraBarsKeyMap.prefixCode(model.prefix))
			return "Choose a bar key different from the prefix." + details;
		var issue = bindings.conflict(code, 0, true);
		return issue.length == 0 ? "" : issue + details + ". Try an unbound alternative shown below.";
	}
	function blockReason(app:GameApp, controller:client.PlayerController, hero:ent.Hero):String {
		if (!model.enabled || model.prefix == "off") return "ExtraBars disabled.";
		if (hero == null || controller == null || app == null) return "No local hero.";
		if (capture.waitingRelease || CursorCaptureFix.keyboardCaptureActive || host.anyInteractiveOpen()) return "Editing: close SolarFlare tools before testing.";
		try {
			if (!hxd.Window.getInstance().get_isFocused()) return "Game is not focused.";
			if (app.get_isLoading()) return "Loading.";
			if (app.isInCutscene() || lib.Input.cinematicCapturesKbd()) return "Cutscene input is blocked.";
			if (hero.isDead()) return "Hero is dead.";
			if (controller.isInputBlocked()) return "Chat or a native window owns input.";
		} catch (e:Dynamic) { return "Gameplay eligibility unavailable: " + Std.string(e); }
		return "";
	}
	static function collect(hero:ent.Hero, kind:String):Array<ExtraBarsUseCandidate> {
		var out:Array<ExtraBarsUseCandidate> = [];
		var loadout = hero.loadout;
		if (loadout == null || loadout.inventory == null || loadout.equipment == null) throw "Carried inventory unavailable.";
		function scan(inv:st.Inventory, equipped:Bool):Void {
			var n = inv.getSize();
			if (n < 0 || n > 1024) throw "Invalid inventory size.";
			for (i in 0...n) {
				if (equipped) { var eq:st.Equipment = inv; if (eq.isShortcut(i)) continue; }
				var stack = inv.getStack(i);
				if (stack == null || stack.item == null || solarflare.EngineText.cleanId(stack.item.kind) != kind) continue;
				out.push({item:stack.item, count:loadout.getDisplayStackCount(inv, stack),
					shortcut:false, usable:stack.item.canBeUsed(hero)});
			}
		}
		scan(loadout.inventory, false); scan(loadout.equipment, true);
		return out;
	}
	function log(event:Dynamic):Void {
		try {
			Reflect.setField(event, "at", haxe.Timer.stamp());
			var dir = ModPaths.child("logs");
			if (!sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
			var file = sys.io.File.append(haxe.io.Path.join([dir, "extrabars-prototype.jsonl"]), false);
			try { file.writeString(haxe.Json.stringify(event) + "\n"); file.close(); }
			catch (e:Dynamic) { file.close(); throw e; }
		} catch (e:Dynamic) { logFailure = "Diagnostic log unavailable: " + Std.string(e); }
	}
	public function drawBar():Void {
		bar.draw(slot, chrome, function() open.set(true), model.rows, model.columns, model.slotSize, function(pixels) {
			model.slotSize = pixels; SettingsStore.markDirty();
		});
	}
	public function draw():Void {
		var mapped = ExtraBarsKeyMap.find(model.keyCode);
		rawBoundDown = mapped != null && ImGui.isKeyDown(mapped.imgui);
		rawPrefixDown = ExtraBarsKeyMap.prefixUIDown(model.prefix);
		if (!open.get()) {
			if (capture.waitingRelease || capture.key > 0) clearTransientState();
			return;
		}
		EditorWindow.drawMenuWindow("ExtraBars Prototype###SolarFlare.ExtraBarsPrototype", open, 620, 780, function() {
			var available = ImGui.getContentRegionAvail();
			UiScope.child("##extrabars_editor_body", ImGui.vec2(0, Math.max(80, available.y - 28)), drawContents);
			solarflare.ui.HudChrome.of("ExtraBars.EditorResize").drawResizeCorner("ExtraBars.EditorResize", true,
				520, 640, 2400, 1600, null, 8);
		});
	}
	function drawContents():Void {
		ImGui.separatorText("Activation prototype");
		ImGui.textWrapped("Choose a prefix and mode, then assign one item and a plain bar key. Ctrl/Alt/Shift remain native dash/cursor/mount controls.");
		ImGui.textWrapped("Close editors before testing. Hold or Toggle routes only the assigned bar key to ExtraBars; native keys remain immediate outside bars mode. Long-press is retired.");
		ImGui.separatorText("Bar layout");
		UiLayout.propertyGrid("##extrabars_layout", function() {
			UiLayout.propertyRow("Rows / columns", function() {
				UiLayout.inlinePair("##extrabars_grid_dimensions", function(width:Single) {
					rowsRef.set(model.rows);
					if (ImGui.sliderInt("##extrabars_rows", rowsRef, 1, Std.int(8 / model.columns), "%d rows")) {
						model.setGrid(rowsRef.get(), model.columns); SettingsStore.markDirty();
					}
				}, function(width:Single) {
					columnsRef.set(model.columns);
					if (ImGui.sliderInt("##extrabars_columns", columnsRef, 1, Std.int(8 / model.rows), "%d columns")) {
						model.setGrid(model.rows, columnsRef.get()); SettingsStore.markDirty();
					}
				});
			}, "At most eight cells. Reduce one dimension before increasing the other.");
			UiLayout.propertyRow("Presets", function() {
				UiLayout.inlineSplit("##extrabars_grid_presets", 4, function(index:Int, width:Single) {
					var rows = [1, 2, 4, 8][index]; var columns = [8, 4, 2, 1][index];
					if (ImGui.button(rows + "x" + columns + "##extrabars_preset_" + index, ImGui.vec2(width, 0))) {
						model.setGrid(rows, columns); SettingsStore.markDirty();
					}
				});
			});
			UiLayout.propertyRow("Slot size", function() {
				slotSizeRef.set(model.slotSize);
				if (ImGui.sliderInt("##extrabars_slot_size", slotSizeRef, 24, 96, "%d px")) {
					model.slotSize = ExtraBarsGrid.size(slotSizeRef.get()); SettingsStore.markDirty();
				}
			});
		});
		ImGui.textWrapped("Drag the bottom-right corner to resize the editor or HUD. The first cell is the active test item; other cells are empty until the full builder. Layout changes retain the test assignment.");
		UiLayout.propertyGrid("##extrabars_prototype_properties", function() {
			UiLayout.propertyRow("Enabled", function() {
				enabledRef.set(model.enabled);
				if (ImGui.checkbox("##extrabars_prototype_enabled", enabledRef)) {
					model.enabled = enabledRef.get(); SettingsStore.markDirty();
				}
			});
			UiLayout.propertyRow("Prefix", function() {
				drawChoice("##extrabars_prefix", ExtraBarsActivationConfig.prefixes, model.prefix,
					ExtraBarsActivationConfig.prefixLabel, function(value) {
						model.prefix = value; clearTransientState(); SettingsStore.markDirty();
					});
			});
			UiLayout.propertyRow("Mode", function() {
				drawChoice("##extrabars_mode", ExtraBarsActivationConfig.liveModes, model.mode,
					ExtraBarsActivationConfig.modeLabel, function(value) {
						model.mode = value; clearTransientState(); SettingsStore.markDirty();
					});
			});
			UiLayout.propertyRow("Assigned item", function() {
				var entry = ConsumableCatalog.find(model.itemKind);
				ImGui.text(entry != null ? entry.name : (model.itemKind.length > 0 ? model.itemKind : "Unassigned"));
			});
			UiLayout.propertyRow("Hotkey", function() {
				ImGui.text(ExtraBarsKeyMap.label(model.keyCode, 0));
			});
			UiLayout.propertyRow("Binding", function() {
				UiLayout.inlinePair("##extrabars_binding_actions", function(width:Single) {
					if (ImGui.button("Record bar key##extrabars_record", ImGui.vec2(width, 0))) {
						capture.start(); captureMessage = capture.message;
					}
				}, function(width:Single) {
					if (ImGui.button("Clear##extrabars_clear", ImGui.vec2(width, 0))) {
						clearTransientState(); model.keyCode = 0; model.modifiers = 0; SettingsStore.markDirty();
					}
				});
			});
		});
		drawCapture();
		if (captureMessage.length > 0) ImGui.textWrapped(captureMessage);
		if (bindingIssue.length > 0) ImGui.textWrapped(bindingIssue);
		ImGui.textWrapped("Base " + nativeState + "; prefix " + ExtraBarsActivationConfig.prefixLabel(model.prefix)
			+ "; mode " + ExtraBarsActivationConfig.modeLabel(model.mode) + ". Active bar keys use the native input filter.");
		if (model.mode == "long_press") ImGui.textWrapped("Long-press is retired. Choose Hold or Toggle above.");
		else ImGui.textWrapped(model.mode == "hold" ? "Hold the prefix, then press the bar key. Release the prefix to leave ExtraBars."
			: "Tap the prefix to toggle ExtraBars on/off, then press the bar key.");
		if (suggestedChords.length > 0) ImGui.textWrapped("Checked unbound alternatives: " + suggestedChords + ".");
		ImGui.separatorText("Consumable");
		var query = search.draw("##extrabars_consumable_search");
		UiScope.child("##extrabars_prototype_catalog", ImGui.vec2(0, 190), function() {
			for (view in catalogViews) {
				if (query.length > 0 && (view.name + " " + view.id + " " + view.type).toLowerCase().indexOf(query) < 0) continue;
				var pos = ImGui.getCursorScreenPos();
				var selected = ImGui.selectable("      " + view.name + "  [" + view.type + "]  "
					+ (view.known ? Std.string(view.count) : "?") + "##extrabars_item_" + view.id,
					model.itemKind == view.id, 0, ImGui.vec2(0, 30));
				if (selected) { model.itemKind = view.id; SettingsStore.markDirty(); }
				GameIcons.drawKey(ImGui.getWindowDrawList(), view.icon, pos.x, pos.y, 26, 26);
			}
		});
		ImGui.separatorText("Test status");
		ImGui.textWrapped(gate.length == 0 ? "Gameplay input eligible." : gate);
		ImGui.textWrapped(routeState + "; " + activationLabel());
		ImGui.textWrapped(lastResult);
		ImGui.text("Submitted requests: " + requestCount + "   Count: " + countBefore + " → " + countAfter);
		if (logFailure.length > 0) ImGui.textWrapped(logFailure);
		UiLayout.inlinePair("##extrabars_test_actions", function(width:Single) {
			if (ImGui.button("Save##extrabars_save", ImGui.vec2(width, 32))) solarflare.ui.UiActionQueue.save();
		}, function(width:Single) {
			if (ImGui.button("Close editors and test##extrabars_test", ImGui.vec2(width, 32))) host.closeInteractiveWindows();
		});
	}
	function drawChoice(id:String, values:Array<String>, current:String, label:String->String, apply:String->Void):Void {
		if (!ImGui.beginCombo(id, label(current))) return;
		var failure:Dynamic = null;
		try {
			for (value in values) if (ImGui.selectable(label(value), value == current)) apply(value);
		} catch (e:Dynamic) { failure = e; }
		ImGui.endCombo();
		if (failure != null) UiScope.report("combo", id, failure);
	}
	function drawCapture():Void {
		if (!capture.waitingRelease) return;
		var anyDown = ExtraBarsKeyMap.uiModifiers() != 0 || ImGui.isKeyDown(ImGuiKey.Escape);
		var pressedKey = 0;
		for (entry in ExtraBarsKeyMap.keys) {
			if (ImGui.isKeyDown(entry.imgui)) anyDown = true;
			if (pressedKey == 0 && ImGui.isKeyPressed(entry.imgui, false)) pressedKey = entry.code;
		}
		capture.step(anyDown, ImGui.isKeyPressed(ImGuiKey.Escape, false), pressedKey, ExtraBarsKeyMap.uiModifiers());
		captureMessage = capture.message;
	}
}
