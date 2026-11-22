#!/usr/bin/env python3
"""Deterministic SolarFlare runtime architecture guardrails."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "solarflare"

EXPECTED_RELEASE_HOOKS = {
    ("postfix", "st.skill.BaseSkill.doStart"),
    ("postfix", "st.skill.BaseSkill.doStop"),
    ("postfix", "ent.Hero.onSkillUse"),
    ("postfix", "ent.Unit.rpcDisplayDamage__impl"),
    ("postfix", "ui.Hud.updateVisibility"),
    ("postfix", "GameApp.update"),
    ("postfix", "ent.Hero.set_attackComboCount"),
    ("postfix", "client.UnitController.startSkillAim"),
}
# Chat payload telemetry was retired in v3.3b; both builds now use the same hooks.
TELEMETRY_ONLY_HOOKS: set[tuple[str, str]] = set()
CONTINUOUS_STATE_HOOKS = {
    "st.Player.update",
    "ent.Unit.set_health",
    "ent.HeroAttributes.set_rage",
    "ent.HeroAttributes.set_spark",
    "ent.HeroAttributes.set_comboPoint",
    "st.skill.Skill.onTriggerCD",
    "st.skill.Skill.reduceCooldown",
    "st.skill.Skill.resetCooldown",
    "st.skill.Status.init",
    "st.skill.Status.set_stacks",
    "st.skill.Status.onStacksChange",
    "st.skill.Status.set_refreshDuration",
    "st.skill.Status.extendDuration",
    "st.skill.Status.onRemove",
    "ent.GameObject.__net_mark_statuses",
}


def require(ok: bool, message: str) -> None:
    if not ok:
        raise AssertionError(message)


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def without_telemetry_blocks(body: str) -> str:
    """Return the release view of a Haxe source file."""
    out: list[str] = []
    telemetry_depth = 0
    for line in body.splitlines():
        directive = line.strip()
        if telemetry_depth:
            if directive.startswith("#if "):
                telemetry_depth += 1
            elif directive == "#end":
                telemetry_depth -= 1
            continue
        if directive == "#if solarflare_telemetry":
            telemetry_depth = 1
            continue
        out.append(line)
    require(telemetry_depth == 0, "unterminated solarflare_telemetry block")
    return "\n".join(out)


def hooks(body: str) -> list[tuple[str, str]]:
    return re.findall(r"@:hlx\.(prefix|postfix)\(([^)]+)\)", body)


def main() -> int:
    sources = {p: text(p) for p in SRC.rglob("*.hx")}
    joined = "\n".join(sources.values())
    release_joined = "\n".join(without_telemetry_blocks(body) for body in sources.values())
    release_hooks = hooks(release_joined)
    telemetry_hooks = hooks(joined)
    require(len(release_hooks) == len(set(release_hooks)),
            f"duplicate release hook target(s): {release_hooks}")
    require(set(release_hooks) == EXPECTED_RELEASE_HOOKS,
            "release hook allowlist mismatch: "
            f"expected={sorted(EXPECTED_RELEASE_HOOKS)} actual={sorted(set(release_hooks))}")
    require(set(telemetry_hooks) == EXPECTED_RELEASE_HOOKS | TELEMETRY_ONLY_HOOKS,
            "telemetry hook allowlist mismatch: "
            f"actual={sorted(set(telemetry_hooks))}")
    require(not (CONTINUOUS_STATE_HOOKS & {target for _, target in release_hooks}),
            "continuous state hook returned to release")
    mod_entry = text(SRC / "ModEntry.hx")
    # GeauxHooks (ui.BaseUI.startDrag) retired 2026-10-11: its drag capture had no consumer.
    for retired in ("PriestHooks.keep", "RogueHooks.keep", "MageHooks.keep",
                    "StatusObserveHooks.keep", "GeauxHooks.keep"):
        require(retired not in mod_entry, f"retired hook root remains: {retired}")
    require("solarflare.localtime" not in joined and "LocalTimeConfig" not in joined,
            "retired Local Time remains reachable")
    require("-debug" not in text(ROOT / "compile.hxml"), "release build enables -debug")
    telemetry = text(ROOT / "compile.telemetry.hxml")
    require("-debug" in telemetry and "-D solarflare_telemetry" in telemetry,
            "telemetry build flags missing")
    require("VERSION:Int = 36" in text(SRC / "ui" / "SettingsStore.hx"),
            "settings schema is not 36")
    require("VERSION:Int = 19" in text(SRC / "ui" / "ProfileMigration.hx"),
            "profile schema is not 19")
    require("new BoolRef(false)" in text(SRC / "combatlog" / "CombatLogRecorder.hx"),
            "combat recorder is not opt-in")
    for path, body in sources.items():
        if path.name.endswith("Hooks.hx") or path.name == "HealthHooks.hx":
            require("File.append" not in body and "saveContent" not in body,
                    f"hook file performs disk I/O: {path.relative_to(ROOT)}")
    require((SRC / "runtime" / "TelemetryKernel.hx").exists(), "TelemetryKernel missing")
    require((SRC / "runtime" / "EventRing.hx").exists(), "EventRing missing")
    for path, body in sources.items():
        if path.parent.name == "debug":
            continue
        release = re.sub(r"//[^\n]*|/\*[\s\S]*?\*/", "", without_telemetry_blocks(body))
        for probe in ("ResolutionLedger", "PayloadProbe", "FieldWalkLog", "LedgerBinding"):
            require(probe not in release,
                    f"investigation dependency in release: {path.relative_to(ROOT)} ({probe})")
    print(f"runtime architecture PASS ({len(release_hooks)} release hooks, "
          f"{len(telemetry_hooks) - len(release_hooks)} telemetry-only)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
