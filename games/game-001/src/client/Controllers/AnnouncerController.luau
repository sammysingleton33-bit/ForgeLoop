--!strict
--[[
	AnnouncerController (game-001, FORGE-04, FL-0062; CONTRACTS G11): presents AnnouncerService's
	moments (`Feedback.Moment`).
		- celebrations (Feedback/Lines CELEBRATIONS: kingdomFounded, keepUpgraded, objectiveCaptured,
		  victory, defeat) through NotificationController:celebrate, registered once at start;
		- every other moment as a toast through NotificationController:show (silent when the moment
		  has its own sound, so nothing plays twice), coalesced by the line's key ("×N");
		- the moment's own sound and effect at its position (AudioController, VFXController).
	All of them are found with registry:find, so any may be absent (the headless boot gate).

		AnnouncerController.moment: Signal (moment, presentation)   -- MusicController listens
		AnnouncerController:onMoment(moment)                        -- what the remote calls (specs too)
]]

local Lines = require("@game/ReplicatedStorage/Game/Feedback/Lines")
local Moments = require("@game/ReplicatedStorage/Game/Feedback/Moments")
local RemoteLink = require("@game/ReplicatedStorage/Forge/Experience/RemoteLink")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local AnnouncerController = {}
AnnouncerController.__index = AnnouncerController

local Def = { name = "AnnouncerController", dependencies = {} }

function Def.create(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		_links = {},
		_registered = false,
		moment = Signal.new(),
	}, AnnouncerController)
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry)
end

function AnnouncerController:start()
	local registry = self._registry
	self._notifications = registry:find("NotificationController")
	self._audio = registry:find("AudioController")
	self._vfx = registry:find("VFXController")
	self:_registerCelebrations()
	table.insert(
		self._links,
		RemoteLink.on(self._env, "Feedback.Moment", function(moment)
			self:onMoment(moment)
		end)
	)
end

function AnnouncerController:destroy()
	for _, link in self._links do
		link:disconnect()
	end
	table.clear(self._links)
	self.moment:disconnectAll()
end

function AnnouncerController:_registerCelebrations()
	local notifications = self._notifications
	if notifications == nil or notifications.registerCelebration == nil then
		return
	end
	local kinds = {}
	for kind in Lines.CELEBRATIONS do
		table.insert(kinds, kind)
	end
	table.sort(kinds)
	for _, kind in kinds do
		local problems = notifications:registerCelebration(kind, Lines.CELEBRATIONS[kind])
		if #problems > 0 then
			self._env.log(
				"warn",
				"announcer: celebration rejected",
				{ kind = kind, problems = table.concat(problems, "; ") }
			)
		end
	end
	self._registered = true
end

function AnnouncerController:onMoment(moment: any)
	if type(moment) ~= "table" or not table.find(Moments.KINDS, moment.kind) then
		return
	end
	local presentation = Moments.present(moment)
	local notifications = self._notifications
	local celebrated = false
	if presentation.celebrate and notifications and notifications.celebrate and self._registered then
		celebrated = notifications:celebrate(presentation.celebrate, moment) == true
	end
	if not celebrated then
		local toast = presentation.toast
		if toast == nil and presentation.celebrate then
			-- no celebrations (NotificationController without FL-0027's API): show the celebration's toast
			local spec = Lines.CELEBRATIONS[presentation.celebrate]
			if spec and spec.toast then
				toast = {
					kind = spec.toast.kind,
					title = (string.gsub(spec.toast.title, "{(%w+)}", function(field)
						local value = moment[field]
						return if type(value) == "string" or type(value) == "number" then tostring(value) else ""
					end)),
				}
			end
		end
		if toast and notifications and notifications.show then
			notifications:show({
				title = toast.title,
				body = toast.body,
				kind = toast.kind,
				key = toast.key,
				silent = presentation.sound ~= nil,
			})
		end
		local position = if typeof(moment.position) == "Vector3" then moment.position else nil
		if presentation.sound and self._audio then
			self._audio:play(presentation.sound, { position = position })
		end
		if presentation.vfx and self._vfx and position then
			self._vfx:play(presentation.vfx, { position = position })
		end
	end
	self.moment:fire(moment, presentation)
end

return Def
