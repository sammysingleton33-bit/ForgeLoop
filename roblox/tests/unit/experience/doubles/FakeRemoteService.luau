--[[
	FakeRemoteService — a local double of FORGE-01's RemoteService server API (interfaces §6) for
	FORGE-04 specs, used until FL-0009 lands.

		local remotes = FakeRemoteService.new({ declarations = ExperienceRemotes })
		remotes:handle(name, fn(player, ...))    -- service side (what RemoteService:handle does)
		remotes:fire(name, player, ...)          -- recorded in remotes.sent
		remotes:fireAll(name, ...)               -- recorded with player = "all"
		remotes:call(name, player, ...) -> (accepted, result)
			simulates a client call: unknown name, wrong kind, extra arguments or a failed validator
			drop the call (accepted = false, counted in remotes.rejected) before the handler runs
		remotes:sentTo(name, player?) -> { { player, args } }
]]

local FakeRemoteService = {}
FakeRemoteService.__index = FakeRemoteService

function FakeRemoteService.new(options: { declarations: { any }? }?)
	local byName = {}
	for _, decl in (options and options.declarations) or {} do
		byName[decl.name] = decl
	end
	return setmetatable({ _decls = byName, _handlers = {}, sent = {}, rejected = 0 }, FakeRemoteService)
end

function FakeRemoteService:handle(name: string, fn: (...any) -> ...any)
	assert(self._handlers[name] == nil, `handler for {name} registered twice`)
	local decl = self._decls[name]
	if next(self._decls) ~= nil then
		assert(decl, `{name} is not declared`)
		assert(decl.kind == "event" or decl.kind == "function", `{name} is not a client->server remote`)
	end
	self._handlers[name] = fn
end

function FakeRemoteService:fire(name: string, player: any, ...)
	local decl = self._decls[name]
	if next(self._decls) ~= nil then
		assert(
			decl and (decl.kind == "serverEvent" or decl.kind == "unreliableServerEvent"),
			`{name} is not a server->client remote`
		)
	end
	table.insert(self.sent, { name = name, player = player, args = table.pack(...) })
end

function FakeRemoteService:fireAll(name: string, ...)
	self:fire(name, "all", ...)
end

function FakeRemoteService:call(name: string, player: any, ...): (boolean, any)
	local handler = self._handlers[name]
	local decl = self._decls[name]
	if handler == nil then
		self.rejected += 1
		return false, nil
	end
	if decl then
		local args = table.pack(...)
		local validators = decl.args or {}
		if args.n > #validators then
			self.rejected += 1
			return false, nil
		end
		for i, validator in validators do
			local ok = validator(args[i])
			if not ok then
				self.rejected += 1
				return false, nil
			end
		end
	end
	return true, handler(player, ...)
end

function FakeRemoteService:sentTo(name: string, player: any?): { any }
	local out = {}
	for _, entry in self.sent do
		if entry.name == name and (player == nil or entry.player == player or entry.player == "all") then
			table.insert(out, entry)
		end
	end
	return out
end

return FakeRemoteService
