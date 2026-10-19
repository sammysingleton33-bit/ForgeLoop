--!strict
--[[
	HowToPlayController (FORGE-03, game-001 client, FL-0138) — "How to play": the whole match in six short cards
	(UI/HowToPlayModel, UI/HowToPlay), so a new player can learn the rules at any time.

	Ways in:
		- the "How to play" button at the end of the Kingdom menu's Overview tab (KingdomHudController passes onHelp
		  while this controller is loaded)
		- a "Rules" rail button while the match is in its Lobby countdown (removed when Founding starts)
	It is a HUD menu ("howto"), drawn on the modal layer: opening another menu closes it, and the back key (#130)
	steps one card back, then closes. Closing returns to the Kingdom menu when it was opened from there.
	Keys while open (ContextActionService, above the camera's pan keys so the arrows don't move the view):
		Right / D-pad right / Enter → next (Done on the last card closes), Left / D-pad left → back.
	Touch and mouse: Back, Next and Close are 44 px buttons.

	Depends on KingdomHudController (menus, modal layer, rail, store).
	API (specs and scenes)
		help:open()   help:close()   help:next()   help:back()   help:key(keyCode) -> boolean (handled)
		help.index    help.cards     help.view (UI/HowToPlay)
		HowToPlayController.MENU = "howto"   HowToPlayController.RAIL (the Lobby rail button)
]]

local HowToPlay = require("../UI/HowToPlay")
local HowToPlayModel = require("../UI/HowToPlayModel")
local Signature = require("../UI/Signature")

local HowToPlayController = {}
HowToPlayController.__index = HowToPlayController

local Def = { name = "HowToPlayController", dependencies = { "KingdomHudController" } }

HowToPlayController.MENU = "howto"
HowToPlayController.ACTION = "ForgeHowToPlay"
HowToPlayController.RAIL = table.freeze({
	id = "howto",
	icon = "info",
	label = "Rules", -- the rail's label width (72 px) does not fit "How to play"; the panel's title says it
	target = "HUD.HowToPlayButton",
	order = 5, -- after the built-in menus, during the Lobby countdown
})
HowToPlayController.NEXT_KEYS = table.freeze({ Enum.KeyCode.Right, Enum.KeyCode.DPadRight, Enum.KeyCode.Return })
HowToPlayController.BACK_KEYS = table.freeze({ Enum.KeyCode.Left, Enum.KeyCode.DPadLeft })

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		hud = registry:get("KingdomHudController"),
		cards = HowToPlayModel.cards(),
		index = 1,
		view = nil :: any,
		_returnTo = nil :: string?,
		_key = nil :: string?,
		_railShown = false,
		_bound = false,
		_connections = {} :: { any },
	}, HowToPlayController)
end

function HowToPlayController:start()
	local hud = self.hud
	if hud.setBackStep ~= nil then
		hud:setBackStep(HowToPlayController.MENU, function()
			if self.index > 1 then
				self:back()
				return true
			end
			return false
		end)
	end
	self._connections = {
		hud.rendered:connect(function(metrics)
			self:_syncRail()
			self:render(metrics)
		end),
	}
	self:_syncRail()
end

function HowToPlayController:destroy()
	self._destroyed = true
	for _, connection in self._connections do
		pcall(function()
			connection:disconnect()
		end)
	end
	self._connections = {}
	self:_bind(false)
	if self._railShown then
		self.hud:removeRailItem(HowToPlayController.RAIL.id)
		self._railShown = false
	end
	if self.view then
		self.view:destroy()
	end
end

-- The rail button shows during the Lobby countdown only (the Kingdom menu has the way in after that).
function HowToPlayController:_syncRail()
	local match = self.hud.store.match
	local lobby = type(match) == "table" and match.phase == "Lobby"
	if lobby == self._railShown or self._destroyed then
		return
	end
	self._railShown = lobby
	if lobby then
		local item = table.clone(HowToPlayController.RAIL)
		item.onActivated = function()
			self:open()
		end
		self.hud:addRailItem(item)
	else
		self.hud:removeRailItem(HowToPlayController.RAIL.id)
	end
end

function HowToPlayController:isOpen(): boolean
	return self.hud.state.menu == HowToPlayController.MENU
end

function HowToPlayController:open()
	if self:isOpen() then
		return
	end
	local from = self.hud.state.menu
	self._returnTo = if from == "kingdom" then from else nil
	self.index = 1
	self.hud:setMenu(HowToPlayController.MENU)
end

function HowToPlayController:close()
	if not self:isOpen() then
		return
	end
	local back = self._returnTo
	self._returnTo = nil
	self.hud:setMenu(back) -- nil closes; "kingdom" returns to the panel it was opened from
end

function HowToPlayController:next()
	if self.index >= #self.cards then
		self:close()
		return
	end
	self.index += 1
	self:render()
end

function HowToPlayController:back()
	if self.index <= 1 then
		return
	end
	self.index -= 1
	self:render()
end

function HowToPlayController:key(keyCode: any): boolean
	if not self:isOpen() then
		return false
	end
	if table.find(HowToPlayController.NEXT_KEYS, keyCode) then
		self:next()
		return true
	elseif table.find(HowToPlayController.BACK_KEYS, keyCode) then
		self:back()
		return true
	end
	return false
end

-- Arrow keys, D-pad and Enter while the cards are open; sunk so the camera does not pan underneath.
function HowToPlayController:_bind(on: boolean)
	if on == self._bound then
		return
	end
	local actions = self._env.ContextActionService
	if actions == nil then
		self._bound = on
		return
	end
	self._bound = on
	pcall(function()
		if on then
			local keys = {}
			for _, k in HowToPlayController.NEXT_KEYS do
				table.insert(keys, k)
			end
			for _, k in HowToPlayController.BACK_KEYS do
				table.insert(keys, k)
			end
			actions:BindActionAtPriority(HowToPlayController.ACTION, function(_, state, input)
				if state ~= Enum.UserInputState.Begin then
					return Enum.ContextActionResult.Sink
				end
				return if self:key(input and input.KeyCode)
					then Enum.ContextActionResult.Sink
					else Enum.ContextActionResult.Pass
			end, false, Enum.ContextActionPriority.High.Value + 10, table.unpack(keys))
		else
			actions:UnbindAction(HowToPlayController.ACTION)
		end
	end)
end

function HowToPlayController:render(metrics: any?)
	local hud = self.hud
	if self._destroyed or hud.roots.modals == nil then
		return
	end
	self.view = self.view or HowToPlay.new(hud.roots.modals)
	local open = self:isOpen()
	self:_bind(open)
	if not open then
		self.view:destroy()
		self._key = nil
		return
	end
	local m = metrics or hud:metrics()
	local key = Signature.of({ index = self.index, breakpoint = m.breakpoint, width = m.width, height = m.height })
	if key == self._key and self.view.instance ~= nil then
		return
	end
	self._key = key
	self.view:render(HowToPlayModel.view(self.cards, self.index), m, {
		onBack = function()
			self:back()
		end,
		onNext = function()
			self:next()
		end,
		onClose = function()
			self:close()
		end,
	})
end

return Def
