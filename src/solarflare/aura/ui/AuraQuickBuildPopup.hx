package solarflare.aura.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiChildFlags;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiHoveredFlags;
import imgui.Enums.ImGuiKey;
import imgui.Enums.ImGuiWindowFlags;
import imgui.ref.BoolRef;
import solarflare.aura.AuraConfig;
import solarflare.aura.AuraEffect;
import solarflare.aura.AuraEngine;
import solarflare.aura.AuraDef;
import solarflare.aura.AuraPack;
import solarflare.aura.AuraQuickBuildDraft;
import solarflare.aura.AuraQuickBuildRules;
import solarflare.aura.AuraTimer;
import solarflare.aura.AuraTimingReferences;
import solarflare.aura.AuraTimingReferencePolicy;
import solarflare.aura.AuraVisualRenderer;
import solarflare.aura.preview.AdvancedAuraPreview;
import solarflare.aura.signal.AuraConditionUiState;
import solarflare.aura.signal.AuraSignalCatalog;
import solarflare.aura.signal.AuraSignalDescriptor;
import solarflare.cdb.AuraCatalog;
import solarflare.cdb.CdbAuraTable;
import solarflare.cdb.ConsumableCatalog;
import solarflare.ui.ByteUtil;
import solarflare.ui.GameIcons;
import solarflare.ui.UiChrome;
import solarflare.ui.UiLayout;
import solarflare.ui.UiScope;

/** Creation-only modal; drawing and Cancel never mutate live configuration. */
class AuraQuickBuildPopup {
	static inline var TITLE:String = "Quick Build Aura###ab_quick_build_modal";
	static inline var SEARCH_CAP:Int = 160;
	/** Content width at which the preview moves beside the cards. */
	static inline var SIDE_MIN_WIDTH:Single = 760;
	static inline var FOOTER_HELP:String = "Configure multiple conditions, expressions, countdown/count-up, and recurring Status timers in Advanced.";
	var draft:AuraQuickBuildDraft = null;
	var visible = new BoolRef(false);
	var requested = false;
	var group = "";
	var signalSearch = new hl.Bytes(SEARCH_CAP);
	var subjectSearch = new hl.Bytes(SEARCH_CAP);
	var iconSearch = new hl.Bytes(SEARCH_CAP);
	var inputs = new AuraConditionUiState();
	var glowColor = new hl.Bytes(16);
	var preview = new AdvancedAuraPreview();
	var commitIssue = "";
	var castRank:Null<Int> = null;
	var castRankChosen:Bool = false;

	public function new() {}

	function disabled(blocked:Bool, body:Void->Void):Void {
		ImGui.beginDisabled(blocked);
		try { body(); } catch (e:Dynamic) { ImGui.endDisabled(); throw e; }
		ImGui.endDisabled();
	}

	public function start(seed:AuraQuickBuildDraft = null):Void {
		draft = seed != null ? seed : new AuraQuickBuildDraft();
		visible.set(true);
		requested = true;
		var signal = AuraSignalCatalog.find(draft.condition.signal);
		group = signal != null ? signal.group : "";
		commitIssue = "";
		preview.reset();
		for (buf in [signalSearch, subjectSearch, iconSearch]) ByteUtil.clearBytes(buf, SEARCH_CAP);
		inputs.sync(draft.condition);
		castRank = null; castRankChosen = false;
		applyTimingReference(draft.cooldownReference);
		var color = draft.aura.glowColor;
		glowColor.setF32(0, ((color >>> 16) & 255) / 255.0);
		glowColor.setF32(4, ((color >>> 8) & 255) / 255.0);
		glowColor.setF32(8, (color & 255) / 255.0);
		glowColor.setF32(12, ((color >>> 24) & 255) / 255.0);
	}

	public function cancel():Void {
		draft = null;
		visible.set(false);
		requested = false;
		commitIssue = "";
	}

	/** Sets offered by the Scope picker; refreshed from the library each draw. */
	var setsSource:AuraConfig;

