--!strict
-- Robux items (Build Spec section 13). Looks, convenience and capped time-savers only.
-- AssetId = 0 is a placeholder: create the pass/product on the Creator Dashboard and paste its id.
-- Items with AssetId 0 show as "Coming soon" in the store and can never be bought.

export type Pass = {
	Id: string,
	Name: string,
	AssetId: number,
	OfferedFromStage: number,
	Price: number,
	Effect: string,
}

export type Product = {
	Id: string,
	Name: string,
	AssetId: number,
	OfferedFromStage: number,
	Price: number,
	DailyCap: number?, -- nil = no cap
	Once: boolean?, -- true = each player can buy it only once (Starter Pack)
	Effect: string,
}

export type Cosmetic = {
	Id: string,
	Name: string,
	Kind: "Glow" | "Theme" | "Title",
	Rarity: "Common" | "Rare" | "Epic",
	Weight: number,
	Color: Color3?,
}

local Products = {}

Products.Passes = {
	{ Id = "pass_plot", Name = "Extra Plot", AssetId = 2072326781, OfferedFromStage = 3, Price = 199, Effect = "+16 soil tiles to place anywhere in your garden" },
	{ Id = "pass_nest", Name = "Extra Nest Slot", AssetId = 2071201228, OfferedFromStage = 4, Price = 149, Effect = "+1 breeding nest slot" },
	{ Id = "pass_inventory", Name = "Bigger Inventory", AssetId = 2074802252, OfferedFromStage = 4, Price = 149, Effect = "+100 bag space" },
	{ Id = "pass_autoharvest", Name = "Auto-Harvest", AssetId = 2071003251, OfferedFromStage = 6, Price = 399, Effect = "Auto-harvests ready crops every 10 s" },
	{ Id = "pass_founder", Name = "Founder Pass", AssetId = 2069936676, OfferedFromStage = 4, Price = 499, Effect = "Founder title, creature glow, garden theme, +50 bag space" },
	{ Id = "pass_shoptheme", Name = "Shop Stall Themes", AssetId = 2072390774, OfferedFromStage = 5, Price = 149, Effect = "Golden shop stall" },
	{ Id = "pass_grovetheme", Name = "Spirit Grove Themes", AssetId = 2074220257, OfferedFromStage = 7, Price = 199, Effect = "Starlight Spirit Grove" },
	{ Id = "pass_vipflair", Name = "Premium Flair", AssetId = 2074370263, OfferedFromStage = 5, Price = 99, Effect = "VIP title" },
	{ Id = "pass_season", Name = "Moon Season Premium", AssetId = 2074130271, OfferedFromStage = 3, Price = 599, Effect = "Premium track of the Moon Season (cosmetics only)" },
} :: { Pass }

Products.DevProducts = {
	{ Id = "dp_rename", Name = "Rename Token", AssetId = 3728675911, OfferedFromStage = 3, Price = 25, Effect = "Rename a creature" },
	{ Id = "dp_recolor", Name = "Recolor Token", AssetId = 3728675951, OfferedFromStage = 4, Price = 49, Effect = "Change a creature's color only" },
	{ Id = "dp_crate1", Name = "Cosmetic Crate", AssetId = 3728676002, OfferedFromStage = 4, Price = 49, Effect = "One random cosmetic (odds shown)" },
	{ Id = "dp_crate10", Name = "Cosmetic Crate x10", AssetId = 3728676086, OfferedFromStage = 4, Price = 399, Effect = "Ten crates" },
	{ Id = "dp_growth", Name = "Growth Boost", AssetId = 3728676148, OfferedFromStage = 6, Price = 49, DailyCap = 3, Effect = "Crops grow 1.5x faster for 30 minutes" },
	{ Id = "dp_coin_s", Name = "Small Coin Pack", AssetId = 3728676211, OfferedFromStage = 1, Price = 49, DailyCap = 3, Effect = "Coins worth about 12 minutes of play at your level" },
	{ Id = "dp_coin_m", Name = "Medium Coin Pack", AssetId = 3728676264, OfferedFromStage = 1, Price = 99, DailyCap = 2, Effect = "Coins worth about 30 minutes of play at your level" },
	{ Id = "dp_coin_l", Name = "Large Coin Pack", AssetId = 3728676301, OfferedFromStage = 1, Price = 149, DailyCap = 1, Effect = "Coins worth about 1 hour of play at your level" },
	{ Id = "dp_tierskip", Name = "Season Tier Skip", AssetId = 3728676341, OfferedFromStage = 3, Price = 49, Effect = "Skip one tier of the Moon Season" },
	-- These two have their own spots in the store (top and bottom) and stay hidden while AssetId = 0
	{ Id = "dp_starter", Name = "Starter Pack", AssetId = 0, OfferedFromStage = 2, Price = 99, Once = true, Effect = "One time only: 1 hour of coins, 3 crates, a Growth Boost, a Rename Token and the Early Bird title" },
	{ Id = "dp_support", Name = "Support the Developer", AssetId = 0, OfferedFromStage = 1, Price = 49, Effect = "Supporter title. Thank you for helping Moonlit Grove grow!" },
} :: { Product }

