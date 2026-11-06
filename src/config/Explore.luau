--!strict
-- Exploration regions, monster nests and taming (Build Spec sections 8 and 14, design doc 14).
-- Regions sit in the forest around the gardens. Each nest has guard monsters; defeat the guards,
-- then destroy the nest for rewards. Nests respawn after RespawnSeconds.

export type Reward = {
	Coins: number,
	Essence: number,
	EggChance: number, -- chance of a tamable egg
	EggPool: { string },
	Goods: { [string]: number }?,
	Seeds: { [string]: number }?,
	StarTouchedChance: number?, -- Moonlands: rare mutation chance for a random creature
}

export type Region = {
	Id: string,
	Name: string,
	Feature: string, -- ProgressionService feature key
	MinLevel: number,
	Center: Vector3,
	Radius: number,
	NestCount: number,
	NestHealth: number,
	Guards: { string }, -- monster ids picked at random
	GuardMin: number,
	GuardMax: number,
	Ground: Color3,
	Reward: Reward,
}

local Explore = {}

Explore.Regions = {
	{
		Id = "forest",
		Name = "Whisper Forest",
		Feature = "Explore",
		MinLevel = 30,
		Center = Vector3.new(0, 0, -480),
		Radius = 70,
		NestCount = 4,
		NestHealth = 150,
		Guards = { "swarmer" },
		GuardMin = 3,
		GuardMax = 5,
		Ground = Color3.fromRGB(70, 110, 60),
		Reward = { Coins = 400, Essence = 10, EggChance = 0.35, EggPool = { "pip" }, Goods = { amber = 2 } },
	},
	{
		Id = "caves",
		Name = "Echo Caves",
		Feature = "Caves",
		MinLevel = 33,
		Center = Vector3.new(480, 0, 0),
		Radius = 55,
		NestCount = 3,
		NestHealth = 300,
		Guards = { "brute", "swarmer" },
		GuardMin = 3,
		GuardMax = 4,
		Ground = Color3.fromRGB(80, 80, 95),
		Reward = { Coins = 900, Essence = 25, EggChance = 0.3, EggPool = { "bruno", "pip" }, Goods = { crystal = 2 } },
	},
	{
		Id = "territories",
		Name = "Monster Territories",
		Feature = "Territories",
		MinLevel = 40,
		Center = Vector3.new(-480, 0, 0),
		Radius = 60,
		NestCount = 4,
		NestHealth = 450,
		Guards = { "trickster", "brute" },
		GuardMin = 4,
		GuardMax = 5,
		Ground = Color3.fromRGB(100, 70, 60),
		Reward = { Coins = 2000, Essence = 50, EggChance = 0.25, EggPool = { "tricky", "fox", "bruno" }, Seeds = { starfruit = 1 } },
	},
	{
		Id = "moonlands",
		Name = "Ancient Moonlands",
		Feature = "Moonlands",
		MinLevel = 45,
		Center = Vector3.new(0, 0, 480),
		Radius = 60,
		NestCount = 3,
		NestHealth = 700,
		Guards = { "brute", "trickster" },
		GuardMin = 4,
		GuardMax = 6,
		Ground = Color3.fromRGB(70, 80, 130),
		Reward = { Coins = 4000, Essence = 90, EggChance = 0.2, EggPool = { "moth", "tricky" }, Goods = { moonshard = 1 }, Seeds = { moonmelon = 1 }, StarTouchedChance = 0.10 },
	},
} :: { Region }

Explore.ById = {} :: { [string]: Region }
for _, region in Explore.Regions do
	Explore.ById[region.Id] = region
end

-- Goods found while exploring (sold at the merchant)
Explore.Goods = {
	amber = { Name = "Amber", Sell = 150 },
	crystal = { Name = "Crystal", Sell = 400 },
	moonshard = { Name = "Moon Shard", Sell = 1500 },
}

Explore.RespawnSeconds = 600
Explore.ActivateDistance = 90 -- guards appear when an unlocked player is this close
Explore.EggHatchSeconds = 120
Explore.GuardHealthMult = 1.5 -- nest guards are a bit tougher than night monsters

return Explore