	public function draw(cfg:AuraConfig, commit:AuraQuickBuildDraft->Bool->String):Void {
		setsSource = cfg;
		if (draft == null) return;
		if (requested) { ImGui.openPopup(TITLE); requested = false; }
		// Size from the screen, not the builder window: the preview needs room even when the builder is small.
		var screenW:Single = 1920;
		var screenH:Single = 1080;
		var screenCx:Single = 960;
		var screenCy:Single = 540;
		try {
			var vp = ImGui.getMainViewport();
			var center = vp != null ? ImGui.ImGuiViewport_GetCenter(vp) : null;
			if (center != null && center.x > 160 && center.y > 120) { screenCx = center.x; screenCy = center.y; screenW = center.x * 2; screenH = center.y * 2; }
		} catch (_:Dynamic) {}
		var width:Single = Math.max(520, Math.min(1180, screenW - 64));
		var height:Single = Math.max(440, Math.min(900, screenH - 80));
		ImGui.setNextWindowSize(ImGui.vec2(width, height), ImGuiCond.Appearing);
		ImGui.setNextWindowPos(ImGui.vec2(screenCx - width * 0.5, screenCy - height * 0.5), ImGuiCond.Appearing);
		ImGui.setNextWindowSizeConstraints(ImGui.vec2(520, 440), ImGui.vec2(Math.max(520, screenW - 32), Math.max(440, screenH - 32)));
		if (!ImGui.beginPopupModal(TITLE, visible, ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse)) {
			if (!visible.get()) cancel();
			return;
		}
		try {
			if (!visible.get() || ImGui.isKeyPressed(ImGuiKey.Escape, false)) {
				ImGui.closeCurrentPopup();
				cancel();
			} else {
				var finished = false;
				var avail = ImGui.getContentRegionAvail();
				if (avail.x >= SIDE_MIN_WIDTH) {
					// Wide: the cards on the left, a permanent preview and the actions on the right.
					var sideWidth:Single = Math.min(420, Math.max(320, avail.x * 0.36));
					UiScope.child("##ab_quick_body", ImGui.vec2(avail.x - sideWidth - 8, 0), function() drawCards(cfg));
					ImGui.sameLine(0, 8);
					UiScope.child("##ab_quick_side", ImGui.vec2(0, 0), function() finished = drawSide(cfg, commit),
						ImGuiChildFlags.Borders | ImGuiChildFlags.AlwaysUseWindowPadding);
				} else {
					// Narrow: cards on top, then the preview and actions underneath.
					var helpH = ImGui.calcTextSize(FOOTER_HELP, false, avail.x).y;
					var footerH:Single = 126 + ImGui.getFrameHeight() + 36 + 36 + 26 + helpH + 48;
					var bodyH:Single = Math.max(64, avail.y - footerH);
					UiScope.child("##ab_quick_body", ImGui.vec2(0, bodyH), function() drawCards(cfg));
					ImGui.separator();
					drawPreviewStage(cfg, 118);
					finished = drawActions(cfg, commit, false);
				}
				if (finished) { ImGui.closeCurrentPopup(); cancel(); }
			}
		} catch (e:Dynamic) { ImGui.endPopup(); throw e; }
		ImGui.endPopup();
	}

	function drawCards(cfg:AuraConfig):Void {
		drawIdentity();
		card("watch", "1. What are we watching?", drawWatch);
		card("appearance", "2. What should it look like?", function() drawAppearance(cfg));
		card("timing", "3. When does it show?", drawTiming);
	}

	function card(id:String, title:String, body:Void->Void):Void {
		UiScope.child("##ab_quick_card_" + id, ImGui.vec2(0, 0), function() {
			UiChrome.subHeader(title);
			body();
		}, ImGuiChildFlags.Borders | ImGuiChildFlags.AutoResizeY | ImGuiChildFlags.AlwaysUseWindowPadding,
			ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse);
		ImGui.spacing();
	}

