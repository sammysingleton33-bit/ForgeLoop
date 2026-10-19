--!strict
--[[
	LoadoutController (FORGE-03, game-001 client, FL-0073) — the loadout and perk picker before the duel (design
	crown-arena.md §3-§5; CONTRACTS G12.4 Arena.Choose). UI/LoadoutPicker over UI/LoadoutModel, on the modal layer,
	while the arena stage is "loadout" and the local player is a champion (ArenaHudController's feed).

	The choice starts on the duellist's weapon and armour (or the defaults) and the first offers up to the slots, so
	a champion who never touches it still duels with perks. Ready sends Arena.Choose(weapon, armour, triggers);
	after a Ready, every change is sent again at once ("You can still change it until the time runs out"). With
	AUTO_SEC left and nothing accepted yet, the current choice is sent by itself. A refusal is said in words
	(ArenaText.REASONS) and the picker stays open.
	Mouse and touch tap the tiles; a gamepad gets the first weapon tile selected when the picker opens (Roblox GUI
	selection moves between the tiles and cards; A picks).

	Depends on KingdomHudController (remotes, modal layer, layout) and ArenaHudController (state, support).
	API (specs and scenes)
		loadout.choice   loadout.sent ({ pending?, ok?, reason? }?)   loadout.view   loadout:model()
		loadout:weapon(id)   loadout:armour(id)   loadout:toggle(trigger)   loadout:ready()
		LoadoutController.AUTO_SEC   .POLL_SEC   .CHOOSE
]]

local LoadoutModel = require("../UI/LoadoutModel")
local LoadoutPicker = require("../UI/LoadoutPicker")
local Signature = require("../UI/Signature")

local LoadoutController = {}
LoadoutController.__index = LoadoutController

local Def = { name = "LoadoutController", dependencies = { "KingdomHudController", "ArenaHudController" } }

LoadoutController.CHOOSE = "Arena.Choose"
LoadoutController.AUTO_SEC = 1.5
LoadoutController.POLL_SEC = 0.5

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		hud = registry:get("KingdomHudController"),
		arena = registry:get("ArenaHudController"),
		choice = nil :: any,
		sent = nil :: any,
		view = nil :: any,
		_round = nil :: string?,
		_key = nil :: string?,
		_open = false,
		_connections = {} :: { any },
	}, LoadoutController)
end

function LoadoutController:start()
	local env = self._env
	table.insert(
		self._connections,
		self.hud.rendered:connect(function(metrics)
			self:render(metrics)
		end)
	)
	table.insert(
		self._connections,
		self.arena.changed:connect(function()
			self:render()
		end)
	)
	table.insert(
		self._connections,
		self.arena.supportChanged:connect(function()
			self:_reseed()
			self:render()
		end)
	)
	self._running = true
	env.spawn(function()
		while self._running do
			env.wait(LoadoutController.POLL_SEC)
			if self._running and self._open then
				self:_auto()
				self:render()
			end
		end
	end)
end

function LoadoutController:destroy()
	self._destroyed = true
	self._running = false
	for _, connection in self._connections do
		pcall(function()
			connection:disconnect()
		end)
	end
	self._connections = {}
	if self.view then
		self.view:destroy()
	end
end

-- A new loadout stage (another pair, another deadline) starts a fresh choice.
function LoadoutController:_roundKey(): string?
	local st = self.arena.state
	if type(st) ~= "table" or st.stage ~= "loadout" then
		return nil
	end
	local a = if type(st.a) == "table" then st.a.userId else nil
	local b = if type(st.b) == "table" then st.b.userId else nil
	return `{a}|{b}|{st.endsAt}`
end

function LoadoutController:_duellist(): any
	local st = self.arena.state
	local side = LoadoutModel.side(st, self.arena:userId())
	return if side then st[side] else nil
end

function LoadoutController:_ensure()
	local key = self:_roundKey()
	if key ~= self._round then
		self._round = key
		self.sent = nil
		self.choice = if key then LoadoutModel.choice(self:_duellist(), self.arena.support) else nil
		self._seeded = self.arena.support ~= nil
	end
end

-- The support arrived after the stage began (Kingdom.GetSupport answers later): seed the perks once, unless the
-- player already chose.
function LoadoutController:_reseed()
	self:_ensure()
	if self.choice and not self._seeded and self.arena.support ~= nil and self.sent == nil then
		local fresh = LoadoutModel.choice(self:_duellist(), self.arena.support)
		self.choice.triggers = fresh.triggers
		self._seeded = true
	end
end

