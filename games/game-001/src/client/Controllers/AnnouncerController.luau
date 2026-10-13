--!strict
--[[
	AnnouncerController (game-001, FORGE-04, FL-0062; CONTRACTS G11): presents AnnouncerService's
	moments (`Feedback.Moment`).
		- celebrations (Feedback/Lines CELEBRATIONS: kingdomFounded, keepUpgraded, objectiveCaptured,
		  victory, defeat) through NotificationController:celebrate, registered once at start;
		- every other moment as a toast through NotificationController:show (silent when the moment
		  has its own sound, so nothing plays twice), coalesced by the line's key ("×N");
		- the moment's own sound and effect at its position (AudioController, VFXController).
	The end-of-match summary owns the result line (FORGE-00 ruling on #49): when FORGE-03's
	SliceSummaryController is on this client, a matchEnded moment shows no plain toast ("A draw",
	"<kingdom> wins the match"). Celebrations (Victory!, Defeat) and the music stay; a client without
	the summary keeps the toast (Def.SUMMARY_OWNS).
	A celebration that NotificationController declines (the same moment twice inside its cooldown)
	is simply done: the plain-toast fallback is only for a NotificationController without the
	celebration API or a kind it rejected. Effects get the moment's kingdom colour (`tint`, config
	Kingdoms identities) for presets that allow it, and so do celebrations (payload.tint).
	All of them are found with registry:find, so any may be absent (the headless boot gate).

		AnnouncerController.moment: Signal (moment, presentation)   -- MusicController listens
		AnnouncerController:onMoment(moment)                        -- what the remote calls (specs too)
]]

local Kingdoms = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local Lines = require("@game/ReplicatedStorage/Game/Feedback/Lines")
local Moments = require("@game/ReplicatedStorage/Game/Feedback/Moments")
local RemoteLink = require("@game/ReplicatedStorage/Forge/Experience/RemoteLink")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local AnnouncerController = {}
AnnouncerController.__index = AnnouncerController

local Def = { name = "AnnouncerController", dependencies = {} }

-- moment kinds whose plain toast the end-of-match summary already says (SliceSummaryController)
Def.SUMMARY_OWNS = table.freeze({ matchEnded = true })

-- kingdom id -> banner colour, for presets with tint = true
Def.COLORS = (function()
	local out = {}
	for _, identity in Kingdoms.identities or {} do
		local c = identity.color
		if type(identity.id) == "string" and type(c) == "table" then
			out[identity.id] = Color3.fromRGB(c[1], c[2], c[3])
		end
	end
	return table.freeze(out)
end)()

function Def.create(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		_links = {},
		_celebrations = {} :: { [string]: boolean }, -- kinds NotificationController accepted
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
	self._summary = registry:find("SliceSummaryController")
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
		else
			self._celebrations[kind] = true
		end
	end
end

function AnnouncerController:onMoment(moment: any)
	if type(moment) ~= "table" or not table.find(Moments.KINDS, moment.kind) then
		return
	end
	local presentation = Moments.present(moment)
	local notifications = self._notifications
	local tint = if type(moment.kingdom) == "string" then Def.COLORS[moment.kingdom] else nil
	local celebrated = false
	if
		presentation.celebrate
		and notifications
		and notifications.celebrate
		and self._celebrations[presentation.celebrate]
	then
		local payload = moment
		if tint then
			payload = table.clone(moment)
			payload.tint = tint
		end
		-- false = the same moment inside its cooldown: already shown, so no fallback toast
		notifications:celebrate(presentation.celebrate, payload)
		celebrated = true
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
		if toast and presentation.celebrate == nil and self._summary ~= nil and Def.SUMMARY_OWNS[moment.kind] then
			toast = nil -- the summary on screen shows the same result line
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
			self._vfx:play(presentation.vfx, { position = position, tint = tint })
		end
	end
	self.moment:fire(moment, presentation)
end

return Def