	function drawIdentity():Void {
		var a = draft.aura;
		UiLayout.propertyGrid("##ab_quick_identity", function() {
			UiLayout.propertyRow("Name", function() {
				if (ImGui.inputText("##ab_quick_name", a.nameBuf, AuraDef.NAME_BUF))
					a.name = ByteUtil.readBytes(a.nameBuf, AuraDef.NAME_BUF);
			});
			UiLayout.propertyRow("Aura Set", function() {
				var currentSet = setsSource != null ? setsSource.findSet(AuraConfig.tagOf(a)) : null;
				if (ImGui.beginCombo("##ab_quick_scope", currentSet != null ? currentSet.name : a.fight.length == 0 ? "None" : a.fight)) {
					try {
						var options:Array<{id:String, name:String}> = [{id: "", name: "None"}];
						if (setsSource != null) for (set in setsSource.sets) if (set != null) options.push({id: set.id, name: set.name});
						for (option in options)
							if (ImGui.selectable(option.name + "##ab_quick_scope_" + option.id, AuraConfig.tagOf(a) == option.id)) {
								a.fight = option.id; a.syncFightBuf();
							}
						ImGui.separator();
						if (ImGui.inputTextWithHint("##ab_quick_custom_scope", "Custom encounter tag", a.fightBuf, AuraDef.FIGHT_BUF))
							a.fight = ByteUtil.readBytes(a.fightBuf, AuraDef.FIGHT_BUF);
					} catch (e:Dynamic) { ImGui.endCombo(); throw e; }
					ImGui.endCombo();
				}
			});
		});
	}

	function chooseSignal(id:String):Void {
		if (AuraQuickBuildRules.selectSignal(draft.condition, id)) {
			group = AuraSignalCatalog.find(id).group;
			inputs.sync(draft.condition);
			commitIssue = "";
			castRank = null; castRankChosen = false;
			applyTimingReference("CDB");
		}
	}

	function drawWatch():Void {
		var labels = ["Skill ready", "Instant cast", "Low HP", "Buff stacks", "Enemy cast"];
		var signals = ["skill.ready", "skill.instantReady", "resource.health.ratio", "status.stacks", "event.cast.active"];
		var columns = UiLayout.columnCount(ImGui.getContentRegionAvail().x, 112, 5);
		for (row in 0...Std.int(Math.ceil(labels.length / columns))) {
			UiLayout.inlineSplit("##ab_quick_picks_" + row, columns, function(col:Int, w:Single) {
				var i = row * columns + col;
				if (i < labels.length && UiChrome.navButton(labels[i] + "##ab_quick_pick_" + i,
					draft.condition.signal == signals[i], ImGui.vec2(w, 28))) chooseSignal(signals[i]);
			});
		}
		ImGui.spacing();
		UiLayout.propertyGrid("##ab_quick_watch", function() {
			UiLayout.propertyRow("Group", function() {
				if (ImGui.beginCombo("##ab_quick_group", group.length == 0 ? "Choose group..." : group)) {
					try {
						for (g in AuraSignalCatalog.groups()) if (ImGui.selectable(g + "##ab_quick_group_" + g, group == g)) {
							group = g;
							ByteUtil.clearBytes(signalSearch, SEARCH_CAP);
						}
					} catch (e:Dynamic) { ImGui.endCombo(); throw e; }
					ImGui.endCombo();
				}
			});
			UiLayout.propertyRow("Signal", drawSignalPicker);
			var d = AuraSignalCatalog.find(draft.condition.signal);
			if (d != null && d.subjectKind != "" && d.subjectKind != "script")
				UiLayout.propertyRow("Subject", function() drawSubjectPicker(d));
			if (d != null && d.subjectKind != "script") drawComparison(d);
		});
		if (group == "Scripting" || draft.condition.signal == "custom.script")
			ImGui.textWrapped("Custom expressions are configured through Open in Advanced below.");
		ImGui.textWrapped(draft.summary());
		if (draft.requirements.length > 0) {
			var needs = [for (r in draft.requirements) AuraQuickBuildRules.conditionSummary(r)];
			ImGui.textDisabled("Also requires: " + needs.join(", "));
		}
	}

	function drawSignalPicker():Void {
		var d = AuraSignalCatalog.find(draft.condition.signal);
		if (!ImGui.beginCombo("##ab_quick_signal", d == null ? "Choose signal..." : d.label)) return;
		try {
			ImGui.inputTextWithHint("##ab_quick_signal_search", "Search signals...", signalSearch, SEARCH_CAP);
			var search = ByteUtil.readBytes(signalSearch, SEARCH_CAP);
			var shown = 0;
			for (item in AuraSignalCatalog.inGroup(group)) {
				if (!AuraCatalog.matchesSearch(item.id, item.label, search)) continue;
				shown++;
				if (ImGui.selectable(item.label + "##ab_quick_signal_" + item.id, draft.condition.signal == item.id)) chooseSignal(item.id);
			}
			if (shown == 0) ImGui.textDisabled(group == "" ? "Choose a group first." : "No matching signals.");
		} catch (e:Dynamic) { ImGui.endCombo(); throw e; }
		ImGui.endCombo();
	}