function LoadoutController:model(): any
	self:_ensure()
	if self.choice == nil then
		return nil
	end
	return LoadoutModel.view(
		self.arena.state,
		self.arena.support,
		self.arena:userId(),
		self.choice,
		self._env.serverTimeNow(),
		self.sent
	)
end

function LoadoutController:_changed()
	if self.sent and self.sent.ok then
		self:ready() -- already Ready: the new choice goes out at once
	else
		self:render()
	end
end

function LoadoutController:weapon(id: string)
	self:_ensure()
	if self.choice == nil or self.choice.weapon == id then
		return
	end
	self.choice = { weapon = id, armour = self.choice.armour, triggers = self.choice.triggers }
	self:_changed()
end

function LoadoutController:armour(id: string)
	self:_ensure()
	if self.choice == nil or self.choice.armour == id then
		return
	end
	self.choice = { weapon = self.choice.weapon, armour = id, triggers = self.choice.triggers }
	self:_changed()
end

function LoadoutController:toggle(trigger: string)
	self:_ensure()
	if self.choice == nil then
		return
	end
	local nextChoice = LoadoutModel.toggle(self.choice, trigger, self.arena.support)
	if nextChoice == self.choice then
		return -- full, or not offered: the card already says why
	end
	self.choice = nextChoice
	self:_changed()
end

function LoadoutController:ready()
	self:_ensure()
	if self.choice == nil or (self.sent and self.sent.pending) then
		return
	end
	if not self.hud:hasRemote(LoadoutController.CHOOSE) then
		return
	end
	local round = self._round
	local weapon, armour, triggers = LoadoutModel.args(self.choice)
	self.sent = { pending = true }
	self:render()
	self._env.spawn(function()
		local called, ok, reason = pcall(function()
			return self.hud.remotes:invoke(LoadoutController.CHOOSE, weapon, armour, triggers)
		end)
		if self._destroyed or self._round ~= round then
			return
		end
		local auto = self.sent ~= nil and self.sent.auto == true -- an automatic send is tried once
		self.sent = { ok = called and ok == true, reason = if called then reason else "invalid_args", auto = auto }
		self:render()
	end)
end

-- Time nearly out and nothing accepted yet: send what is on screen.
function LoadoutController:_auto()
	local st = self.arena.state
	if self.choice == nil or type(st) ~= "table" or type(st.endsAt) ~= "number" then
		return
	end
	if self.sent ~= nil and (self.sent.ok or self.sent.pending or self.sent.auto) then
		return
	end
	if st.endsAt - self._env.serverTimeNow() <= LoadoutController.AUTO_SEC then
		self:ready()
		if self.sent then
			self.sent.auto = true
		end
	end
end

-- Gamepad selection: the first weapon tile when the picker opens; after a re-render (every change rebuilds the
-- picker), the tile or card of the same name, so A on a tile never drops the selection.
function LoadoutController:_selected(): string?
	local ok, name = pcall(function()
		local selected = self._env.GuiService.SelectedObject
		if selected and self.view.instance and selected:IsDescendantOf(self.view.instance) then
			return selected.Name
		end
		return nil
	end)
	return if ok then name else nil
end

function LoadoutController:_focusGamepad(name: string?)
	local env = self._env
	pcall(function()
		if not env.UserInputService.GamepadEnabled or self.view == nil or self.view.instance == nil then
			return
		end
		local target = if name then self.view.instance:FindFirstChild(name, true) else nil
		env.GuiService.SelectedObject = target or self.view:first()
	end)
end

function LoadoutController:render(metrics: any?)
	local hud = self.hud
	if self._destroyed or hud.roots.modals == nil then
		return
	end
	self.view = self.view or LoadoutPicker.new(hud.roots.modals)
	local model = self:model()
	if model == nil then
		self.view:destroy()
		self._open = false
		self._key = nil
		return
	end
	local m = metrics or hud:metrics()
	-- the countdown ticks in place (a rebuild every second would reset the perk list's scroll)
	local still = table.clone(model)
	still.clock, still.secondsLeft, still.urgent = nil, nil, nil
	local key = Signature.of({ model = still, breakpoint = m.breakpoint, width = m.width, height = m.height })
	if key == self._key and self.view.instance ~= nil then
		self.view:setClock(model.clock, model.urgent)
		return
	end
	self._key = key
	local opening = not self._open
	local selected = if opening then nil else self:_selected()
	self._open = true
	self.view:render(model, m, {
		onWeapon = function(id)
			self:weapon(id)
		end,
		onArmour = function(id)
			self:armour(id)
		end,
		onTrigger = function(trigger)
			self:toggle(trigger)
		end,
		onReady = function()
			self:ready()
		end,
	})
	if opening or selected then
		self:_focusGamepad(selected)
	end
end

return Def
