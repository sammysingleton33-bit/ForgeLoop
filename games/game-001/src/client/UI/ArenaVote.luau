--!strict
--[[
	UI/ArenaVote — the co-rulers' champion vote on the modal layer (FL-0142); the model is UI/ArenaVoteModel.
		Header   "Choose your champion" and the countdown chip ("8 s")
		Body     the hint or the vote's status; one 44 px button per candidate ("You" for the local ruler), gold
		         (primary) on the one this ruler voted for; "1 of 2 voted" under them
	Desktop/tablet: 520 × 204, centred. Phones (667 × 375): min(520, width - 16) × min(178, height - 16), centred
	4 px low so it clears the Roblox top bar. Two to four candidates share the row; buttons never go under 44 px tall.
	Names for specs and Studio: "ArenaVote" (attributes side, kingdom), "VoteClock", "VoteStatus" (attribute kind),
	"Candidate_<userId>" (attribute fullName; face attributes picked, voted), "VotedCount".

	ArenaVote.new(parent) -> view
	view:render(view, metrics, ui: { onVote(userId) })   view:tick(view) (the countdown, in place)   view:destroy()
	view.instance: Frame "ArenaVote"   ArenaVote.shorten(name, buttonWidth)   ArenaVote.textWidth(text)
]]

local Button = require("@game/ReplicatedStorage/Forge/UI/Components/Button")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Panel = require("@game/ReplicatedStorage/Forge/UI/Components/Panel")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local ArenaVote = {}
ArenaVote.__index = ArenaVote

ArenaVote.SIZE = table.freeze({ width = 520, height = 204 })
ArenaVote.PHONE = table.freeze({ width = 520, height = 178 })
ArenaVote.GAP = 8

local STATUS_COLOR =
	{ hint = "textSecondary", pending = "textSecondary", ok = "gold300", failed = "gules", left = "gules" }

-- A candidate's label is held to its button (Style.text truncates with "…", exact on Roblox). Before that, a name is
-- cut here to what an estimate of the bold 15 px label says fits, so it ends with "…" inside the button rather than
-- being clipped: wide letters (W, M, capitals) count wide, i / l / punctuation narrow. 16 px is the button's padding.
-- The full name is on the button's "fullName" attribute and in the status line once voted for.
ArenaVote.PAD = 16
local NARROW =
	{ i = 4, l = 4, j = 5, I = 5, t = 6, f = 6, r = 7, ["."] = 4, [","] = 4, ["'"] = 4, [" "] = 5, ["_"] = 9 }
local WIDE = { W = 19, M = 18, m = 16, w = 15 }
function ArenaVote.charWidth(ch: string): number
	if NARROW[ch] then
		return NARROW[ch]
	elseif WIDE[ch] then
		return WIDE[ch]
	elseif string.match(ch, "^%u$") then
		return 12
	end
	return 10
end
function ArenaVote.textWidth(text: string): number
	local w = 0
	for _, code in utf8.codes(text) do
		w += ArenaVote.charWidth(utf8.char(code))
	end
	return w
end
function ArenaVote.shorten(name: string, buttonWidth: number): string
	local budget = buttonWidth - ArenaVote.PAD
	if utf8.len(name) == nil or ArenaVote.textWidth(name) <= budget then
		return name
	end
	local ellipsis = ArenaVote.textWidth("…") + 2
	local out, w = {}, 0
	for _, code in utf8.codes(name) do
		local ch = utf8.char(code)
		local cw = ArenaVote.charWidth(ch)
		if w + cw + ellipsis > budget then
			break
		end
		table.insert(out, ch)
		w += cw
	end
	return table.concat(out) .. "…"
end

function ArenaVote.new(parent: Instance)
	return setmetatable({ _parent = parent, instance = nil :: Frame?, buttons = {} :: { [number]: any } }, ArenaVote)
end