	function drawSubjectPicker(d:AuraSignalDescriptor):Void {
		var c = draft.condition;
		var label = c.subjectLabel.length > 0 ? c.subjectLabel : c.subject;
		if (!ImGui.beginCombo("##ab_quick_subject", label.length > 0 ? label : "Choose " + d.subjectKind + "...")) return;
		try {
			ImGui.inputTextWithHint("##ab_quick_subject_search", "Search names or IDs...", subjectSearch, SEARCH_CAP);
			var search = ByteUtil.readBytes(subjectSearch, SEARCH_CAP);
			UiScope.child("##ab_quick_subject_list", ImGui.vec2(0, 240), function() {
				var shown = 0;
				if (d.subjectKind == "consumable") {
					for (entry in ConsumableCatalog.entries) if (AuraCatalog.matchesSearch(entry.id, entry.name, search)) {
						shown++; subjectRow(entry.id, entry.name, "consumable", d.subjectKind);
					}
				} else if (d.subjectKind == "status") {
					var frame = AuraEngine.signalFrame();
					if (frame != null) {
						ImGui.separatorText("Currently on your character");
						for (i in 0...frame.statusCount) {
							var status = frame.statuses[i];
							if (!status.known || !status.present) continue;
							var name = AuraCatalog.label(status.rawId);
							if (AuraCatalog.matchesSearch(status.rawId, name, search)) {
								shown++; subjectRow(status.rawId, name, "live", "status");
							}
						}
					}
					for (rank in [0, 2, 3]) {
						ImGui.separatorText(rank == 0 ? "Status / Proc IDs" : rank == 2 ? "Skills granting Statuses" : "Status categories");
						for (entry in AuraCatalog.entries) {
							if (AuraCatalog.statusPickRank(entry.id, entry.kind) != rank || !AuraCatalog.entryMatchesSearch(entry, search)) continue;
							shown++; subjectRow(entry.id, entry.name, entry.kind, "status");
						}
					}
				} else {
					for (entry in AuraCatalog.entries) {
						if (!AuraCatalog.matchesSubject(entry.kind, d.subjectKind) || !AuraCatalog.entryMatchesSearch(entry, search)) continue;
						shown++; subjectRow(entry.id, entry.name, entry.kind, d.subjectKind);
					}
				}
				if (shown == 0) ImGui.textDisabled("No matching subjects.");
			});
		} catch (e:Dynamic) { ImGui.endCombo(); throw e; }
		ImGui.endCombo();
	}

	function subjectRow(id:String, name:String, kind:String, subjectKind:String):Void {
		var resolved = AuraQuickBuildRules.subjectId(id, subjectKind);
		if (ImGui.selectable((name.length > 0 ? name : id) + " [" + id + "]##ab_quick_subject_" + kind + "_" + id,
			draft.condition.subject == resolved)) {
			draft.condition.subject = resolved;
			draft.condition.subjectLabel = name;
			castRank = null; castRankChosen = false;
			applyTimingReference("CDB");
			commitIssue = "";
			ImGui.closeCurrentPopup();
		}
	}

	function drawComparison(d:AuraSignalDescriptor):Void {
		var c = draft.condition;
		UiLayout.propertyRow("Comparison", function() {
			if (ImGui.beginCombo("##ab_quick_operator", AuraQuickBuildRules.opLabel(c.op))) {
				try {
					for (op in AuraQuickBuildRules.operators(d))
						if (ImGui.selectable(AuraQuickBuildRules.opLabel(op) + "##ab_quick_operator_" + op, c.op == op)) c.op = op;
				} catch (e:Dynamic) { ImGui.endCombo(); throw e; }
				ImGui.endCombo();
			}
		});
		if (d.id == "status.present") return;
		UiLayout.propertyRow(d.kind == Boolean ? "Value" : "Threshold", function() {
			switch (d.kind) {
				case Boolean:
					if (ImGui.checkbox("True##ab_quick_bool", inputs.boolRef)) c.boolValue = inputs.boolRef.get();
				case Percent:
					if (ImGui.inputFloat("##ab_quick_percent", inputs.percentRef, 1, 10, "%.2f%%")) {
						inputs.percentRef.set(Math.max(0, Math.min(100, inputs.percentRef.get())));
						inputs.pullPercent(c);
					}
				case Identity:
					ImGui.textDisabled("Configure this value in Advanced.");
				default:
					if (ImGui.inputFloat("##ab_quick_number", inputs.numberRef, d.kind == Count ? 1 : 0.1, 10,
						d.kind == Count ? "%.0f" : d.kind == Duration ? "%.1f seconds" : "%.2f")) {
						c.numberValue = inputs.numberRef.get();
						if (d.kind == Count) c.numberValue = Math.round(c.numberValue);
						// Validation reports invalid entries; merely drawing never repairs them.
						inputs.numberRef.set(c.numberValue);
					}
			}
		});
	}

