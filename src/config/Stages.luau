--!strict
-- Progressive Unlock System (Build Spec section 4, with section 22.3 level changes).
-- Unlock by play progress, never real time. Each feature key is unlocked by exactly one stage.

export type Trigger = {
	Level: number?,
	NightsSurvived: number?,
	AdultCreatures: number?,
}

export type Stage = {
	Id: number,
	Name: string,
	Trigger: Trigger,
	Features: { string },
	DaySeconds: number,
	NightSeconds: number,
	NightEveryDays: number, -- 2 = a night every second day
	Tip: string,
}

local Stages = {}

Stages.List = {
	{
		Id = 1,
		Name = "Seeds",
		Trigger = {},
		Features = { "Plant", "Sell" },
		DaySeconds = 120,
		NightSeconds = 45,
		NightEveryDays = 2,
		Tip = "Plant seeds, harvest them and sell to the merchant.",
	},
	{
		Id = 2,
		Name = "Defense",
		Trigger = { NightsSurvived = 1 },
		-- FriendVisit: friends-only visits and co-op defense (section 4.5). Public visits wait for stage 5.
		Features = { "Fence", "Lantern", "Essence", "Moonlit", "FriendVisit" },
		DaySeconds = 180,
		NightSeconds = 75,
		NightEveryDays = 2,
		Tip = "Build fences and lanterns to protect your garden at night.",
	},
	{
		Id = 3,
		Name = "Growth",
		Trigger = { Level = 5 },
		Features = { "Sprinkler", "SoilUpgrade", "Jobs", "Eggs", "Trap", "ReinforcedFence" },
		DaySeconds = 240,
		NightSeconds = 90,
		NightEveryDays = 2,
		Tip = "Buy creature eggs, upgrade your soil and reinforce your fences. Watch out for Brutes!",
	},
	{
		Id = 4,
		Name = "Family",
		Trigger = { Level = 10, AdultCreatures = 2 },
		Features = { "Traits", "Breeding", "Nests", "Training" },
		DaySeconds = 300,
		NightSeconds = 150,
		NightEveryDays = 1,
		Tip = "Pair two adults in a nest to raise a baby.",
	},
	{
		Id = 5,
		Name = "Friends",
		Trigger = { Level = 13 },
		Features = { "Visit", "PlayerShop", "Leaderboards", "Watchtower", "Shelter" },
		DaySeconds = 330,
		NightSeconds = 165,
		NightEveryDays = 1,
		Tip = "Visit gardens, open a shop stall and help neighbors defend.",
	},
	{
		Id = 6,
		Name = "Hunger",
		Trigger = { Level = 17 },
		Features = { "Hunger", "LureBerry" },
		DaySeconds = 360,
		NightSeconds = 180,
		NightEveryDays = 1,
		Tip = "Monsters get hungrier as you defend. Feed them Lure Berries to calm them.",
	},
	{
		Id = 7,
		Name = "Legacy",
		Trigger = { Level = 25 },
		Features = { "Elder", "Spirit", "Kidnap" },
		DaySeconds = 360,
		NightSeconds = 180,
		NightEveryDays = 1,
		Tip = "Old creatures become Spirits that strengthen their bloodline.",
	},
	{
		Id = 8,
		Name = "Explore",
		Trigger = { Level = 30 },
		Features = { "Explore", "Taming", "Caves" },
		DaySeconds = 360,
		NightSeconds = 180,
		NightEveryDays = 1,
		Tip = "Explore the forest, clear nests and tame monsters.",
	},
	{
		Id = 9,
		Name = "Endgame",
		Trigger = { Level = 40 },
		Features = { "Feast", "Heist", "Trading", "Territories", "Moonlands" },
		DaySeconds = 360,
		NightSeconds = 180,
		NightEveryDays = 1,
		Tip = "Join Feast Night, raise a Heist Flag and trade with others.",
	},
} :: { Stage }

-- Stage 1 special case: the first night starts this many seconds after first spawn
Stages.FirstNightAfterSpawnSeconds = 120 -- first night after 2 minutes: show what makes the game special early (was 210)

-- Veteran skip (section 4.3)
Stages.VeteranSkip = {
	TargetStage = 3,
	GiftCoins = 200,
	GiftSeeds = 3,
}

-- Micro-unlocks between stages (section 4.5)
Stages.MicroUnlocks = {
	[2] = { Seeds = { "radish" }, PlotOffered = true, Title = "Sprout" },
	[3] = { MerchantShows = { "tomato" }, PlotOffered = true, Decoration = "scarecrow" },
	[4] = { PlotOffered = true, GiftCoins = 100, Cosmetic = "lantern_skin_1", MysteryEgg = true },
}

-- Teasers for locked features (section 22.3)
Stages.Teasers = {
	{ Id = "SpiritGroveGate", FromStage = 1, Text = "Unlocks at Level 25" },
	{ Id = "ElderSilhouette", FromStage = 3, Text = "" },
	{ Id = "HungerIcon", FromStage = 3, Text = "Unlocks at Level 17" },
	{ Id = "HeistAndFeast", FromStage = 4, Text = "Coming later" },
}

-- Build a lookup feature -> stage id once
local featureStage: { [string]: number } = {}
for _, stage in Stages.List do
	for _, feature in stage.Features do
		assert(featureStage[feature] == nil, `Feature {feature} is unlocked by two stages`)
		featureStage[feature] = stage.Id
	end
end
Stages.FeatureStage = featureStage

function Stages.Get(stageId: number): Stage
	return Stages.List[math.clamp(stageId, 1, #Stages.List)]
end

return Stages
