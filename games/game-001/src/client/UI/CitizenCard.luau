--!strict
--[[
	UI/CitizenCard — the citizen card v2 in the menu drawer (prototype scenes "card", "card-quiet",
	"card-asking"): who they are, how they see you (loyalty, mood, obedience), what they are doing,
	their traits, family, friends and rivals, what they remember, and Talk (they have something to
	say) or Ask. Tablet/desktop: two columns in a fitted panel; phone: one scrolling column. Talk stays
	pinned at the bottom.

	CitizenCard.new(parent: GuiObject) -> card
	card:render(model: CitizenModel Card, metrics: Layout Metrics, ui: {
		color: Color3?,                  the avatar's kingdom colour
		talk: { visible: boolean, state: "idle" | "loading" },
		onTalk: () -> (), onClose: () -> () })
	card:destroy()
	Names for specs and Studio: panel "CitizenCard"; "Avatar" (+ "Request" badge); "CitizenName",
	"CitizenSub"; "Stat_<loyalty|mood|obedience>" with "Value" and a ProgressBar; "Intent"; "Traits"
	with "Trait_<n>"; "Relation_<family|friends|rivals>" with "Names"; "Memories" with "LastMemory",
	"Memory_<n>"; button "Talk" (face attribute `talk` = "request" | "ask" | "loading").
]]

local Button = require("@game/ReplicatedStorage/Forge/UI/Components/Button")
local CitizenModel = require("./CitizenModel")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local IconButton = require("@game/ReplicatedStorage/Forge/UI/Components/IconButton")
local Panel = require("@game/ReplicatedStorage/Forge/UI/Components/Panel")
local ProgressBar = require("@game/ReplicatedStorage/Forge/UI/Components/ProgressBar")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local CitizenCard = {}
CitizenCard.__index = CitizenCard

local RIVAL = Color3.fromRGB(255, 138, 115)
local FILLS = {
	love = Color3.fromRGB(232, 112, 92),
	gold = Color3.fromRGB(234, 196, 108),
	cool = Color3.fromRGB(110, 158, 216),
}

function CitizenCard.new(parent: Instance)
	return setmetatable({ _parent = parent, panel = nil, talk = nil }, CitizenCard)
end

-- The round avatar with the citizen's initial (no portraits yet), in the kingdom's colour; an amber
-- "!" when they have something to say (same cue as FORGE-04's thought bubble).
function CitizenCard.avatar(initial: string, size: number, color: Color3, request: boolean): Frame
	local lighter = color:Lerp(Color3.new(1, 1, 1), 0.15)
	local darker = color:Lerp(Color3.new(0, 0, 0), 0.3)
	local avatar = Create("Frame", {
		Name = "Avatar",
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(size, size),
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(Theme.color("gold500"), 2),
		Gradient = Style.gradient(lighter, darker),
		Initial = Style.text({
			text = initial,
			role = "heading",
			weight = Enum.FontWeight.Heavy,
			size = math.floor(size * 0.45),
			color = Theme.color("parchment100"),
			xAlign = "Center",
			extra = { Size = UDim2.fromScale(1, 1) },
		}),
	})
	if request then
		Create("Frame", {
			Name = "Request",
			BackgroundColor3 = Theme.color("amber"),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -3, 0, 3),
			Size = UDim2.fromOffset(16, 16),
			ZIndex = 3,
			Parent = avatar,
		}, {
			Corner = Style.corner(999),
			Stroke = Style.stroke(Theme.color("ink950"), 1.5),
			Mark = Style.text({
				text = "!",
				weight = Enum.FontWeight.ExtraBold,
				size = 11,
				color = Theme.color("ink950"),
				xAlign = "Center",
				extra = { Size = UDim2.fromScale(1, 1), ZIndex = 3 },
			}),
		})
	end
	return avatar
end

-- Header row: avatar, name and occupation, close button (also used by UI/ConversationPanel).
function CitizenCard.header(spec: {
	initial: string,
	name: string,
	sub: string?,
	color: Color3,
	request: boolean?,
	avatar: number,
	onClose: () -> (),
}): (Frame, any)
	local size = spec.avatar
	local close = IconButton.new({ icon = "close", variant = "plain", size = 36, onActivated = spec.onClose })
	close.instance.AnchorPoint = Vector2.new(1, 0.5)
	close.instance.Position = UDim2.fromScale(1, 0.5)
	close.instance.Name = "Close"
	local row = Create("Frame", {
		Name = "HeaderRow",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Avatar = CitizenCard.avatar(spec.initial, size, spec.color, spec.request == true),
		Who = Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(size + 10, 0),
			Size = UDim2.new(1, -(size + 10 + 44), 1, 0),
		}, {
			List = Style.list("y", 1, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
			CitizenName = Style.text({
				text = spec.name,
				role = "heading",
				weight = Enum.FontWeight.Bold,
				size = 16,
				color = Theme.color("parchment100"),
				extra = { Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1 },
			}),
			CitizenSub = if spec.sub
				then Style.text({
					text = spec.sub,
					weight = Enum.FontWeight.Bold,
					size = 11,
					color = Theme.color("gold400"),
					extra = { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2 },
				})
				else nil,
		}),
		Close = close.instance,
	})
	return row, close
