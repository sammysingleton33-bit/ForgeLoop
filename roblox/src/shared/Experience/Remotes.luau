--!strict
--[[
	Experience/Remotes — FORGE-04 remote declarations (interfaces §6). RemoteService (FORGE-01)
	aggregates them with env.sharedModules("Remotes") and creates
	ReplicatedStorage.ForgeRemotes.Experience.<Action>.

	| Remote                       | Kind        | Payload |
	| Experience.Settings          | serverEvent | (settings: { [key]: value }) — on profile load and after every change |
	| Experience.SetSetting        | event       | (key: SETTING_KEYS, value: boolean | number 0..1 | string) — client sends on release, not per slider tick |
	| Experience.OnboardingState   | serverEvent | (state: OnboardingState) — Experience/Onboarding.snapshot() |
	| Experience.OnboardingAction  | event       | (flowId, action) — client-observed actions ("CameraMoved", "PanelOpened:Resources") |
	| Experience.OnboardingSkip    | event       | (flowId) |
]]

local Schema = require("./Schema")
local Validators = require("./Validators")

return {
	{ name = "Experience.Settings", kind = "serverEvent" },
	{
		name = "Experience.SetSetting",
		kind = "event",
		args = { Validators.enum(Schema.SETTING_KEYS), Validators.settingValue() },
		rate = { burst = 10, perSecond = 2 },
	},
	{ name = "Experience.OnboardingState", kind = "serverEvent" },
	{
		name = "Experience.OnboardingAction",
		kind = "event",
		args = { Validators.string(1, 32), Validators.string(1, 48) },
		rate = { burst = 6, perSecond = 2 },
	},
	{
		name = "Experience.OnboardingSkip",
		kind = "event",
		args = { Validators.string(1, 32) },
		rate = { burst = 2, perSecond = 0.2 },
	},
}
