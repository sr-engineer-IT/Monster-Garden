--!strict
-- NPC merchant and player shop rules (Build Spec section 6). Robux items live in Products.

local Shop = {}

-- Seeds always in stock once their stage is reached (rare seeds use rare slots)
Shop.CommonSeeds = { "carrot", "radish", "tomato", "corn", "pumpkin", "glowberry", "lureberry" }

-- Creature eggs sold from stage 3 (feature "Eggs"); each species has its own stage too
Shop.CommonEggs = { "chicken", "sheep", "cow", "dog", "owl", "boar" }

-- Rare restock: each slot rolls Config.RareRestockChance every Config.MerchantRestockSeconds
Shop.RareSlots = 6
Shop.RarePool = {
	{ Kind = "Seed", Id = "starfruit", Weight = 50 },
	{ Kind = "Seed", Id = "moonmelon", Weight = 40 },
	{ Kind = "Egg", Id = "fox", Weight = 7, Price = 5000 },
	{ Kind = "Egg", Id = "moth", Weight = 3, Price = 8000 },
}

-- Merchant buy price for one Monster Essence (assumption: not in spec, keep low so Essence is spent)
Shop.EssenceSellPrice = 5

Shop.MaxBuyQuantity = 99
Shop.EggHatchSeconds = 60 -- bought eggs hatch after this many seconds

-- Player shop stalls (stage 5)
Shop.PlayerShop = {
	FeeShare = 0.05, -- 5% fee on sales (coin sink)
	-- Allowed listing price band relative to the merchant value (assumption: limits price manipulation)
	MinPriceMult = 0.5,
	MaxPriceMult = 3.0,
	MaxListings = 6,
}

return Shop
