--!strict
--[[
	ArenaIntroController (FORGE-03, game-001 client, FL-0073) — the two-sided versus card while the arena stage is
	"intro" (design crown-arena.md §7): both champions, their support tier and score, the top three reasons, the
	loadout and the chosen perks. UI/ArenaIntroCard over UI/ArenaIntroModel, on the modal layer, for everyone (the
	champions and the watching rulers). FORGE-04's intro camera passes over the stands behind it.

	Depends on KingdomHudController (modal layer, layout) and ArenaHudController (state, lookup).
	API (specs and scenes)   intro.view   intro:model()   ArenaIntroController.POLL_SEC
]]

local ArenaIntroCard = require("../UI/ArenaIntroCard")
local ArenaIntroModel = require("../UI/ArenaIntroModel")
local Signature = require("../UI/Signature")

local ArenaIntroController = {}
ArenaIntroController.__index = ArenaIntroController

local Def = { name = "ArenaIntroController", dependencies = { "KingdomHudController", "ArenaHudController" } }

ArenaIntroController.POLL_SEC = 0.5 -- the countdown

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		hud = registry:get("KingdomHudController"),
		arena = registry:get("ArenaHudController"),
		view = nil :: any,
		_key = nil :: string?,
		_connections = {} :: { any },
	}, ArenaIntroController)
end

function ArenaIntroController:start()
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
	self._running = true
	env.spawn(function()
		while self._running do
			env.wait(ArenaIntroController.POLL_SEC)
			local st = self.arena.state
			if self._running and st ~= nil and st.stage == "intro" then
				self:render()
			end
		end
	end)
end

function ArenaIntroController:destroy()
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

function ArenaIntroController:model(): any
	return ArenaIntroModel.view(self.arena.state, self.arena:lookup(), self.arena:userId(), self._env.serverTimeNow())
end

function ArenaIntroController:render(metrics: any?)
	local hud = self.hud
	if self._destroyed or hud.roots.modals == nil then
		return
	end
	self.view = self.view or ArenaIntroCard.new(hud.roots.modals)
	local model = self:model()
	if model == nil then
		self.view:destroy()
		self._key = nil
		return
	end
	local m = metrics or hud:metrics()
	local key = Signature.of({ model = model, breakpoint = m.breakpoint, width = m.width, height = m.height })
	if key == self._key and self.view.instance ~= nil then
		return
	end
	self._key = key
	self.view:render(model, m)
end

return Def
