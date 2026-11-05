--!strict
-- Crops (Build Spec section 5). Ready when
--   os.time() - PlantedAt >= GrowSeconds * soilMult * sprinklerMult (minus water taps)
-- Multi-harvest crops stay planted and regrow after RegrowSeconds until Harvests runs out.

export type Crop = {
	Id: string,
	Name: string,
	Stage: number,
	SeedCost: number,
	GrowSeconds: number,
	Harvests: number,
	RegrowSeconds: number?,
	Sell: number,
	XP: number,
	MoonlitChance: number,
	Glowing: boolean,
	Rare: boolean,
	HungerChange: number?, -- Lure Berry only
	MinLevel: number?, -- micro-unlock: also needs this Garden Level (section 4.5)
	Color: Color3,
	FruitSize: number,
}

local Crops = {}

Crops.List = {
	{ Id = "carrot", Name = "Carrot", Stage = 1, SeedCost = 10, GrowSeconds = 20, Harvests = 1, Sell = 16, XP = 2, MoonlitChance = 0.10, Glowing = false, Rare = false, Color = Color3.fromRGB(255, 140, 40), FruitSize = 1.2 },
	{ Id = "radish", Name = "Radish", Stage = 1, SeedCost = 25, GrowSeconds = 30, Harvests = 1, Sell = 42, XP = 3, MoonlitChance = 0.10, Glowing = false, Rare = false, MinLevel = 2, Color = Color3.fromRGB(220, 60, 120), FruitSize = 1.2 },
	{ Id = "tomato", Name = "Tomato", Stage = 2, SeedCost = 60, GrowSeconds = 60, Harvests = 3, RegrowSeconds = 40, Sell = 110, XP = 5, MoonlitChance = 0.10, Glowing = false, Rare = false, MinLevel = 3, Color = Color3.fromRGB(230, 50, 40), FruitSize = 1.4 },
	{ Id = "corn", Name = "Corn", Stage = 3, SeedCost = 150, GrowSeconds = 120, Harvests = 3, RegrowSeconds = 80, Sell = 300, XP = 8, MoonlitChance = 0.10, Glowing = false, Rare = false, Color = Color3.fromRGB(250, 215, 60), FruitSize = 1.6 },
	{ Id = "pumpkin", Name = "Pumpkin", Stage = 3, SeedCost = 500, GrowSeconds = 300, Harvests = 1, Sell = 1500, XP = 15, MoonlitChance = 0.10, Glowing = false, Rare = false, Color = Color3.fromRGB(240, 120, 20), FruitSize = 2.6 },
	{ Id = "glowberry", Name = "Glowberry", Stage = 4, SeedCost = 400, GrowSeconds = 240, Harvests = 2, RegrowSeconds = 150, Sell = 900, XP = 12, MoonlitChance = 0.25, Glowing = true, Rare = false, Color = Color3.fromRGB(80, 230, 255), FruitSize = 1.3 },
	{ Id = "starfruit", Name = "Starfruit", Stage = 5, SeedCost = 3000, GrowSeconds = 900, Harvests = 1, Sell = 9000, XP = 40, MoonlitChance = 0.12, Glowing = false, Rare = true, Color = Color3.fromRGB(255, 240, 120), FruitSize = 1.6 },
	{ Id = "moonmelon", Name = "Moon Melon", Stage = 5, SeedCost = 2500, GrowSeconds = 600, Harvests = 1, Sell = 7000, XP = 35, MoonlitChance = 0.30, Glowing = true, Rare = true, Color = Color3.fromRGB(170, 200, 255), FruitSize = 2.2 },
	{ Id = "lureberry", Name = "Lure Berry", Stage = 6, SeedCost = 20, GrowSeconds = 45, Harvests = 1, Sell = 15, XP = 1, MoonlitChance = 0, Glowing = false, Rare = false, HungerChange = -5, Color = Color3.fromRGB(200, 40, 200), FruitSize = 1.0 },
} :: { Crop }

Crops.ById = {} :: { [string]: Crop }
for _, crop in Crops.List do
	Crops.ById[crop.Id] = crop
end

-- Growth modifiers
Crops.SoilMultiplier = { 1.0, 0.9, 0.8 } -- index = soil level
Crops.SoilUpgradeCost = { [2] = 200, [3] = 800 }
Crops.SprinklerMultiplier = 0.8
Crops.SprinklerRadiusTiles = 2
Crops.MoonlitSellMult = 1.5
Crops.StarterSeeds = { carrot = 3 } -- given on first join

return Crops
