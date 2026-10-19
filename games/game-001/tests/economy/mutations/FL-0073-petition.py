"""FL-0073 (e) citizen card: arena perk preview and petitions (PetitionModel, CitizenCard, CitizenCardController).
Each row breaks one rule and expects a named PetitionUI spec to fail.

Run from the repository root (needs lune on PATH):
    python3 games/game-001/tests/economy/mutations/FL-0073-petition.py
One line per row: CAUGHT / NOT CAUGHT / NOT APPLIED. Exits 1 unless every row is CAUGHT. A run in which no spec file
ran counts as NOT CAUGHT. Left out as equivalent (a later guard gives the same result): an unknown role defaulting
its config (SupportModel.offers has no offer for it either) and an unknown need made fulfillable (CitizenModel.price
already reports COST_UNKNOWN as a need). Rows: (name, file, old, new, expected failing test (substring of its name)).
"""
import pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
U = "games/game-001/src/client/UI/"
C = "games/game-001/src/client/Controllers/"
RUN = ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json",
       "--specs", "games/game-001/tests", "economy/PetitionUI"]
M, V, K = U + "PetitionModel.luau", U + "CitizenCard.luau", C + "CitizenCardController.luau"
ROWS = [
    ("pledged threshold off", M, "elseif loyalty >= pledgedAt then \"pledged\"", "elseif loyalty >= pledgedAt + 10 then \"pledged\"",
     "80..94 is pledged"),
    ("empowered never", M, "if loyalty >= empoweredAt then \"empowered\"", "if false then \"empowered\"", "80..94 is pledged"),
    ("effect at current loyalty", M, "offerAt(role, name, math.max(loyalty, pledgedAt))", "offerAt(role, name, empoweredAt)",
     "below 80"),
    ("no loyalty to go", M, "toGo = if power == \"none\" then pledgedAt - loyalty else nil", "toGo = nil", "below 80"),
    ("no empowered preview", M, "next = if power == \"pledged\" and empowered then", "next = if false and empowered then",
     "80..94 is pledged"),
    ("minutes floored", M, "local m = math.ceil(seconds / 60)", "local m = math.floor(seconds / 60)",
     "key citizen below 80 shows"),
    ("expired fulfillable", M, "canFulfil = not expired and not unknown", "canFulfil = not unknown", "a petition: cost"),
    ("short need fulfillable", M, "and priced.need == nil,", "and true,", "can't cover: Need"),
    ("blank petition shown", M, "or type(p.id) ~= \"string\" or p.id == \"\"", "or type(p.id) ~= \"string\"", "fails closed"),
    ("raw reason shown", M, "return REASONS[tostring(code)] or PetitionModel.GENERIC", "return REASONS[tostring(code)] or tostring(code)",
     "refusal reasons are sentences"),
    ("petition after the perk on phones", V, "petitionBox(pv.model, pv, if phone then 2 else 1)", "petitionBox(pv.model, pv, if phone then 9 else 1)",
     "phone 667"),
    ("fulfil state attribute", V, "\t\tif state == \"loading\" then \"loading\" elseif p.canFulfil then \"ready\"",
     "\t\tif false then \"loading\" elseif p.canFulfil then \"ready\"", "one call at a time"),
    ("no error line", V, "\tif ui.error then\n", "\tif false then\n", "a refusal shows its reason"),
    ("no perk box", V, "local perk = if ui.perk then perkBox(", "local perk = if false then perkBox(", "key citizen below 80 shows"),
    ("not dark", K, "visible = petition ~= nil and hud:hasRemote(CitizenCardController.FULFIL),", "visible = petition ~= nil,",
     "dark until Kingdom.FulfilPetition"),
    ("fulfil ignores the remote", K, "if p == nil or entityId == nil or not hud:hasRemote(CitizenCardController.FULFIL) then",
     "if p == nil or entityId == nil then", "dark until Kingdom.FulfilPetition"),
    ("double sends", K, "if self.petition.state == \"loading\" or not p.canFulfil then", "if not p.canFulfil then",
     "one call at a time"),
    ("blocked still sends", K, "if self.petition.state == \"loading\" or not p.canFulfil then", "if self.petition.state == \"loading\" then",
     "can't cover: Need"),
    ("stale reply lands", K, "\t\tif token ~= self._fulfilToken then\n\t\t\treturn -- another", "\t\tif false then\n\t\t\treturn -- another",
     "never lands on the next"),
    ("no refresh after fulfil", K, "\t\t\tself:_inspect(entityId, true) -- the petition is gone", "\t\t\tlocal _ = entityId -- the petition is gone",
     "Fulfil spends the need"),
    ("no success notice", K, "hud:notify({ kind = \"success\", title = PetitionModel.FULFILLED, body = p.text })", "local _ = p",
     "Fulfil spends the need"),
    ("drop shown as refusal", K, "if called and ok ~= nil then PetitionModel.reason(reason) else CitizenText.unreachable()",
     "PetitionModel.reason(reason)", "dropped call"),
    ("card rebuilt on treasury push", K, "\tif key == self._renderKey and self.card.panel ~= nil then",
     "\tif false then", "treasury pushes"),
]
bad = 0
for name, path, old, new, expect in ROWS:
    f = ROOT / path
    src = f.read_text()
    if old not in src:
        print(f"NOT APPLIED | {name}"); bad += 1; continue
    f.write_text(src.replace(old, new, 1))
    try:
        out = subprocess.run(RUN, cwd=ROOT, capture_output=True, text=True, timeout=900).stdout
    finally:
        f.write_text(src)
    ran = " 0 spec file(s)" not in out
    hit = ran and any(l.strip().startswith("x ") and expect in l for l in out.splitlines())
    bad += not hit
    print(f"{'CAUGHT' if hit else 'NOT CAUGHT'} | {name} | {expect}")
print(f"{len(ROWS) - bad}/{len(ROWS)} caught")
sys.exit(1 if bad else 0)