	function drawAppearance(cfg:AuraConfig):Void {
		if (draft.face != "Banner" && draft.aura.showBanner.get())
			ImGui.textWrapped("This preset also includes a banner alert. Choosing a different face replaces that presentation.");
		var faces = ["Icon", "Glow", "Bar", "Banner"];
		var columns = UiLayout.columnCount(ImGui.getContentRegionAvail().x, 108, 4);
		for (row in 0...Std.int(Math.ceil(faces.length / columns))) {
			UiLayout.inlineSplit("##ab_quick_faces_" + row, columns, function(col:Int, w:Single) {
				var i = row * columns + col;
				if (i < faces.length && UiChrome.navButton(faces[i] + "##ab_quick_face_" + i,
					draft.face == faces[i], ImGui.vec2(w, 42))) draft.setFace(faces[i]);
			});
		}
		UiLayout.propertyGrid("##ab_quick_appearance", function() {
			if (draft.face == "Glow") UiLayout.propertyRow("Glow color", function() {
				if (ImGui.colorEdit4("##ab_quick_glow_color", glowColor)) {
					var packed = ImGui.colorConvertFloat4ToU32(ImGui.vec4(glowColor.getF32(0), glowColor.getF32(4), glowColor.getF32(8), glowColor.getF32(12)));
					draft.aura.glowColor = solarflare.aura.AuraGlowStyle.fromImGuiColor(packed);
				}
			});
			if (draft.face == "Banner") {
				UiLayout.propertyRow("Banner text", function() {
					if (ImGui.inputTextWithHint("##ab_quick_banner", "Leave empty to use the aura name", draft.aura.bannerBuf, AuraDef.BANNER_BUF))
						draft.aura.bannerText = ByteUtil.readBytes(draft.aura.bannerBuf, AuraDef.BANNER_BUF);
				});
				UiLayout.propertyRow("Hold seconds", function() drawHold("banner"));
			}
			if (draft.face == "Icon" || draft.face == "Glow") {
				var hasIcon = GameIcons.hasKey(draft.aura.preferredIconId());
				if (!hasIcon || draft.aura.iconId.length > 0) UiLayout.propertyRow("Icon", drawIconPicker);
				else UiLayout.propertyRow("Icon", function() ImGui.textDisabled("Automatic from the watched subject"));
			}
			UiLayout.propertyRow("Overlays", drawOverlays);
			UiLayout.propertyRow("Show icon",function() ImGui.checkbox("##ab_quick_show_icon",draft.aura.showIcon));
			UiLayout.propertyRow("Automatic timer text",function() ImGui.checkbox("Use global countdown##ab_quick_global_countdown",draft.aura.useGlobalCountdown));
		});
		if (cfg.countdownAll.get() && draft.aura.useGlobalCountdown.get())
			ImGui.textWrapped("Automatic countdown is enabled globally. Timer text may appear even when Countdown is off here.");
		if (draft.face == "Banner") ImGui.textDisabled("Face overlays are retained for when you choose Icon, Glow, or Bar.");
	}

	function drawOverlays():Void {
		var keys = ["Stacks", "Counter", "Countdown", "Fuse", "Label"];
		var columns = UiLayout.columnCount(ImGui.getContentRegionAvail().x, 108, 5);
		for (row in 0...Std.int(Math.ceil(keys.length / columns))) {
			UiLayout.inlineSplit("##ab_quick_overlays_" + row, columns, function(col:Int, w:Single) {
				var i = row * columns + col;
				if (i >= keys.length) return;
				var key = keys[i];
				var ref = draft.overlay(key);
				if (UiChrome.toggleTile("##ab_quick_overlay_" + key, key, ref.get(), w, 32, false, false)) draft.toggleOverlay(key);
				if (ImGui.isItemHovered()) ImGui.setTooltip(key == "Stacks" ? "Live buff/debuff (Status) stacks."
					: key == "Counter" ? "Persistent total of false-to-true condition transitions."
					: key == "Countdown" ? "Show timer text when remaining or elapsed time is available. Configure timers in Advanced."
					: key == "Fuse" ? "Show the existing remaining-time fuse." : "Show the aura label.");
			});
		}
	}

