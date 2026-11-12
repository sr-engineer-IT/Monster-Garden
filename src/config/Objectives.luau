--!strict
-- Goal chain (design doc section 6, Build Spec section 22.1-22.2). One goal shows at a time.
-- Event goals count matching events; Stat goals read a profile number (e.g. GardenLevel).

export type Objective = {
	Id: string,
	Text: string,
	Event: string?, -- counted event name
	Stat: string?, -- or: profile field that must reach Count
	Count: number,
	XP: number,
}

local Objectives = {}

Objectives.List = {
	{ Id = "plant3", Text = "Plant 3 seeds", Event = "Plant", Count = 3, XP = 20 },
	{ Id = "harvest3", Text = "Harvest 3 crops", Event = "Harvest", Count = 3, XP = 20 },
	{ Id = "sell1", Text = "Sell your crops at the merchant cart", Event = "Sell", Count = 1, XP = 20 },
	{ Id = "buyseed", Text = "Buy more seeds", Event = "BuySeed", Count = 1, XP = 20 },
	{ Id = "pet1", Text = "Pet your rabbit", Event = "Pet", Count = 1, XP = 20 },
	{ Id = "night1", Text = "Survive your first night", Stat = "NightsSurvived", Count = 1, XP = 40 },
	{ Id = "fence", Text = "Build a fence at a garden gate", Event = "Build:wood_fence", Count = 1, XP = 30 },
	{ Id = "lantern", Text = "Build a lantern", Event = "Build:lantern", Count = 1, XP = 30 },
	{ Id = "petal", Text = "Collect a glowing Moon Petal", Event = "Petal", Count = 1, XP = 20 },
	{ Id = "feed3", Text = "Feed your creature three times", Event = "Feed", Count = 3, XP = 30 },
	{ Id = "swarmers10", Text = "Defeat 10 Swarmers", Event = "Kill:swarmer", Count = 10, XP = 50 },
	{ Id = "expand", Text = "Buy more farm land at the merchant cart", Event = "Expand", Count = 1, XP = 40 },
	{ Id = "night3", Text = "Survive 3 nights", Stat = "NightsSurvived", Count = 3, XP = 60 },
	{ Id = "level5", Text = "Reach Garden Level 5", Stat = "GardenLevel", Count = 5, XP = 100 },
	{ Id = "egg", Text = "Buy a creature egg", Event = "BuyEgg", Count = 1, XP = 50 },
	{ Id = "soil", Text = "Upgrade your soil", Event = "Soil", Count = 1, XP = 50 },
	{ Id = "reinforce", Text = "Reinforce a fence with Essence", Event = "Build:reinforced_fence", Count = 1, XP = 60 },
	{ Id = "brute", Text = "Defeat a Brute", Event = "Kill:brute", Count = 1, XP = 100 },
	{ Id = "night10", Text = "Survive 10 nights", Stat = "NightsSurvived", Count = 10, XP = 150 },
	{ Id = "level10", Text = "Reach Garden Level 10", Stat = "GardenLevel", Count = 10, XP = 200 },
	{ Id = "nest", Text = "Build a breeding nest", Event = "Build:nest", Count = 1, XP = 100 },
	{ Id = "baby", Text = "Raise your first baby", Event = "Baby", Count = 1, XP = 200 },
	{ Id = "train", Text = "Train a young creature", Event = "Train", Count = 1, XP = 100 },
	{ Id = "level13", Text = "Reach Garden Level 13", Stat = "GardenLevel", Count = 13, XP = 250 },
	{ Id = "visit", Text = "Visit another garden", Event = "Visit", Count = 1, XP = 100 },
	{ Id = "list", Text = "List something in your shop stall", Event = "List", Count = 1, XP = 100 },
	{ Id = "level17", Text = "Reach Garden Level 17", Stat = "GardenLevel", Count = 17, XP = 300 },
	{ Id = "lure", Text = "Throw a Lure Berry to calm the monsters", Event = "LureBerry", Count = 1, XP = 150 },
	{ Id = "level25", Text = "Reach Garden Level 25", Stat = "GardenLevel", Count = 25, XP = 400 },
	{ Id = "level30", Text = "Reach Garden Level 30", Stat = "GardenLevel", Count = 30, XP = 500 },
	{ Id = "clearnest", Text = "Destroy a monster nest in the forest", Event = "NestCleared", Count = 1, XP = 400 },
	{ Id = "tame", Text = "Hatch a tamed monster egg", Event = "Tame", Count = 1, XP = 400 },
	{ Id = "level40", Text = "Reach Garden Level 40", Stat = "GardenLevel", Count = 40, XP = 800 },
	{ Id = "feast", Text = "Take part in Feast Night", Event = "Feast", Count = 1, XP = 800 },
	{ Id = "trade", Text = "Complete a trade with another player", Event = "Trade", Count = 1, XP = 300 },
} :: { Objective }

Objectives.DoneText = "All goals done! More is coming soon."

return Objectives