end

local function box(name: string, order: number): Frame
	return Create("Frame", {
		Name = name,
		BackgroundColor3 = Theme.color("scrim"),
		BackgroundTransparency = 0.5,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(Theme.color("ink500"), 1),
		Padding = Style.padding(8, 10),
		List = Style.list("y", 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
	})
end

local function boxTitle(icon: string, title: string): Frame
	local i = Icon.new(icon, 16)
	i.AnchorPoint = Vector2.new(0, 0.5)
	i.Position = UDim2.fromScale(0, 0.5)
	return Create("Frame", {
		Name = "Head",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 0,
	}, {
		Icon = i,
		Title = Style.text({
			text = title,
			role = "heading",
			weight = Enum.FontWeight.Bold,
			size = 12,
			color = Theme.color("gold300"),
			extra = { Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 1, 0) },
		}),
	})
end

local function statRow(stat: any): Frame
	local bar = ProgressBar.new({ progress = stat.value / 100, color = FILLS[stat.fill], width = UDim.new(1, -176) })
	bar.instance.AnchorPoint = Vector2.new(0, 0.5)
	bar.instance.Position = UDim2.new(0, 84, 0.5, 0)
	local main = stat.id == "loyalty"
	return Create("Frame", {
		Name = "Stat_" .. stat.id,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
	}, {
		Label = Style.text({
			text = stat.label,
			size = 12,
			color = Theme.color("textSecondary"),
			extra = { Size = UDim2.new(0, 80, 1, 0) },
		}),
		Bar = bar.instance,
		Band = if stat.band
			then Style.text({
				text = stat.band,
				size = 11,
				color = Theme.color("textSecondary"),
				xAlign = "Right",
				extra = {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -28, 0, 0),
					Size = UDim2.new(0, 60, 1, 0),
				},
			})
			else nil,
		Value = Style.text({
			text = stat.text,
			weight = Enum.FontWeight.ExtraBold,
			size = if main then 14 else 12,
			color = if main then Theme.color("gold300") else Theme.color("textPrimary"),
			xAlign = "Right",
			extra = { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 26, 1, 0) },
		}),
	})
end

local function opinion(model: any, phone: boolean, order: number): Frame?
	if #model.stats == 0 then
		return nil
	end
	local frame = box("Opinion", order)
	if not phone then
		boxTitle("heart", `How {model.firstName} sees you`).Parent = frame
	end
	for i, stat in model.stats do
		local row = statRow(stat)
		row.LayoutOrder = i
		row.Parent = frame
	end
	return frame
end

local function intent(model: any, order: number): Frame?
	if model.intent == nil then
		return nil
	end
	local icon = Icon.new(model.intentIcon, 18)
	icon.Position = UDim2.fromOffset(0, 0)
	return Create("Frame", {
		Name = "Intent",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, {
		Icon = icon,
		Now = Style.text({
			text = "Now",
			weight = Enum.FontWeight.ExtraBold,
			size = 12,
			color = Theme.color("gold400"),
			extra = { Position = UDim2.fromOffset(24, 0), Size = UDim2.fromOffset(32, 18) },
		}),
		IntentText = Style.text({
			text = model.intent,
			size = 12,
			wrap = true,
			yAlign = "Top",
			extra = {
				Position = UDim2.fromOffset(58, 2),
				Size = UDim2.new(1, -58, 0, 16),
				AutomaticSize = Enum.AutomaticSize.Y,
				LineHeight = CitizenModel.LINE_HEIGHT,
			},
		}),
	})
end

local function traits(model: any, order: number): Frame?
	if #model.traits == 0 then
		return nil
	end
	local list = Style.list("x", 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	list.Wraps = true
	local frame = Create("Frame", {
		Name = "Traits",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, { List = list })
	for i, trait in model.traits do
		Create("Frame", {
			Name = "Trait_" .. i,
			BackgroundColor3 = Theme.color("ink950"),
			BackgroundTransparency = 0.3,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			LayoutOrder = i,
			Parent = frame,
		}, {
			Corner = Style.corner(999),
			Stroke = Style.stroke(Theme.color("gold700"), 1),
			Padding = Style.padding(0, 8),
			Label = Style.text({
				text = trait,
				weight = Enum.FontWeight.Bold,
				size = 11,
				color = Theme.color("parchment200"),
				extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1) },
			}),
		})
	end
	return frame
end

local function people(model: any, order: number): Frame?
	if #model.relations == 0 then
		return nil
	end
	local frame = box("People", order)
	boxTitle("citizens", "People").Parent = frame
	for i, r in model.relations do
		Create("Frame", {
			Name = "Relation_" .. r.id,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i,
			Parent = frame,
		}, {
			Key = Style.text({
				text = r.label,
				size = 12,
				color = if r.rival then RIVAL else Theme.color("textSecondary"),
				yAlign = "Top",
				extra = { Size = UDim2.fromOffset(56, 16) },
			}),
			Names = Style.text({
				text = table.concat(r.names, ", "),
				size = 12,
				wrap = true,
				yAlign = "Top",
				extra = {
					Position = UDim2.fromOffset(60, 0),
					Size = UDim2.new(1, -60, 0, 16),
					AutomaticSize = Enum.AutomaticSize.Y,
					LineHeight = CitizenModel.LINE_HEIGHT,
				},
			}),
		})
	end
	return frame
end

local function memoryLine(name: string, s: string, last: boolean, order: number): Frame
	return Create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, {
		Diamond = Create("Frame", {
			BackgroundColor3 = if last then Theme.color("gold400") else Theme.color("gold600"),
			Position = UDim2.fromOffset(1, 6),
			Size = UDim2.fromOffset(5, 5),
			Rotation = 45,
		}),
		MemoryText = Style.text({
			text = s,
			weight = if last then Enum.FontWeight.Bold else Enum.FontWeight.SemiBold,
			size = 12,
			color = if last then Theme.color("textPrimary") else Theme.color("textSecondary"),
			wrap = true,
			yAlign = "Top",
			extra = {
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -12, 0, 16),
				AutomaticSize = Enum.AutomaticSize.Y,
				LineHeight = CitizenModel.LINE_HEIGHT,
			},
		}),
	})