	function drawIconPicker():Void {
		if (!ImGui.beginCombo("##ab_quick_icon", draft.aura.iconId.length > 0 ? draft.aura.iconId : "Choose an icon...")) return;
		try {
			if (ImGui.selectable("Automatic##ab_quick_icon_auto", draft.aura.iconId.length == 0)) {
				draft.aura.iconId = ""; draft.aura.syncIconBuf();
			}
			ImGui.inputTextWithHint("##ab_quick_icon_search", "Search icons...", iconSearch, SEARCH_CAP);
			var search = ByteUtil.readBytes(iconSearch, SEARCH_CAP);
			UiScope.child("##ab_quick_icon_list", ImGui.vec2(0, 220), function() {
				var shown = 0;
				for (entry in AuraCatalog.entries) {
					if (!AuraCatalog.entryMatchesSearch(entry, search)) continue;
					var stem = CdbAuraTable.iconStem(entry.id);
					if (!GameIcons.hasKey(stem.length > 0 ? stem : entry.id)) continue;
					shown++;
					if (ImGui.selectable(entry.name + " [" + entry.id + "]##ab_quick_icon_" + entry.id, draft.aura.iconId == entry.id)) {
						draft.aura.iconId = entry.id; draft.aura.syncIconBuf(); ImGui.closeCurrentPopup();
					}
				}
				if (shown == 0) ImGui.textDisabled("No matching usable icons.");
			});
		} catch (e:Dynamic) { ImGui.endCombo(); throw e; }
		ImGui.endCombo();
	}

	function drawTiming():Void {
		UiLayout.propertyGrid("##ab_quick_timing", function() {
			UiLayout.propertyRow("Show", function() {
				var labels = ["While true", "Flash then hold", "Alert once"];
				var whens = [AuraEffect.WHEN_WHILE_TRUE, AuraEffect.WHEN_ON_RISE_HOLD, AuraEffect.WHEN_ON_RISE];
				for (i in 0...labels.length)
					if (ImGui.radioButton(labels[i] + "##ab_quick_when_" + i, draft.behavior == whens[i])) draft.setBehavior(whens[i]);
			});
			if (draft.behavior == AuraEffect.WHEN_ON_RISE_HOLD) UiLayout.propertyRow("Hold seconds", function() drawHold("flash"));
			UiLayout.propertyRow("Timer", function() {
				var modes = ["Off", "Count down", "Count up"];
				UiLayout.inlineSplit("##ab_quick_timer_modes", 3, function(i:Int, w:Single) {
					if (UiChrome.navButton(modes[i] + "##ab_quick_timer_mode_" + i, draft.aura.timerMode == i, ImGui.vec2(w, 28))) {
						draft.setTimerMode(i); applyTimingReference(draft.cooldownReference);
					}
				});
			});
			if (AuraTimingReferencePolicy.isCooldown(draft.condition.signal)) {
				UiLayout.propertyRow("Cooldown timing", function() {
					var choices = ["Game time", "CDB", "Observed"];
					UiLayout.inlineSplit("##ab_quick_cooldown_reference", 3, function(i:Int, w:Single) {
						if (UiChrome.navButton(choices[i] + "##ab_quick_cd_" + i, draft.cooldownReference == choices[i], ImGui.vec2(w, 28))) applyTimingReference(choices[i]);
					});
				}, "Starts when the skill enters cooldown and follows live seconds, including modifiers. CDB and Observed supply an estimate only if live timing is unavailable.");
			}
			if (AuraTimingReferencePolicy.isCast(draft.condition.signal)) UiLayout.propertyRow("Cast rank", function() {
				var ranks = solarflare.castbar.LearnedCastTimes.ranks(draft.condition.subject);
				if (ranks.indexOf(null) < 0) ranks.unshift(null);
				if (ranks.indexOf(castRank) < 0) ranks.push(castRank);
				if (ImGui.beginCombo("##ab_quick_cast_rank", castRank == null ? "Unknown" : "Rank " + castRank)) {
					try {
						for (rank in ranks) if (ImGui.selectable((rank == null ? "Unknown" : "Rank " + rank) + "##ab_quick_cast_rank_" + rank, castRank == rank)) {
							castRank = rank; castRankChosen = true; applyTimingReference("CDB");
						}
					} catch (e:Dynamic) { ImGui.endCombo(); throw e; }
					ImGui.endCombo();
				}
			}, "Defaults to the observed rank when available. Choose a recorded rank to use its matching cast time.");
			if (AuraTimingReferencePolicy.isCooldown(draft.condition.signal) || AuraTimingReferencePolicy.isCast(draft.condition.signal)) {
				UiLayout.propertyRow(AuraTimingReferencePolicy.isCooldown(draft.condition.signal) ? "Cooldown estimate" : "Timer seconds", function() {
					var seconds = draft.aura.timerSeconds.get();
					ImGui.textWrapped(draft.timerReferenceLabel + (seconds > 0 ? " · " + Math.round(seconds * 1000) / 1000 + " s" : ""));
					if (UiChrome.ghostButton("Apply current reference##ab_quick_timer_refresh")) applyTimingReference(draft.cooldownReference);
				}, "Countdown and Fuse stay off until you enable them. Manual duration overrides are available in Advanced.");
			} else if (draft.aura.timerMode != AuraTimer.MODE_OFF) {
				UiLayout.propertyRow("Fixed seconds", function() {
					if (ImGui.inputFloat("##ab_quick_timer_seconds", draft.aura.timerSeconds, 0, 0, "%.3f s")) {
						var v = draft.aura.timerSeconds.get();
						draft.aura.timerSeconds.set(Math.isFinite(v) ? Math.max(0.1, Math.min(600, v)) : 0);
					}
				});
			}
		});
		ImGui.textWrapped("Unlocked HUD faces remain visible for placement. Lock their position in Advanced to follow the show rules.");
		if (draft.behavior == AuraEffect.WHEN_ON_RISE)
			ImGui.textWrapped("One brief alert per false-to-true transition; it can fire again after the condition stops being true.");
	}

