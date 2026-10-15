--!strict
--[[
	FeedbackHighlightController (game-001, FORGE-04, FL-0115; CONTRACTS G13.6, G4.1): the citizen under
	the mouse and the selected citizen, outlined in the world, so from the aerial camera the ruler sees
	what a click will pick and what is picked (the user's first Studio playtest: citizens were hard to
	notice and interact with).

	Hooks, found with registry:find in start():
		InputModeController.hovered(kind, id)   -> a light outline on that citizen (mouse only)
		InputModeController.selected(kind, id)  -> a gold outline while that citizen stays selected
		EntityController:getModel(id), .rendered / .released -> the rig to outline; a released rig
		    loses its outline, and the citizen's next rig (a job change) gets it back
		ConversationController.opened / .closed -> no outlines while the conversation stage shows
	One Highlight each (Roblox draws at most 31 at once), reparented to the rig it outlines, on top of
	roofs (DepthMode AlwaysOnTop). The selected outline wins when both are on one citizen. Citizens
	only: buildings and plots keep FORGE-03's selection look.

		FeedbackHighlightController.hoverId / .selectedId   -- entity ids or nil
		FeedbackHighlightController:refresh()               -- re-attach both outlines
]]

local Def = {
	name = "FeedbackHighlightController",
	dependencies = {},
}

local rgb = Color3.fromRGB
Def.STYLE = table.freeze({
	hover = table.freeze({ outline = rgb(255, 248, 225), outlineTransparency = 0.1, fillTransparency = 0.85 }),
	selected = table.freeze({ outline = rgb(242, 190, 60), outlineTransparency = 0, fillTransparency = 0.7 }),
})

local Controller = {}
Controller.__index = Controller

local function connect(target: any, signalName: string, handler: (...any) -> ()): any
	local signal = target and target[signalName]
	if signal == nil then
		return nil
	end
	local ok, connection = pcall(function()
		return signal:connect(handler)
	end)
	return if ok then connection else nil
end

local function citizenId(kind: any, id: any): number?
	return if kind == "citizen" and type(id) == "number" and id == id then id else nil
end

function Def.create(env: any, registry: any): any
	return setmetatable({
		_env = env,
		_registry = registry,
		_connections = {},
		_gone = {} :: { [number]: boolean },
		_talking = false,
		_lights = {} :: { [string]: any },
		hoverId = nil :: number?,
		selectedId = nil :: number?,
	}, Controller)
end

function Def.new(env: any, registry: any): any
	return Def.create(env, registry)
end

function Controller:start()
	local registry = self._registry
	local input = registry:find("InputModeController")
	self._entities = registry:find("EntityController")
	if input == nil or self._entities == nil then
		self._env.log("info", "FeedbackHighlightController: no InputModeController or EntityController; no outlines")
		return
	end
	local conversation = registry:find("ConversationController")
	for _, item in
		{
			connect(input, "hovered", function(kind, id)
				self.hoverId = citizenId(kind, id)
				self:refresh()
			end),
			connect(input, "selected", function(kind, id)
				self.selectedId = citizenId(kind, id)
				self:refresh()
			end),
			connect(self._entities, "released", function(id)
				self._gone[id] = true -- getModel still returns the pooled rig until it is rendered again
				self:refresh()
			end),
			connect(self._entities, "rendered", function(id)
				self._gone[id] = nil
				self:refresh()
			end),
			connect(conversation, "opened", function()
				self._talking = true
				self:refresh()
			end),
			connect(conversation, "closed", function()
				self._talking = false
				self:refresh()
			end),
		}
	do
		table.insert(self._connections, item)
	end
end

function Controller:destroy()
	for _, connection in self._connections do
		pcall(function()
			connection:disconnect()
		end)
	end
	table.clear(self._connections)
	for _, light in self._lights do
		light:Destroy()
	end
	table.clear(self._lights)
end

function Controller:refresh()
	local hover = if self.hoverId ~= self.selectedId then self.hoverId else nil
	self:_attach("selected", self.selectedId)
	self:_attach("hover", hover)
end

function Controller:_modelOf(id: number?): any
	if id == nil or self._talking or self._gone[id] then
		return nil
	end
	local entities = self._entities
	local ok, model = pcall(entities.getModel, entities, id)
	if not ok or model == nil or model.Parent == nil then
		return nil -- no rig, or hidden by LOD
	end
	return model
end

function Controller:_attach(kind: string, id: number?)
	local model = self:_modelOf(id)
	local light = self._lights[kind]
	if model == nil then
		if light ~= nil then
			light.Parent = nil
		end
		return
	end
	if light == nil then
		local style = Def.STYLE[kind]
		light = self._env.newInstance("Highlight")
		light.Name = if kind == "hover" then "ForgeHoverOutline" else "ForgeSelectedOutline"
		light.OutlineColor = style.outline
		light.OutlineTransparency = style.outlineTransparency
		light.FillColor = style.outline
		light.FillTransparency = style.fillTransparency
		light.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		self._lights[kind] = light
	end
	light.Adornee = model
	light.Parent = model
end

return table.freeze(Def)
