--!strict
-- Creatures (Build Spec section 7). Species ids are used in saved data; display names can change.

export type Range = { Min: number, Max: number }

export type Goods = {
	Id: string,
	Name: string,
	EverySeconds: number,
	Sell: number,
}

export type Species = {
	Id: string,
	Name: string,
	Stage: number,
	Traits: { Str: Range, Int: Range, End: Range },
	Goods: Goods?,
	EggCost: number?, -- nil = not sold by the merchant
	RareEgg: boolean,
	Roles: { string },
	Value: number, -- base price used for player shops and trading bands
	Tamed: boolean?, -- tamed monster companion (stage 8)
}

local function r(min: number, max: number): Range
	return { Min = min, Max = max }
end

local Creatures = {}

Creatures.List = {
	{ Id = "rabbit", Name = "Rabbit", Stage = 1, Traits = { Str = r(15, 35), Int = r(15, 35), End = r(15, 35) }, RareEgg = false, Roles = { "Farmer" }, Value = 100 },
	{ Id = "chicken", Name = "Chicken", Stage = 3, Traits = { Str = r(10, 30), Int = r(10, 30), End = r(15, 35) }, Goods = { Id = "egg", Name = "Egg", EverySeconds = 120, Sell = 25 }, EggCost = 150, RareEgg = false, Roles = { "Producer", "Farmer" }, Value = 150 },
	{ Id = "sheep", Name = "Sheep", Stage = 3, Traits = { Str = r(15, 35), Int = r(10, 30), End = r(20, 40) }, Goods = { Id = "wool", Name = "Wool", EverySeconds = 240, Sell = 80 }, EggCost = 400, RareEgg = false, Roles = { "Producer", "Farmer" }, Value = 400 },
	{ Id = "cow", Name = "Cow", Stage = 4, Traits = { Str = r(25, 45), Int = r(10, 30), End = r(30, 50) }, Goods = { Id = "milk", Name = "Milk", EverySeconds = 360, Sell = 150 }, EggCost = 900, RareEgg = false, Roles = { "Producer", "Farmer" }, Value = 900 },
	{ Id = "dog", Name = "Dog", Stage = 5, Traits = { Str = r(35, 55), Int = r(25, 45), End = r(30, 50) }, EggCost = 1500, RareEgg = false, Roles = { "Guardian", "Farmer" }, Value = 1500 },
	{ Id = "owl", Name = "Owl", Stage = 5, Traits = { Str = r(10, 30), Int = r(45, 65), End = r(15, 35) }, EggCost = 1800, RareEgg = false, Roles = { "Scout", "Farmer" }, Value = 1800 },
	{ Id = "fox", Name = "Fox", Stage = 5, Traits = { Str = r(25, 45), Int = r(45, 65), End = r(20, 40) }, RareEgg = true, Roles = { "Scout", "MonsterHunter", "Farmer" }, Value = 5000 },
	{ Id = "boar", Name = "Boar", Stage = 5, Traits = { Str = r(50, 70), Int = r(15, 35), End = r(40, 60) }, EggCost = 3000, RareEgg = false, Roles = { "Guardian", "MonsterHunter", "Farmer" }, Value = 3000 },
	{ Id = "moth", Name = "Spirit Moth", Stage = 6, Traits = { Str = r(10, 30), Int = r(30, 50), End = r(20, 40) }, Goods = { Id = "moondust", Name = "Moon Dust", EverySeconds = 480, Sell = 400 }, RareEgg = true, Roles = { "RareCompanion", "Producer" }, Value = 8000 },
	-- Tamed monster companions (stage 8): raised from eggs found in monster nests
	{ Id = "pip", Name = "Tamed Swarmer", Stage = 8, Traits = { Str = r(25, 45), Int = r(20, 40), End = r(20, 40) }, RareEgg = true, Roles = { "Guardian", "MonsterHunter" }, Value = 2500, Tamed = true },
	{ Id = "bruno", Name = "Tamed Brute", Stage = 8, Traits = { Str = r(60, 80), Int = r(10, 30), End = r(50, 70) }, RareEgg = true, Roles = { "Guardian", "MonsterHunter" }, Value = 6000, Tamed = true },
	{ Id = "tricky", Name = "Tamed Trickster", Stage = 9, Traits = { Str = r(30, 50), Int = r(55, 75), End = r(25, 45) }, RareEgg = true, Roles = { "Scout", "MonsterHunter" }, Value = 7000, Tamed = true },
} :: { Species }

Creatures.ById = {} :: { [string]: Species }
for _, species in Creatures.List do
	Creatures.ById[species.Id] = species
end