function ArenaVote:render(v: any, m: any, ui: { [string]: any })
	self:destroy()
	local phone = m.breakpoint == "phone"
	local box = if phone then ArenaVote.PHONE else ArenaVote.SIZE
	local width = math.min(box.width, m.width - 16)
	local height = math.min(box.height, m.height - 16)
	local clock = Create("Frame", {
		Name = "VoteClock",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(64, 28),
		BackgroundColor3 = Theme.color("ink950"),
		BackgroundTransparency = 0.2,
		Visible = v.clock ~= nil,
	}, {
		Corner = Style.corner(14),
		Stroke = Style.stroke(Theme.color("gold600"), 1),
		Label = Style.text({
			text = v.clock or "",
			weight = Enum.FontWeight.Bold,
			size = 15,
			color = Theme.color("gold300"),
			xAlign = "Center",
			extra = { Size = UDim2.fromScale(1, 1) },
		}),
	})
	self._clock = clock
	local header = Create("Frame", { Name = "HeaderRow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		Title = Style.text({
			text = "Choose your champion",
			role = "heading",
			weight = Enum.FontWeight.Bold,
			size = if phone then 16 else 20,
			color = Theme.color("gold300"),
			extra = { Size = UDim2.new(1, -72, 1, 0) },
		}),
		VoteClock = clock,
	})
	local panel = Panel.new({
		header = header,
		size = UDim2.fromOffset(width, height),
		position = if phone then UDim2.new(0.5, 0, 0.5, 4) else UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		padding = if phone then 10 else 16,
		compact = phone,
		zIndex = 3,
	})
	local content = panel.content
	local statusHeight = if phone then 32 else 40
	local status = Style.text({
		text = v.status,
		weight = Enum.FontWeight.SemiBold,
		size = if phone then 12 else 15,
		color = Theme.color(STATUS_COLOR[v.statusKind] or "textSecondary"),
		wrap = true,
		yAlign = "Top",
		extra = { Name = "VoteStatus", Size = UDim2.new(1, 0, 0, statusHeight), LineHeight = 1.1 },
	})
	status:SetAttribute("kind", v.statusKind)
	status.Parent = content
	-- the candidates: one row of equal buttons
	local row = Create("Frame", {
		Name = "Candidates",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, statusHeight + 6),
		Size = UDim2.new(1, 0, 0, 44),
	}, { List = Style.list("x", ArenaVote.GAP, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local count = math.max(1, #v.candidates)
	local inner = width - 2 * (if phone then 10 else 16)
	local each = math.floor((inner - ArenaVote.GAP * (count - 1)) / count)
	each = math.min(each, if phone then 200 else 180)
	self.buttons = {}
	for index, c in v.candidates do
		local button = Button.new({
			text = ArenaVote.shorten(c.name, each),
			variant = if c.picked then "primary" else "secondary",
			size = "regular",
			width = each,
			layoutOrder = index,
			onActivated = function()
				if ui.onVote then
					ui.onVote(c.userId)
				end
			end,
		})
		button.instance.Name = `Candidate_{c.userId}`
		button.instance:SetAttribute("fullName", c.name)
		-- the kit's label grows with its text; here it is held to the button (Style.text ends it with "…")
		local label = button.face:FindFirstChild("Label", true)
		if label and label:IsA("TextLabel") then
			label.AutomaticSize = Enum.AutomaticSize.None
			label.Size = UDim2.new(0, each - ArenaVote.PAD, 1, 0)
		end
		button.face:SetAttribute("picked", c.picked)
		button.face:SetAttribute("voted", c.hasVoted)
		button.instance.Parent = row
		self.buttons[c.userId] = button
	end
	row.Parent = content
	Style.text({
		text = v.votedText,
		weight = Enum.FontWeight.SemiBold,
		size = if phone then 12 else 14,
		color = Theme.color("textMuted"),
		xAlign = "Center",
		extra = {
			Name = "VotedCount",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, 0, 0, 18),
		},
	}).Parent =
		content
	-- no scrim: the arena and the stands stay in view behind the vote
	self.instance = Create("Frame", {
		Name = "ArenaVote",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	}, { Panel = panel.instance }) :: Frame
	self.instance:SetAttribute("side", v.side)
	self.instance:SetAttribute("kingdom", v.kingdomId)
	self.instance.Parent = self._parent
end

-- The countdown moves in place: no rebuild, so a press on a candidate is never cut short (FORGE-07 M1).
function ArenaVote:tick(v: any)
	local clock = self._clock
	if clock == nil or clock.Parent == nil then
		return
	end
	clock.Visible = v.clock ~= nil
	local label = clock:FindFirstChildWhichIsA("TextLabel")
	if label then
		label.Text = v.clock or ""
	end
end

function ArenaVote:destroy()
	if self.instance then
		self.instance:Destroy()
		self.instance = nil
	end
	self._clock = nil
	self.buttons = {}
end

return ArenaVote
