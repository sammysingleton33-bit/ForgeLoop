"""Mutation check for FORGE-04 specs: proves each named spec can fail.

Each row breaks one rule in the source, runs the matching Lune specs, expects the named test to
fail, and restores the file (also on error). Run from anywhere:
    python3 roblox/tests/unit/experience/mutations.py            # all rows
    python3 roblox/tests/unit/experience/mutations.py FL-0025    # one task
Prints one line per row: CAUGHT / NOT CAUGHT / MUTATION NOT APPLIED. Needs lune on PATH.
"""
import subprocess, sys, re, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[4]  # repository root
S = "roblox/src/server/Services/"; C = "roblox/src/client/Controllers/"; X = "roblox/src/shared/Experience/"
M = [
 ("FL-0023", S+"AnalyticsService.luau", 'local floor = if kind == "event" then self._capacity * self._limits.customReserve else 0', 'local floor = 0', "AnalyticsService", "keeps a reserve for funnels"),
 ("FL-0023", S+"AnalyticsService.luau", 'if decl.kind == "recurring" and (type(sessionId) ~= "string" or sessionId == "") then', 'if false then', "AnalyticsService", "drops recurring funnel steps without a sessionId"),
 ("FL-0023", S+"AnalyticsService.luau", 'local ok, err = pcall(service[method], service, ...)', 'local ok, err = true, service[method](service, ...)', "AnalyticsService", "never throws when Roblox errors"),
 ("FL-0023", S+"AnalyticsService.luau", 'out[AnalyticsSchema.FIELD_KEYS[index]] = text', 'out[AnalyticsSchema.FIELD_KEYS[4 - index]] = text', "AnalyticsService", "maps the value field and CustomField01-03"),
 ("FL-0023", S+"AnalyticsService.luau", 'if state.tokens < 1 then', 'if false then', "AnalyticsService", "caps one player at perPlayerPerMinute"),
 ("FL-0023", X+"AnalyticsSchema.luau", 'if #fields > AnalyticsSchema.CAPS.customFields then', 'if false then', "AnalyticsSchema", "rejects more than 3 custom fields"),
 ("FL-0024", X+"Schema.luau", 'local step = migrations[fromVersion]', 'local step = migrations[fromVersion + 1] or migrations[fromVersion]', "Settings", "migrates step by step"),
 ("FL-0024", S+"SettingsService.luau", 'if section == "settings" or not table.find(Schema.SECTIONS, section) or not isPlayer(player) then', 'if not table.find(Schema.SECTIONS, section) or not isPlayer(player) then', "Settings", "update(section) changes only that section"),
 ("FL-0024", S+"SettingsService.luau", 'if last and now - last < ANALYTICS_GAP then', 'if false then', "Settings", "reports SettingChanged at most once per key"),
 ("FL-0024", X+"SoundRegistry.luau", 'if not nonEmpty(entry.licence) then', 'if false then', "Audio", "rejects entries without licence"),
 ("FL-0024", C+"AudioController.luau", 'Def.BUDGET = table.freeze({ voices = 8, music = 1, ambience = 2 })', 'Def.BUDGET = table.freeze({ voices = 9, music = 1, ambience = 2 })', "Audio", "keeps at most 8 voices"),
 ("FL-0024", C+"AudioController.luau", 'if self:_countOf(soundId) >= (entry.maxInstances or 2) then', 'if false then', "Audio", "enforces cooldown and maxInstances"),
 ("FL-0024", X+"VfxPresets.luau", 'if live > B.particlesPerPreset then', 'if false then', "Vfx", "rejects presets over budget"),
 ("FL-0024", C+"VFXController.luau", 'local scale = if reduced and preset.reducedMotion == "reduce" then 0.5 else 1', 'local scale = 1', "Vfx", "reduced motion halves"),
 ("FL-0024", C+"VFXController.luau", 'if victim == nil then\n\t\t\treturn false', 'if victim == nil then\n\t\t\treturn true', "Vfx", "keeps live particles on screen within budget"),
 ("FL-0024", X+"CueDirector.luau", 'if variant.sound and not (variant.vfx or variant.notify or variant.float or variant.react) then', 'if false then', "Feedback", "the validator catches a sound-only cue"),
 ("FL-0024", X+"CueDirector.luau", 'local first = repeatCount == 1', 'local first = true', "Feedback", "coalesces repeats"),
 ("FL-0024", X+"CitizenReactions.luau", 'if last == nil or now - last >= CitizenReactions.CITIZEN_COOLDOWN then', 'if true then', "Feedback", "gives each citizen a cooldown"),
 ("FL-0024", X+"MusicDirector.luau", 'if not leavingUrgent and now - self._since < self._minDwell then', 'if false then', "Feedback", "only after the minimum dwell time"),
 ("FL-0024", X+"Pacing.luau", 'local target = math.max(signalPhase(self, eventName, data), self:_byClock(now))', 'local target = signalPhase(self, eventName, data)', "Feedback", "any signal after a fallback minute"),
 ("FL-0025", X+"Onboarding.luau", 'if step.trigger.client == trigger.client then', 'if true then', "Onboarding", "client actions only complete the current step"),
 ("FL-0025", X+"Onboarding.luau", 'if step.reward and not trigger.bus then', 'if false then', "Onboarding", "rejects rewards on client-triggered steps"),
 ("FL-0025", X+"Onboarding.luau", 'elseif limits.firstInteractionSec and firstInteraction > limits.firstInteractionSec then', 'elseif false then', "Onboarding", "first interaction comes too late"),
 ("FL-0025", X+"Onboarding.luau", 'if future.trigger.bus and not state.satisfied[future.id] and busMatches(future, trigger) then', 'if false then', "Onboarding", "a later bus step done early"),
 ("FL-0025", S+"OnboardingService.luau", 'if flow == nil or not Onboarding.skip(flow, state, self._env.now()) then', 'if flow == nil then', "Onboarding", "skipping logs OnboardingSkipped"),
 ("FL-0025", S+"OnboardingService.luau", 'section.flows[flow.id] = Onboarding.persisted(state)', 'section.flows[flow.id] = nil', "Onboarding", "persists progress and resumes"),
 ("FL-0025", C+"OnboardingController.luau", 'RemoteLink.send(self._env, "Experience.OnboardingSkip", state.flowId)', 'local _ = state.flowId', "OnboardingController", "Skip tells the server"),
 ("FL-0025", C+"OnboardingController.luau", 'if (position - origin).Magnitude >= Def.MOVE_STUDS then', 'if true then', "OnboardingController", "reports RulerMoved after the character walks"),
]
only = sys.argv[1] if len(sys.argv) > 1 else None
rows = []
for task, path, old, new, filt, expect in M:
    if only and task != only: continue
    f = ROOT / path
    src = f.read_text()
    if old not in src:
        rows.append((task, path, filt, expect, "MUTATION NOT APPLIED (text not found)")); continue
    f.write_text(src.replace(old, new, 1))
    try:
        out = subprocess.run(["lune", "run", "roblox/tests/harness/run.luau", filt], cwd=ROOT, capture_output=True, text=True, timeout=300).stdout
    finally:
        f.write_text(src)
    failed = [l.strip() for l in out.splitlines() if l.strip().startswith("x ")]
    hit = any(expect in l for l in failed)
    summary = [l for l in out.splitlines() if l.startswith("Lune tests:")]
    rows.append((task, path.split("/")[-1], filt, expect, ("CAUGHT" if hit else "NOT CAUGHT") + " | " + (summary[0] if summary else "?")))
for r in rows:
    print(" | ".join(r))
