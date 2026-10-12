--!strict
--[[
	Contracts/BuildStamp — reads the build identity written by roblox/scripts/stamp_build.sh
	(docs/architecture/interfaces.md §11).

	stamp_build.sh writes roblox/src/shared/BuildInfo.json (gitignored); Rojo turns it into the
	ModuleScript ReplicatedStorage.Forge.BuildInfo. An unstamped build simply has no such module.

	API
		BuildStamp.read(forgeFolder, requireModule?) -> BuildInfo?   -- nil when absent or malformed
		BuildStamp.fields(info?) -> { [string]: any }                 -- log fields; sha = "unstamped" when nil
		BuildStamp.describe(info?) -> string                          -- "sha=<sha> branch=<b> builtAt=<t>"
	BuildInfo = { sha: string, branch: string, builtAt: string, dirty: boolean? }
]]

export type BuildInfo = {
	sha: string,
	branch: string,
	builtAt: string,
	dirty: boolean?,
}

local BuildStamp = {}

function BuildStamp.read(forgeFolder: any, requireModule: ((any) -> any)?): BuildInfo?
	if forgeFolder == nil then
		return nil
	end
	local module = forgeFolder:FindFirstChild("BuildInfo")
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local load = requireModule or require
	local ok, info = pcall(load :: any, module)
	if not ok or type(info) ~= "table" or type(info.sha) ~= "string" then
		return nil
	end
	return info :: BuildInfo
end

function BuildStamp.fields(info: BuildInfo?): { [string]: any }
	if info == nil then
		return { sha = "unstamped", hint = "run roblox/scripts/stamp_build.sh before rojo build/serve" }
	end
	return {
		sha = info.sha,
		branch = info.branch,
		builtAt = info.builtAt,
		dirty = if info.dirty then true else nil,
	}
end

function BuildStamp.describe(info: BuildInfo?): string
	if info == nil then
		return "sha=unstamped"
	end
	local text = `sha={info.sha} branch={info.branch} builtAt={info.builtAt}`
	if info.dirty then
		text ..= " dirty=true"
	end
	return text
end

return BuildStamp