Products.PassById = {} :: { [string]: Pass }
for _, pass in Products.Passes do
	Products.PassById[pass.Id] = pass
end

Products.ProductById = {} :: { [string]: Product }
Products.ProductByAssetId = {} :: { [number]: Product }
for _, product in Products.DevProducts do
	Products.ProductById[product.Id] = product
	if product.AssetId ~= 0 then
		Products.ProductByAssetId[product.AssetId] = product
	end
end

-- Garden Club subscription (section 13.3). Paste the subscription id ("EXP-...") to enable it.
Products.Club = {
	SubscriptionId = "EXP-1765176911641838092",
	Name = "Garden Club",
	PriceText = "R$ 199 / month",
	Effect = "Club title, daily gift of 1 cosmetic crate, +30 bag space",
	DailyCrates = 1,
}

-- Starter Pack contents (dp_starter, one per player). Worth about R$ 370 if bought item by item.
Products.StarterPack = {
	CoinMinutes = 60, -- same as a Large Coin Pack
	Crates = 3, -- open as fixed items where paid random items are not allowed
	RenameTokens = 1,
	GrowthBoost = true, -- 30 minutes (Products.GrowthBoost)
	Title = "Early Bird",
}

-- Roblox Premium members get a small bonus here, and Roblox pays the game for their play time
-- (Premium Payouts, automatic). Other players can open Roblox's Premium offer from the store.
Products.Premium = {
	Title = "Premium",
	Effect = "+30 bag space and a Premium title in Moonlit Grove",
}

-- Cosmetic crate pool (odds shown before purchase)
Products.Cosmetics = {
	{ Id = "glow_pink", Name = "Pink Glow", Kind = "Glow", Rarity = "Common", Weight = 30, Color = Color3.fromRGB(255, 150, 210) },
	{ Id = "glow_gold", Name = "Gold Glow", Kind = "Glow", Rarity = "Common", Weight = 30, Color = Color3.fromRGB(255, 210, 90) },
	{ Id = "glow_mint", Name = "Mint Glow", Kind = "Glow", Rarity = "Common", Weight = 25, Color = Color3.fromRGB(120, 255, 190) },
	{ Id = "theme_autumn", Name = "Autumn Garden", Kind = "Theme", Rarity = "Rare", Weight = 8, Color = Color3.fromRGB(200, 120, 50) },
	{ Id = "theme_frost", Name = "Frost Garden", Kind = "Theme", Rarity = "Rare", Weight = 5, Color = Color3.fromRGB(190, 220, 240) },
	{ Id = "title_stargazer", Name = "Stargazer (title)", Kind = "Title", Rarity = "Epic", Weight = 2 },
} :: { Cosmetic }

Products.CosmeticById = {} :: { [string]: Cosmetic }
for _, cosmetic in Products.Cosmetics do
	Products.CosmeticById[cosmetic.Id] = cosmetic
end

-- Cosmetics granted by passes (not in crates)
Products.PassCosmetics = {
	glow_founder = { Id = "glow_founder", Name = "Founder Glow", Kind = "Glow", Rarity = "Epic", Weight = 0, Color = Color3.fromRGB(255, 120, 60) },
	theme_founder = { Id = "theme_founder", Name = "Founder Garden", Kind = "Theme", Rarity = "Epic", Weight = 0, Color = Color3.fromRGB(240, 200, 120) },
}

-- Purchase rules (section 13.4)
Products.NoOffersBeforeStage = 3
Products.CratePityCount = 20 -- a Rare or better cosmetic is guaranteed within 20 crates
Products.GrowthBoost = { Mult = 1.5, DurationSeconds = 1800, Stacks = false }
Products.CoinPackMinutes = { dp_coin_s = 12, dp_coin_m = 30, dp_coin_l = 60 } -- minutes of average earnings
Products.MaxBoostTotal = 0.50 -- boosts never stack past +50%
Products.SpendingReminderAfterPurchases = 5 -- per day

return Products
