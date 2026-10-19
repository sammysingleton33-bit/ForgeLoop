--!strict
--[[
	Arena/Types — the Crown Arena and support types (CONTRACTS G12.1, D-029; design `design/crown-arena.md`).
	Owner: FORGE-01. Types only: nothing here runs. The shapes are the contract's; `Modifier` and the duel types below
	are the ones FORGE-05's fairness harness already uses (tests/fairness/CapsCheck.luau, DuelDouble.luau).
]]

export type KingdomId = string
export type EntityId = number

export type SupportTier = "adoring" | "loyal" | "divided" | "restless" | "hostile"
export type SupportComponent = "reputation" | "happiness" | "stability" | "morale" | "loyalty" | "conduct" | "valour"
export type KeyRole = "blacksmith" | "healer" | "captain" | "provisioner" | "elder" | "merchant"
export type TriggerId =
	"reforge"
	| "fieldRemedy"
	| "calledWarning"
	| "heartyRations"
	| "rallyingHymn"
	| "fineWares"
	| "crowdRally"

export type LeadershipMoment = {
	t: number,
	kingdom: KingdomId,
	userId: number?,
	act: string,
	component: SupportComponent,
	delta: number,
	text: string, -- pre-authored, never user input
}

export type TriggerOffer = {
	trigger: TriggerId,
	citizenId: EntityId?,
	citizenName: string?,
	role: KeyRole?,
	loyalty: number?,
	power: "pledged" | "empowered",
	condition: string,
	effect: string,
} -- crowdRally has no citizen

export type SupportView = {
	kingdom: KingdomId,
	userId: number,
	score: number,
	tier: SupportTier,
	trend: number,
	breakdown: { [SupportComponent]: number },
	moments: { LeadershipMoment },
	offers: { TriggerOffer },
	slots: number,
}

export type Weapon = "swordShield" | "greatsword" | "spear" | "mace"
export type Armour = "light" | "medium" | "heavy"

export type Duellist = {
	userId: number,
	kingdom: KingdomId,
	isAI: boolean,
	tier: SupportTier,
	score: number,
	weapon: Weapon?,
	armour: Armour?,
	triggers: { TriggerId },
	reasons: { string }, -- the top 3 moment texts
	triggerCitizens: { [string]: { name: string, role: string } }?, -- TriggerId -> the key citizen behind it (not the Crowd Rally)
}

export type ArenaStage = "qualify" | "vote" | "loadout" | "intro" | "duel" | "crowning" | "done"
export type ArenaState = {
	stage: ArenaStage,
	endsAt: number?,
	a: Duellist?,
	b: Duellist?,
	coronation: KingdomId?,
	winner: number?,
}
export type DuelAction = "light" | "heavy" | "block" | "blockEnd" | "parry" | "dodge"

-- One support effect on one duellist (the shape Caps.check and DuelModel read; CONTRACTS G12.2 names the type, this
-- defines it). See Arena/Caps for the rules.
export type Modifier = {
	source: string, -- "tier:adoring", "perk:reforge", "crowdRally", "fineWares"
	kind: string, -- "passive" | "trigger" | "heal" | "telegraph"
	stat: string?, -- passive and trigger: damageReduction | damage | staminaRegen
	magnitude: number?, -- a fraction (+6 % = 0.06); heal: a fraction of max HP
	duration: number?, -- seconds; trigger, heal and telegraph
	condition: string?, -- "hpBelow:0.5" | "staminaOut" | "opponentHeavy" | "hype"
	earliest: number?, -- earliest duel second it may fire; nil = the quiet start
	lead: number?, -- telegraph: seconds earlier the opponent's heavy is shown
	uses: number?, -- telegraph: heavy attacks covered
	slot: boolean?, -- a passive that takes a trigger slot (Fine Wares)
	affectsOpponent: boolean?, -- always forbidden
}

export type DuellistSetup = { weapon: Weapon?, armour: Armour?, modifiers: { Modifier }? }
export type DuelInput = { action: DuelAction?, inRange: boolean, facing: boolean }
export type DuelEvent = { t: number, kind: string, side: string, data: { [string]: any }? }

return {}
