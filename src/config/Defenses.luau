--!strict
-- Defenses (Build Spec section 9). Defenses absorb damage before creatures are harmed,
-- but never make survival fully automatic.

export type Cost = { Coins: number?, Essence: number? }

export type Defense = {
	Id: string,
	Name: string,
	Stage: number,
	Feature: string, -- ProgressionService feature key
	Cost: Cost,
	Health: number?, -- nil = no health (one-use or non-combat)
	MaxCount: number?,
	-- Optional effects
	BlocksEdge: boolean?,
	LightRadius: number?,
	MonsterSpeedMult: number?, -- monsters in light move at this speed multiplier
	SwarmerRetreatChance: number?,
	OneUse: boolean?,
	AreaDamage: number?,
	AreaRadius: number?,
	DetectionBonus: number?,
	Capacity: number?,
	-- Gates
	Next: string?, -- the gate this one upgrades to
	MinLevel: number?, -- Garden Level needed to build or upgrade to it
	DamageTakenMult: number?, -- below 1 = takes less damage
	Thorns: number?, -- damage per second to monsters breaking it
	Glow: Color3?, -- glows at night
	Power: string?, -- short text shown in the build prompt
}

local Defenses = {}

Defenses.List = {
	{ Id = "wood_fence", Name = "Wooden Fence", Stage = 2, Feature = "Fence", Cost = { Coins = 50 }, Health = 100, BlocksEdge = true, Next = "reinforced_fence", Power = "Blocks the gate" },
	{ Id = "lantern", Name = "Lantern", Stage = 2, Feature = "Lantern", Cost = { Coins = 80 }, Health = 60, MaxCount = 6, LightRadius = 25, MonsterSpeedMult = 0.8, SwarmerRetreatChance = 0.3 },
	{ Id = "reinforced_fence", Name = "Reinforced Fence", Stage = 3, Feature = "ReinforcedFence", Cost = { Essence = 30 }, Health = 400, BlocksEdge = true, Next = "iron_fence", DamageTakenMult = 0.75, Power = "Sturdy: takes 25% less damage" },
	{ Id = "iron_fence", Name = "Iron Gate", Stage = 3, Feature = "ReinforcedFence", MinLevel = 20, Cost = { Coins = 8000, Essence = 150 }, Health = 900, BlocksEdge = true, Next = "moon_fence", DamageTakenMult = 0.75, Thorns = 12, Power = "Spikes: monsters breaking it take 12 damage per second" },
	{ Id = "moon_fence", Name = "Moon Gate", Stage = 3, Feature = "ReinforcedFence", MinLevel = 35, Cost = { Coins = 40000, Essence = 600 }, Health = 2000, BlocksEdge = true, DamageTakenMult = 0.6, Thorns = 25, Glow = Color3.fromRGB(160, 200, 255), Power = "Moonlight: takes 40% less damage, monsters take 25 damage per second" },
	{ Id = "trap", Name = "Trap", Stage = 3, Feature = "Trap", Cost = { Coins = 30 }, OneUse = true, AreaDamage = 40, AreaRadius = 6 },
	{ Id = "nest", Name = "Breeding Nest", Stage = 4, Feature = "Nests", Cost = { Coins = 300 } },
	{ Id = "watchtower", Name = "Watchtower", Stage = 5, Feature = "Watchtower", Cost = { Coins = 400, Essence = 50 }, Health = 300, DetectionBonus = 40 },
	{ Id = "shelter", Name = "Shelter", Stage = 5, Feature = "Shelter", Cost = { Essence = 200 }, Health = 500, Capacity = 4 },
} :: { Defense }

Defenses.ById = {} :: { [string]: Defense }
for _, defense in Defenses.List do
	Defenses.ById[defense.Id] = defense
end

Defenses.RepairCostShare = 0.20 -- 20% of the price
Defenses.RepairSeconds = 3
Defenses.FirstBruteGift = "reinforced_fence" -- section 22.2: free on the first Brute night

return Defenses
