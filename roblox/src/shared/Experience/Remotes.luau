--!strict
--[[
	Experience/Remotes — FORGE-04 remote declarations (interfaces §6). RemoteService (FORGE-01)
	aggregates them with env.sharedModules("Remotes") and creates
	ReplicatedStorage.ForgeRemotes.Experience.<Action>.

	| Remote                       | Kind        | Payload |
	| Experience.Settings          | serverEvent | (settings: { [key]: value }) — on profile load and after every change |
	| Experience.SetSetting        | event       | (key: SETTING_KEYS, value: boolean | number 0..1 | string) — SettingsController coalesces taps: one per key once it has been still for 0.3 s (SEND_DELAY_SEC) |
	| Experience.OnboardingState   | serverEvent | (state: OnboardingState) — Experience/Onboarding.snapshot() |
	| Experience.OnboardingAction  | event       | (flowId, action) — client-observed actions ("CameraMoved", "PanelOpened:Resources") |
	| Experience.OnboardingSkip    | event       | (flowId) |
]]

local Schema = require("./Schema")
local V = require("../Core/Validate")

-- A setting value: a boolean, a volume 0..1, or a short enum string (Schema.checkSetting re-checks per key).
local settingValue = V.oneOf({ V.boolean(), V.number(0, 1), V.string(1, 16) })

return {
	{ name = "Experience.Settings", kind = "serverEvent" },
	{
		name = "Experience.SetSetting",
		kind = "event",
		args = { V.enum(Schema.SETTING_KEYS), settingValue },
		rate = { burst = 10, perSecond = 2 },
	},
	{ name = "Experience.OnboardingState", kind = "serverEvent" },
	{
		name = "Experience.OnboardingAction",
		kind = "event",
		args = { V.string(1, 32), V.string(1, 48) },
		rate = { burst = 6, perSecond = 2 },
	},
	{
		name = "Experience.OnboardingSkip",
		kind = "event",
		args = { V.string(1, 32) },
		rate = { burst = 2, perSecond = 0.2 },
	},
}
