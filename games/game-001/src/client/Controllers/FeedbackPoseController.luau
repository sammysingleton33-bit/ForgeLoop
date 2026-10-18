--!strict
--[[
	FeedbackPoseController (game-001, FORGE-04, FL-0100 (2/2); CONTRACTS G13.8): the citizen's reaction
	plays on the conversation portrait, with the same gestures the world rig uses (Feedback/ReactionPoses).
		poses:playPortrait(portrait, nameOrTone) -> boolean
		    Plays a reaction pose (cheer, grumble, slump, salute, bow, cower) or the pose for a reaction
		    tone (happy, angry, sad, neutral) on FORGE-02's portrait model, through Kit.posePortrait, for
		    the pose's DURATION; the portrait then rests. A new call on the same portrait replaces the old
		    one. With reduced motion (SettingsController) the key pose is held, without movement, until
		    stopPortrait or the next call. false when there is nothing to play or no Kit.posePortrait.
		poses:stopPortrait(portrait)      back to rest at once (a closed conversation)
		poses:step(dt)                    one frame; Heartbeat calls it live, specs call it directly
		poses.playing[portrait] = { name, t, held }
	Hooks (registry:find in start; each optional, connected only when present):
		ConversationController.opened(entityId) / .closed(entityId)  (G13.8, FORGE-03 FL-0099): which citizen
		    is talking; closing rests every portrait
		EntityController.event(id, kind, payload)  (G4.1): for the talking citizen, a `reaction`
		    ({ text, tone }, the server's G13.3 event) plays the tone's pose, and a consequence cue whose
		    config Vfx.cues pose is a reaction pose (bow, cower, …) plays that pose
		The portrait is FORGE-03's `conversation.stage.portrait.model` (a Kit.portrait, FL-0099).
	World rig: EntityController:playPose(entityId, name) (FORGE-01, proposed) samples ReactionPoses over
	its own pose; CitizenBubbleController already asks for it on every reaction and cue, by the same name.
	Kit.posePortrait comes from FORGE-02 (FL-0098); until it is on main, portrait poses are skipped with
	one warning. Specs set `poses.posePortrait`.
]]

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local ReactionPoses = require("@game/ReplicatedStorage/Game/Feedback/ReactionPoses")
local Vfx = require("@game/ReplicatedStorage/Forge/Config/Vfx")

local Controller = {}
Controller.__index = Controller

local Def = { name = "FeedbackPoseController", dependencies = {} }

local function connect(target: any, name: string, handler: (...any) -> ()): any
	local signal = target and target[name]
	if signal == nil then
		return nil
	end
	local ok, connection = pcall(function()
		if type(signal) == "table" and type(signal.connect) == "function" then
			return signal:connect(handler)
		end
		return signal:Connect(handler)
	end)
	return if ok then connection else nil
end

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		_connections = {} :: { any },
		_warned = false,
		posePortrait = (Kit :: any).posePortrait,
		playing = {} :: { [any]: { name: string, t: number, held: boolean } },
		talking = nil :: any, -- the entity id of the open conversation (ConversationController.opened)
		_joints = {} :: ReactionPoses.Joints, -- reused every frame: no allocation per pose
	}, Controller)
end

function Controller:start()
	local registry = self._registry
	self._settings = registry:find("SettingsController")
	local conversation = registry:find("ConversationController")
	self._conversation = conversation
	for _, connection in
		{
			connect(conversation, "opened", function(entityId)
				self.talking = entityId
			end),
			connect(conversation, "closed", function()
				self.talking = nil
				for model in table.clone(self.playing) do
					self:stopPortrait(model)
				end
			end),
			connect(registry:find("EntityController"), "event", function(id, kind, payload)
				self:_onEvent(id, kind, payload)
			end),
			connect(self._env.RunService, "Heartbeat", function(dt)
				self:step(dt)
			end),
		}
	do
		table.insert(self._connections, connection)
	end
end

-- FORGE-03's portrait for the open conversation (FL-0099: conversation.stage.portrait.model).
function Controller:_portrait(): any
	local conversation = self._conversation
	local ok, model = pcall(function()
		return conversation.stage.portrait.model
	end)
	return if ok then model else nil
end

local function names(id: any, payload: any, talking: any): boolean
	if id == talking then
		return true
	end
	local listed = type(payload) == "table" and payload.entityIds
	return type(listed) == "table" and table.find(listed, talking) ~= nil
end

-- The talking citizen's reaction (its tone) or a consequence cue with a reaction pose.
function Controller:_onEvent(id: any, kind: any, payload: any)
	local talking = self.talking
	if talking == nil or not names(id, payload, talking) then
		return
	end
	local pose
	if kind == "reaction" then
		pose = ReactionPoses.forTone(type(payload) == "table" and payload.tone or nil)
	else
		local cue = type(kind) == "string" and Vfx.cues and Vfx.cues[kind]
		pose = if cue and ReactionPoses.has(cue.pose) then cue.pose else nil
	end
	local portrait = if pose then self:_portrait() else nil
	if portrait ~= nil then
		self:playPortrait(portrait, pose)
	end
end

function Controller:destroy()
	for _, connection in self._connections do
		pcall(function()
			if connection.Disconnect then
				connection:Disconnect()
			else
				connection:disconnect()
			end
		end)
	end
	table.clear(self._connections)
	table.clear(self.playing)
end

function Controller:_reducedMotion(): boolean
	local settings = self._settings
	if settings == nil then
		return false
	end
	local ok, reduced = pcall(function()
		return if settings.reducedMotion then settings:reducedMotion() else settings:get("reducedMotion")
	end)
	return ok and reduced == true
end

-- Places the portrait's parts; false (and one warning) without FORGE-02's Kit.posePortrait.
function Controller:_apply(portrait: any, joints: ReactionPoses.Joints): boolean
	local pose = self.posePortrait
	if pose == nil then
		if not self._warned then
			self._warned = true
			self._env.log("warn", "FeedbackPoseController: Kit.posePortrait is not available; portrait poses skipped")
		end
		return false
	end
	local ok, err = pcall(pose, portrait, joints)
	if not ok then
		self._env.log("warn", "FeedbackPoseController: posePortrait failed", { error = tostring(err) })
	end
	return ok
end

function Controller:playPortrait(portrait: any, nameOrTone: any): boolean
	if portrait == nil then
		return false
	end
	local name = if ReactionPoses.has(nameOrTone) then nameOrTone else ReactionPoses.forTone(nameOrTone)
	local held = self:_reducedMotion()
	local joints = if held then ReactionPoses.still(name, self._joints) else ReactionPoses.sample(name, 0, self._joints)
	if joints == nil or not self:_apply(portrait, joints) then
		self.playing[portrait] = nil
		return false
	end
	self.playing[portrait] = { name = name, t = 0, held = held }
	return true
end

function Controller:stopPortrait(portrait: any)
	if self.playing[portrait] == nil then
		return
	end
	self.playing[portrait] = nil
	self:_apply(portrait, ReactionPoses.rest(self._joints))
end

function Controller:step(dt: number)
	if type(dt) ~= "number" or dt ~= dt or dt <= 0 or next(self.playing) == nil then
		return -- idle frames cost nothing (FORGE-05 #121 L5)
	end
	for portrait, entry in table.clone(self.playing) do
		if not entry.held then
			entry.t += dt
			if entry.t >= ReactionPoses.DURATION[entry.name] then
				self:stopPortrait(portrait)
			else
				self:_apply(portrait, ReactionPoses.sample(entry.name, entry.t, self._joints) :: ReactionPoses.Joints)
			end
		end
	end
end

return Def
