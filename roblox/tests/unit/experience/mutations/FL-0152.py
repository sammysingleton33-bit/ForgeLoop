"""FL-0152 mutation rows (job icons over citizens, D-059 B22.4), run by ../mutations.py (`mutations.py FL-0152`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0152 here only (D-038 (7)).
"""
GC = C2 + "FeedbackJobGlyphController.luau"
GS = "experience/CitizenGlyphs"
OFF = "is off by default"
ON = "on: each citizen's own job glyph"
CAP = "draws at most MAX_SHOWN"
CLU = "a cluster shows one icon a job"
FADE = "fades with the zoom"
HIDE = "hides in walk mode"
POOL = "a released rig gives its glyph back"
STOP = "starts and stops cleanly"
M = [
 # off by default, behind the setting
 ("FL-0152", GC, 'if settings == nil or settings:get(Def.SETTING) ~= true then', 'if settings == nil then', GS, OFF, "game"),
 ("FL-0152", X + "Schema.luau", 'jobGlyphs = table.freeze({ kind = "boolean", default = false })', 'jobGlyphs = table.freeze({ kind = "boolean", default = true })', GS, OFF, "game"),
 # who: citizens with a known job, drawn rigs only; FORGE-03's badge per job and size
 ("FL-0152", GC, 'if not ok or kind ~= "citizen" or type(job) ~= "string" then', 'if not ok or type(job) ~= "string" then', GS, ON, "game"),
 ("FL-0152", GC, 'if look ~= nil and model.Parent ~= nil and not self:_hasBubble(id) then', 'if look ~= nil and not self:_hasBubble(id) then', GS, ON, "game"),
 ("FL-0152", GC, 'local px = if self:_isPhone() then Def.PHONE_PX else Def.GLYPH_PX', 'local px = Def.GLYPH_PX', GS, ON, "game"),
 ("FL-0152", GC, 'gui.AlwaysOnTop = false', 'gui.AlwaysOnTop = true', GS, ON, "game"),
 ("FL-0152", GC, 'farmer = table.freeze({ icon = "farm", color = Theme.resource("food") })', 'farmer = table.freeze({ icon = "farm", color = Theme.resource("wood") })', GS, ON, "game"),
 ("FL-0152", GC, 'badge:GetAttribute("icon") == look.icon and badge:GetAttribute("px") == px then', 'badge:GetAttribute("icon") == look.icon then', GS, ON, "game"),
 ("FL-0152", GC, '\t\tbadge:Destroy()\n', '', GS, ON, "game"),
 ("FL-0152", GC, 'if badge ~= nil and badge:GetAttribute("icon") == look.icon and', 'if badge ~= nil and', GS, POOL, "game"),
 # how many: the nearest MAX_SHOWN on screen
 ("FL-0152", GC, 'if #kept >= Def.MAX_SHOWN then', 'if false then', GS, CAP, "game"),
 ("FL-0152", GC, 'if pivot and point and visible then', 'if pivot and point then', GS, CAP, "game"),
 ("FL-0152", GC, 'return a.distance < b.distance', 'return a.distance > b.distance', GS, CAP, "game"),
 # one icon a same-job cluster, chained, led by its nearest member; no two icons overlap
 ("FL-0152", GC, 'if other.look == c.look and (other.point - c.point).Magnitude < reach then', 'if other.look == c.look and false then', GS, CLU, "game"),
 ("FL-0152", GC, 'if other.look == c.look and (other.point - c.point).Magnitude < reach then', 'if (other.point - c.point).Magnitude < reach then', GS, CLU, "game"),
 ("FL-0152", GC, 'parent[math.max(a, b)] = math.min(a, b)', 'parent[math.min(a, b)] = math.max(a, b)', GS, CLU, "game"),
 ("FL-0152", GC, 'for x = cx - 1, cx + 1 do', 'for x = cx, cx do', GS, CLU, "game"),
 ("FL-0152", GC, 'Def.MERGE = 1.2 --', 'Def.MERGE = 1 --', GS, CLU, "game"),
 ("FL-0152", GC, 'Def.APART = 1 --', 'Def.APART = 0.5 --', GS, CLU, "game"),
 ("FL-0152", GC, 'if (c.point - k.point).Magnitude < Def.APART * px then', 'if false then', GS, CLU, "game"),
 ("FL-0152", GC, 'if (c.point - k.point).Magnitude < Def.APART * px then', 'if (c.point - k.point).Magnitude < Def.APART * Def.GLYPH_PX then', GS, CLU, "game"),
 # fade: full at the start view (70), gone at the overview's closest (40)
 ("FL-0152", GC, 'return math.clamp((zoom - Def.FADE_NONE) / (Def.FADE_FULL - Def.FADE_NONE), 0, 1)', 'return 1', GS, FADE, "game"),
 ("FL-0152", GC, 'Def.FADE_FULL = 55 --', 'Def.FADE_FULL = 80 --', GS, FADE, "game"),
 ("FL-0152", GC, 'Def.FADE_NONE = 40 --', 'Def.FADE_NONE = 30 --', GS, FADE, "game"),
 ("FL-0152", GC, '\tbadge.BackgroundTransparency = clear', '\tbadge.BackgroundTransparency = 0', GS, FADE, "game"),
 ("FL-0152", GC, '\t\tstroke.Transparency = clear', '\t\tstroke.Transparency = 0', GS, FADE, "game"),
 ("FL-0152", GC, '\t\tinner.TextTransparency = clear', '\t\tinner.TextTransparency = 0', GS, FADE, "game"),
 # hidden in walk mode, a scripted shot, the duel, a conversation and under a bubble
 ("FL-0152", GC, 'if look ~= nil and model.Parent ~= nil and not self:_hasBubble(id) then', 'if look ~= nil and model.Parent ~= nil then', GS, HIDE, "game"),
 ("FL-0152", GC, 'if camera.mode ~= nil and camera.mode ~= "overview" then', 'if false then', GS, HIDE, "game"),
 ("FL-0152", GC, 'if ok and playing then', 'if false then', GS, HIDE, "game"),
 ("FL-0152", GC, 'if input ~= nil and input.mode == "arena" then', 'if false then', GS, HIDE, "game"),
 ("FL-0152", GC, 'if ok and open then', 'if false then', GS, HIDE, "game"),
 # pooled; release and destroy take GUIs down
 ("FL-0152", GC, 'gui = table.remove(self._pool) or self:_build()', 'gui = self:_build()', GS, POOL, "game"),
 ("FL-0152", GC, '\tself:_hide(id)\n\tself._models[id] = nil', '\tself._models[id] = nil', GS, POOL, "game"),
 ("FL-0152", GC, 'for _, gui in self._drawn do\n\t\tgui:Destroy()\n\tend', 'for _ in self._drawn do\n\tend', GS, STOP, "game"),
]
