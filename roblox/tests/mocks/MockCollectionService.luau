--[[
	MockCollectionService — tags over the MockEnv DataModel.

	Imitates: creator-docs content/en-us/reference/engine/classes/CollectionService.yaml
	  AddTag(instance, tag), RemoveTag(instance, tag), HasTag(instance, tag), GetTags(instance),
	  GetTagged(tag) -> instances in the DataModel with the tag, GetAllTags(),
	  GetInstanceAddedSignal(tag), GetInstanceRemovedSignal(tag)
	Tags are stored on the instances themselves (Lune instances support tags), so tags set in a map
	loaded into the DataModel are visible to GetTagged.
	Signals fire for AddTag/RemoveTag made through this service while the instance is inside the
	DataModel. Not modelled: signals for tagged instances being parented into or out of the
	DataModel (Lune has no ancestry events) — call AddTag after parenting in specs.

	MockCollectionService.new(dataModel, { spawn = fn? })
]]

local MockSignal = require("./MockSignal")

local MockCollectionService = {}
MockCollectionService.__index = MockCollectionService

function MockCollectionService.new(dataModel: any, options: { spawn: ((...any) -> ())? }?)
	return setmetatable({
		_dataModel = dataModel,
		_spawn = options and options.spawn,
		_added = {},
		_removed = {},
		_known = {},
	}, MockCollectionService)
end

local function signalFor(self, map, tag: string, kind: string)
	local signal = map[tag]
	if signal == nil then
		signal = MockSignal.new({ spawn = self._spawn, name = `{kind}({tag})` })
		map[tag] = signal
	end
	return signal
end

function MockCollectionService:_inDataModel(instance: any): boolean
	return instance:IsDescendantOf(self._dataModel)
end

function MockCollectionService:AddTag(instance: any, tag: string)
	assert(type(tag) == "string", "AddTag: tag must be a string")
	if instance:HasTag(tag) then
		return
	end
	instance:AddTag(tag)
	self._known[tag] = true
	if self:_inDataModel(instance) then
		signalFor(self, self._added, tag, "InstanceAdded"):Fire(instance)
	end
end

function MockCollectionService:RemoveTag(instance: any, tag: string)
	if not instance:HasTag(tag) then
		return
	end
	instance:RemoveTag(tag)
	if self:_inDataModel(instance) then
		signalFor(self, self._removed, tag, "InstanceRemoved"):Fire(instance)
	end
end

function MockCollectionService:HasTag(instance: any, tag: string): boolean
	return instance:HasTag(tag)
end

function MockCollectionService:GetTags(instance: any): { string }
	return instance:GetTags()
end

function MockCollectionService:GetTagged(tag: string): { any }
	local out = {}
	for _, descendant in self._dataModel:GetDescendants() do
		if descendant:HasTag(tag) then
			table.insert(out, descendant)
		end
	end
	return out
end

function MockCollectionService:GetAllTags(): { string }
	local set = table.clone(self._known)
	for _, descendant in self._dataModel:GetDescendants() do
		for _, tag in descendant:GetTags() do
			set[tag] = true
		end
	end
	local out = {}
	for tag in set do
		table.insert(out, tag)
	end
	table.sort(out)
	return out
end

function MockCollectionService:GetInstanceAddedSignal(tag: string)
	return signalFor(self, self._added, tag, "InstanceAdded")
end

function MockCollectionService:GetInstanceRemovedSignal(tag: string)
	return signalFor(self, self._removed, tag, "InstanceRemoved")
end

return MockCollectionService