end

local function memories(model: any, limit: number, order: number): Frame?
	if model.lastMemory == nil and #model.memories == 0 then
		return nil
	end
	local frame = box("Memories", order)
	boxTitle("scroll", "Remembers").Parent = frame
	if model.lastMemory then
		memoryLine("LastMemory", model.lastMemory, true, 1).Parent = frame
	end
	for i, m in model.memories do
		if i > limit then
			break
		end
		memoryLine("Memory_" .. i, m, false, i + 1).Parent = frame
	end
	return frame
end

local function column(name: string, parent: Instance, size: UDim2, position: UDim2): ScrollingFrame
	return Create("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.color("gold600"),
		Parent = parent,
	}, {
		List = Style.list("y", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
		Padding = Style.padding(1, 6, 1, 1),
	})
end

local function put(frame: Instance?, parent: Instance)
	if frame then
		frame.Parent = parent
	end
end

function CitizenCard:render(model: any, metrics: any, ui: { [string]: any })
	self:destroy()
	local phone = metrics.breakpoint == "phone"
	local rect = CitizenModel.cardRect(metrics)
	local header = CitizenCard.header({
		initial = model.initial,
		name = model.name,
		sub = model.sub,
		color = ui.color or Theme.color("gules"),
		request = model.request,
		avatar = if phone then 32 else 36,
		onClose = ui.onClose,
	})
	self.panel = Panel.new({
		header = header,
		size = UDim2.fromOffset(rect.width, rect.height),
		position = UDim2.fromOffset(rect.x, rect.y),
		padding = if phone then 10 else 12,
	})
	self.panel.instance.Name = "CitizenCard"
	self.panel.instance:SetAttribute("entityId", model.entityId)
	local content = self.panel.content
	local talk = ui.talk or { visible = false }
	local footer = if talk.visible then 52 else 0
	if phone then
		local body = column("Body", content, UDim2.new(1, 0, 1, -footer), UDim2.new())
		put(opinion(model, true, 1), body)
		put(intent(model, 2), body)
		put(traits(model, 3), body)
		put(people(model, 4), body)
		put(memories(model, 2, 5), body)
	else
		local left = column("Left", content, UDim2.new(0.5, -5, 1, -footer), UDim2.new())
		local right = column("Right", content, UDim2.new(0.5, -5, 1, -footer), UDim2.new(0.5, 5, 0, 0))
		put(opinion(model, false, 1), left)
		put(intent(model, 2), left)
		put(traits(model, 3), left)
		put(people(model, 1), right)
		put(memories(model, 4, 2), right)
	end
	self.talk = nil
	if talk.visible then
		local loading = talk.state == "loading"
		self.talk = Button.new({
			text = model.talk.text,
			icon = "talk",
			variant = model.talk.variant,
			state = if loading then "loading" else "default",
			onActivated = ui.onTalk,
		})
		self.talk.instance.Name = "Talk"
		self.talk.instance.AnchorPoint = Vector2.new(0, 1)
		self.talk.instance.Position = UDim2.fromScale(0, 1)
		self.talk.face:SetAttribute("talk", if loading then "loading" elseif model.request then "request" else "ask")
		self.talk.instance.Parent = content
	end
	self.panel.instance.Parent = self._parent
end

function CitizenCard:destroy()
	if self.panel then
		self.panel:destroy()
		self.panel = nil
	end
	self.talk = nil
end

return CitizenCard