	function applyTimingReference(choice:String):Void {
		var c = draft.condition;
		if (!AuraTimingReferencePolicy.isCooldown(c.signal) && !AuraTimingReferencePolicy.isCast(c.signal)) return;
		var ref = AuraTimingReferences.forSubject(c.subject, c.signal, castRank, castRankChosen);
		castRank = ref.rank;
		if (AuraTimingReferencePolicy.isCast(c.signal)) draft.setTimerReference("CDB", ref.castSeconds, ref.castLabel);
		else if (choice == "Game time") draft.setTimerReference("Game time", 0, "Live cooldown");
		else {
			var seconds = AuraTimingReferencePolicy.seconds(choice, ref.cdbSeconds, ref.observedSeconds, ref.nativeValid);
			draft.setTimerReference(choice, seconds, seconds > 0 ? choice : "Unavailable");
		}
	}

	function drawHold(id:String):Void {
		if (ImGui.inputFloat("##ab_quick_hold_" + id, draft.aura.durRef, 0.5, 1, "%.1f seconds"))
			draft.setHold(draft.aura.durRef.get());
	}

	/** Right-hand column: a large live preview, its controls, the plain-words summary, then the actions. */
	function drawSide(cfg:AuraConfig, commit:AuraQuickBuildDraft->Bool->String):Bool {
		UiChrome.subHeader("Preview");
		var stageHeight:Single = Math.max(150, Math.min(260, ImGui.getContentRegionAvail().y * 0.34));
		drawPreviewStage(cfg, stageHeight);
		if (draft.face != "Banner") preview.drawControls();
		else ImGui.textDisabled("The banner appears over the screen when the alert fires.");
		ImGui.spacing();
		ImGui.pushTextWrapPos(0);
		ImGui.textDisabled(draft.summary());
		ImGui.popTextWrapPos();
		// Keep the actions pinned to the bottom of the column.
		var helpH = ImGui.calcTextSize(FOOTER_HELP, false, ImGui.getContentRegionAvail().x).y;
		var actionsH:Single = 36 + 36 + 6 + 30 + helpH + 24;
		var spare = ImGui.getContentRegionAvail().y - actionsH;
		if (spare > 0) ImGui.dummy(ImGui.vec2(0, spare));
		return drawActions(cfg, commit, true);
	}