-- Placeholder looks built from parts (section 23.8 placeholder rule)
Creatures.Looks = {
	rabbit = { Body = Color3.fromRGB(245, 240, 235), Accent = Color3.fromRGB(255, 170, 190), Size = 1.8, Ears = true },
	chicken = { Body = Color3.fromRGB(255, 250, 230), Accent = Color3.fromRGB(230, 50, 40), Size = 1.5, Ears = false },
	sheep = { Body = Color3.fromRGB(240, 240, 240), Accent = Color3.fromRGB(60, 50, 50), Size = 2.4, Ears = false },
	cow = { Body = Color3.fromRGB(250, 250, 250), Accent = Color3.fromRGB(40, 40, 40), Size = 3.0, Ears = false },
	dog = { Body = Color3.fromRGB(190, 130, 70), Accent = Color3.fromRGB(90, 60, 30), Size = 2.2, Ears = true },
	owl = { Body = Color3.fromRGB(150, 110, 80), Accent = Color3.fromRGB(255, 210, 80), Size = 1.6, Ears = true },
	fox = { Body = Color3.fromRGB(240, 120, 40), Accent = Color3.fromRGB(255, 255, 255), Size = 2.0, Ears = true },
	boar = { Body = Color3.fromRGB(110, 80, 60), Accent = Color3.fromRGB(240, 230, 200), Size = 2.6, Ears = true },
	moth = { Body = Color3.fromRGB(200, 210, 255), Accent = Color3.fromRGB(150, 120, 255), Size = 1.6, Ears = true },
	pip = { Body = Color3.fromRGB(170, 110, 230), Accent = Color3.fromRGB(255, 255, 140), Size = 1.8, Ears = false },
	bruno = { Body = Color3.fromRGB(170, 80, 70), Accent = Color3.fromRGB(240, 230, 200), Size = 3.2, Ears = true },
	tricky = { Body = Color3.fromRGB(70, 180, 140), Accent = Color3.fromRGB(255, 255, 255), Size = 2.2, Ears = true },
}

-- Recolor token palette (dp_recolor): looks only, traits and mutations unchanged
Creatures.RecolorPalette = {
	Color3.fromRGB(245, 240, 235),
	Color3.fromRGB(255, 200, 120),
	Color3.fromRGB(140, 200, 255),
	Color3.fromRGB(255, 160, 200),
	Color3.fromRGB(160, 230, 150),
	Color3.fromRGB(90, 90, 100),
	Color3.fromRGB(200, 160, 255),
}

Creatures.StarterSpecies = "rabbit"
Creatures.Sexes = { "Boy", "Girl" } -- 50/50, never changes traits
Creatures.TraitMin = 0
Creatures.TraitMax = 100
Creatures.TraitKeys = { "Str", "Int", "End" }
Creatures.MaxNameLength = 20

-- Trait effects (section 7.2)
Creatures.TraitEffects = {
	AttackBase = 3,
	AttackPerStr = 0.2,
	CarryPerStr = 40, -- +1 item per 40 Str
	DetectionBase = 20,
	DetectionPerInt = 0.3,
	JobEfficiencyIntDivisor = 200, -- efficiency x (1 + Int / 200)
	TrapAvoidIntDivisor = 250,
	HealthPenaltyIntAbove = 50, -- -1% max health per 10 Int above 50
	HealthBase = 50,
	HealthPerEnd = 1.5,
	SpeedPenaltyEndAbove = 50, -- -1% speed per 10 End above 50
}

-- Roles (section 7.4). Stage is when the role unlocks.
Creatures.Roles = {
	Farmer = { Stage = 3, Text = "Harvests ready crops nearby", Range = 12, IntervalSeconds = 10 },
	Producer = { Stage = 3, Text = "Makes goods (needs Fed 25+)" },
	Scout = { Stage = 5, Text = "Warns 10 s earlier and shows the monsters' direction" },
	Guardian = { Stage = 5, Text = "Fights monsters; nearby creatures take 25% less damage", Range = 15, DamageReduction = 0.25 },
	MonsterHunter = { Stage = 5, Text = "Fights monsters with +30% damage", DamageBonus = 0.30 },
	RareCompanion = { Stage = 6, Text = "+1% mutation chance for the garden (max +5%)", MutationBonusPer = 0.01, MutationBonusCap = 0.05 },
}
Creatures.RoleOrder = { "Farmer", "Producer", "Scout", "Guardian", "MonsterHunter", "RareCompanion" }
Creatures.FighterRoles = { Guardian = true, MonsterHunter = true }

Creatures.LifeStages = { "Baby", "Young", "Adult", "Elder" }

-- Rare powers from breeding (section 12.2)
Creatures.RarePowers = { "NightVision", "ShadowStep", "GiantSize" }

-- Creature gifts (section 22.2)
Creatures.SecondCreatureGift = { Species = "chicken", AfterNight = 2, HatchSeconds = 180 }
Creatures.MysteryEgg = { Level = 4, Pool = { "chicken", "sheep" } }
Creatures.BruteEggDropChance = 0.05

return Creatures