	/** The aura as it will look, drawn from the live draft with the player's countdown settings. */
	function drawPreviewStage(cfg:AuraConfig, height:Single):Void {
		UiScope.child("##ab_quick_preview", ImGui.vec2(0, height), function() {
			if (draft.face == "Banner") {
				var text = StringTools.trim(draft.aura.bannerText);
				ImGui.dummy(ImGui.vec2(1, Math.max(0, ImGui.getContentRegionAvail().y * 0.5 - 14)));
				UiChrome.heading(text.length > 0 ? text : draft.aura.displayLabel(), 1.35);
				return;
			}
			var oldAll = AuraVisualRenderer.countdownAll;
			var oldMax = AuraVisualRenderer.countdownCeiling;
			var oldScale = AuraVisualRenderer.countdownGlobalScale;
			AuraVisualRenderer.countdownAll = cfg.countdownAll.get();
			AuraVisualRenderer.countdownCeiling = cfg.countdownAutoMax.get();
			AuraVisualRenderer.countdownGlobalScale = cfg.countdownScale.get();
			var failure:Dynamic = null;
			var area = ImGui.getContentRegionAvail();
			try { preview.draw(draft.aura, Math.max(60, area.x), Math.max(60, area.y), false, true); }
			catch (e:Dynamic) { failure = e; }
			AuraVisualRenderer.countdownAll = oldAll;
			AuraVisualRenderer.countdownCeiling = oldMax;
			AuraVisualRenderer.countdownGlobalScale = oldScale;
			if (failure != null) throw failure;
		}, ImGuiChildFlags.Borders);
	}

	/** Issue line and Create / Cancel / Advanced. Returns true when the modal should close. */
	function drawActions(cfg:AuraConfig, commit:AuraQuickBuildDraft->Bool->String, stacked:Bool):Bool {
		var atCap = cfg.auras.length >= AuraEngine.MAX;
		var issue = atCap ? "Aura limit reached. Delete an aura before creating another." : draft.issue(GameIcons.hasKey);
		UiScope.child("##ab_quick_issue", ImGui.vec2(0, 36), function() {
			if (commitIssue.length > 0 || issue.length > 0) {
				ImGui.textWrapped(commitIssue.length > 0 ? commitIssue : issue);
			}
		});
		var finished = false;
		if (stacked) {
			var clicked = false;
			disabled(issue.length > 0, function() clicked = UiChrome.accentButton("Create & Save##ab_quick_create", ImGui.vec2(-1, 36)));
			if (clicked) { commitIssue = commit(draft, false); finished = commitIssue.length == 0; }
			UiLayout.inlinePair("##ab_quick_actions", function(w:Single) {
				if (UiChrome.ghostButton("Cancel##ab_quick_cancel", ImGui.vec2(w, 30))) finished = true;
			}, function(w:Single) {
				var advanced = false;
				disabled(atCap, function() advanced = UiChrome.ghostButton("Open in Advanced##ab_quick_advanced", ImGui.vec2(w, 30)));
				if (advanced && !finished) { commitIssue = commit(draft, true); finished = commitIssue.length == 0; }
			});
		} else {
			UiLayout.inlinePair("##ab_quick_actions", function(w:Single) {
				var clicked = false;
				disabled(issue.length > 0, function() clicked = UiChrome.accentButton("Create & Save##ab_quick_create", ImGui.vec2(w, 36)));
				if (clicked) { commitIssue = commit(draft, false); finished = commitIssue.length == 0; }
			}, function(w:Single) {
				if (UiChrome.ghostButton("Cancel##ab_quick_cancel", ImGui.vec2(w, 36))) finished = true;
			});
			if (!finished) {
				var advanced = false;
				disabled(atCap, function() advanced = UiChrome.ghostButton("Open in Advanced##ab_quick_advanced", ImGui.vec2(-1, 26)));
				if (advanced) { commitIssue = commit(draft, true); finished = commitIssue.length == 0; }
			}
		}
		if (!finished) {
			ImGui.pushTextWrapPos(0);
			ImGui.textDisabled(FOOTER_HELP);
			ImGui.popTextWrapPos();
		}
		return finished;
	}
}
