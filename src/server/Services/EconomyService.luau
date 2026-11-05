--!strict
-- EconomyService: Coins and Monster Essence, the merchant cart (buy seeds, eggs, plot and soil
-- upgrades; sell goods) and the daily login gift (Build Spec section 6).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Crops = require(ConfigFolder:WaitForChild("Crops"))
local Creatures = require(ConfigFolder:WaitForChild("Creatures"))
local Shop = require(ConfigFolder:WaitForChild("Shop"))
local Stages = require(ConfigFolder:WaitForChild("Stages"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local S = require(script.Parent.Parent.Registry)

export type Cost = { Coins: number?, Essence: number? }

local EconomyService = {}

local function notify(player: Player, text: string)
	Remotes.Get("Notify"):FireClient(player, { Text = text })
end

-- Currency -----------------------------------------------------------------------------------

function EconomyService.CanAfford(data: any, cost: Cost): boolean
	return data.Coins >= (cost.Coins or 0) and data.Essence >= (cost.Essence or 0)
end

function EconomyService.CostText(cost: Cost): string
	local parts = {}
	if cost.Coins and cost.Coins > 0 then
		table.insert(parts, `{cost.Coins} coins`)
	end
	if cost.Essence and cost.Essence > 0 then
		table.insert(parts, `{cost.Essence} Essence`)
	end
	return if #parts > 0 then table.concat(parts, " + ") else "free"
end

-- Takes the cost if affordable; tells the player when it is not
function EconomyService.Spend(player: Player, cost: Cost): boolean
	local data = S.DataService.GetData(player)
	if not data then
		return false
	end
	if not EconomyService.CanAfford(data, cost) then
		notify(player, `You need {EconomyService.CostText(cost)}.`)
		return false
	end
	data.Coins -= cost.Coins or 0
	data.Essence -= cost.Essence or 0
	S.DataService.MarkChanged(player)
	return true
end

function EconomyService.AddCoins(player: Player, amount: number)
	local data = S.DataService.GetData(player)
	if data and amount > 0 then
		data.Coins += math.floor(amount)
		S.DataService.MarkChanged(player)
	end
end

function EconomyService.AddEssence(player: Player, amount: number)
	local data = S.DataService.GetData(player)
	if data and amount > 0 and data.Unlocks.Essence then
		data.Essence += math.floor(amount)
		S.DataService.MarkChanged(player)
	end
end

-- Merchant --------------------------------------------------------------------------------------

-- Rare slots: each restock, each of Shop.RareSlots rolls RareRestockChance for a rare item
local rareStock: { number } = {} -- indexes into Shop.RarePool
local rareRestockAt = 0

local function rarePrice(entry: any): number
	if entry.Price then
		return entry.Price
	end
	local crop = Crops.ById[entry.Id]
	return if crop then crop.SeedCost else 1000
end

local function rareStage(entry: any): number
	if entry.Kind == "Seed" then
		return Crops.ById[entry.Id].Stage
	end
	return Creatures.ById[entry.Id].Stage
end

local function restock()
	table.clear(rareStock)
	local weights: { [number]: number } = {}
	for index, entry in Shop.RarePool do
		weights[index] = entry.Weight
	end
	for _ = 1, Shop.RareSlots do
		if Util.Chance(Config.RareRestockChance) then
			table.insert(rareStock, Util.WeightedPick(weights) :: number)
		end
	end
	rareRestockAt = os.time() + Config.MerchantRestockSeconds
end

local function stageLockText(stageId: number): string
	local stage = Stages.Get(stageId)
	if stage.Trigger.Level then
		return `Level {stage.Trigger.Level}`
	elseif stage.Trigger.NightsSurvived then
		return "Survive a night"
	end
	return stage.Name
end

local function cropLockText(crop: Crops.Crop, data: any): string?
	if data.Stage < crop.Stage then
		return stageLockText(crop.Stage)
	elseif data.GardenLevel < (crop.MinLevel or 1) then
		return `Level {crop.MinLevel}`
	end
	return nil
end

local function buildOffers(player: Player, data: any): any
	local offers = { Seeds = {}, Eggs = {}, Upgrades = {}, SellTotal = 0, SellCount = 0 }

	for _, crop in Crops.List do
		if crop.Stage <= Config.MaxStageEnabled and not crop.Rare then
			local harvests = if crop.Harvests > 1 then ", " .. crop.Harvests .. " harvests" else ""
			table.insert(offers.Seeds, {
				Id = "seed:" .. crop.Id,
				Name = `{crop.Name} seed`,
				Info = `Grows {crop.GrowSeconds}s, sells {crop.Sell}{harvests}`,
				Price = crop.SeedCost,
				Owned = data.Inventory.Seeds[crop.Id] or 0,
				Locked = cropLockText(crop, data),
			})
		end
	end

	for _, speciesId in Shop.CommonEggs do
		local species = Creatures.ById[speciesId]
		if species and species.EggCost and species.Stage <= Config.MaxStageEnabled then
			local locked = if data.Stage < math.max(species.Stage, Stages.FeatureStage.Eggs) then stageLockText(math.max(species.Stage, Stages.FeatureStage.Eggs)) else nil
			table.insert(offers.Eggs, {
				Id = "egg:" .. species.Id,
				Name = `{species.Name} egg`,
				Info = if species.Goods then `Makes {species.Goods.Name} (sells {species.Goods.Sell})` else "Companion",
				Price = species.EggCost,
				Locked = locked,
			})
		end
	end

	local nextSize = Config.PlotSizes[data.Plot.SizeIndex + 1]
	if nextSize then
		table.insert(offers.Upgrades, {
			Id = "expand",
			Name = `Bigger plot ({nextSize.Width}x{nextSize.Depth})`,
			Info = `{nextSize.Width * nextSize.Depth} farm tiles`,
			Price = nextSize.Cost,
			Locked = if data.GardenLevel < nextSize.Level then `Level {nextSize.Level}` else nil,
		})
	end
	local nextSoil = data.Plot.SoilLevel + 1
	if Crops.SoilUpgradeCost[nextSoil] then
		table.insert(offers.Upgrades, {
			Id = "soil",
			Name = `Soil level {nextSoil}`,
			Info = `Crops grow {math.floor((1 - Crops.SoilMultiplier[nextSoil]) * 100 + 0.5)}% faster`,
			Price = Crops.SoilUpgradeCost[nextSoil],
			Locked = if data.Unlocks.SoilUpgrade then nil else stageLockText(Stages.FeatureStage.SoilUpgrade),
		})
	end

	-- Rare restock (shared by the whole server, section 6)
	offers.Rare = {}
	offers.RestockAt = rareRestockAt
	for index, slot in rareStock do
		local entry = Shop.RarePool[slot]
		local price = rarePrice(entry)
		local stageNeeded = rareStage(entry)
		table.insert(offers.Rare, {
			Id = "rare:" .. index,
			Name = if entry.Kind == "Seed" then `{Crops.ById[entry.Id].Name} seed` else `{Creatures.ById[entry.Id].Name} egg`,
			Info = "Rare restock",
			Price = price,
			Locked = if data.Stage < stageNeeded then stageLockText(stageNeeded) else nil,
		})
	end

	offers.Capacity = GameMath.InventoryCapacity(data)
	offers.BagCount = GameMath.GoodsCount(data)
	for key, count in data.Inventory.Goods do
		offers.SellTotal += GameMath.SellValue(key) * count
		offers.SellCount += count
	end
	return offers
end

function EconomyService.OpenMerchant(player: Player)
	local data = S.DataService.GetData(player)
	if data then
		Remotes.Get("MerchantOpen"):FireClient(player, buildOffers(player, data))
	end
end

local function nearMerchant(player: Player): boolean
	local plot = S.PlotService.GetPlot(player)
	if plot and S.AntiExploit.WithinDistance(player, plot.Center + Config.World.MerchantOffset, Config.Distance.Merchant) then
		return true
	end
	-- Town Square shops work too
	for _, shop in Config.World.TownShops do
		if S.AntiExploit.WithinDistance(player, shop.Offset, Config.Distance.Merchant + 6) then
			return true
		end
	end
	notify(player, "Walk to your merchant cart or a Town Square shop first.")
	return false
end

local function buySeed(player: Player, data: any, cropId: string, qty: number): boolean
	local crop = Crops.ById[cropId]
	if not crop or crop.Rare or not GameMath.IsCropAvailable(crop, data.Stage, data.GardenLevel) then
		return false
	end
	if not EconomyService.Spend(player, { Coins = crop.SeedCost * qty }) then
		return false
	end
	data.Inventory.Seeds[cropId] = (data.Inventory.Seeds[cropId] or 0) + qty
	notify(player, `Bought {qty} {crop.Name} seed{if qty > 1 then "s" else ""}`)
	S.ObjectiveService.Progress(player, "BuySeed")
	S.CropService.RefreshAll(player)
	return true
end

local function buyEgg(player: Player, data: any, speciesId: string): boolean
	local species = Creatures.ById[speciesId]
	if not species or not species.EggCost or not table.find(Shop.CommonEggs, speciesId) then
		return false
	end
	if not data.Unlocks.Eggs or data.Stage < species.Stage then
		return false
	end
	if S.CreatureService.CountAll(data) >= Config.MaxCreatures then
		notify(player, `Your garden is full ({Config.MaxCreatures} creatures).`)
		return false
	end
	if not EconomyService.Spend(player, { Coins = species.EggCost }) then
		return false
	end
	S.CreatureService.GiveEgg(player, speciesId, Shop.EggHatchSeconds)
	notify(player, `{species.Name} egg bought! It hatches in {Shop.EggHatchSeconds}s.`)
	S.ObjectiveService.Progress(player, "BuyEgg")
	return true
end

local function expandPlot(player: Player, data: any): boolean
	local nextSize = S.PlotService.GetNextExpansion(data)
	if not nextSize or not EconomyService.Spend(player, { Coins = nextSize.Cost }) then
		return false
	end
	data.Plot.SizeIndex += 1
	S.PlotService.BuildTiles(player)
	notify(player, `Your plot is now {nextSize.Width}x{nextSize.Depth}!`)
	S.ObjectiveService.Progress(player, "Expand")
	return true
end

local function upgradeSoil(player: Player, data: any): boolean
	local nextSoil = data.Plot.SoilLevel + 1
	local cost = Crops.SoilUpgradeCost[nextSoil]
	if not data.Unlocks.SoilUpgrade or not cost or not EconomyService.Spend(player, { Coins = cost }) then
		return false
	end
	data.Plot.SoilLevel = nextSoil
	notify(player, `Soil upgraded to level {nextSoil}!`)
	S.ObjectiveService.Progress(player, "Soil")
	S.CropService.RefreshAll(player)
	return true
end

local function onBuyItem(player: Player, data: any, itemId: any, qty: any)
	if not S.AntiExploit.IsString(itemId, 40) then
		return
	end
	qty = if qty == nil then 1 else qty
	if not S.AntiExploit.IsInteger(qty, 1, Shop.MaxBuyQuantity) then
		return
	end
	if not nearMerchant(player) then
		return
	end

	local kind, id = string.match(itemId, "^(%a+):([%w_]+)$")
	if kind == "rare" and id then
		local slot = rareStock[tonumber(id) or 0]
		local entry = slot and Shop.RarePool[slot]
		if entry and data.Stage >= rareStage(entry) then
			if entry.Kind == "Seed" then
				if EconomyService.Spend(player, { Coins = rarePrice(entry) }) then
					data.Inventory.Seeds[entry.Id] = (data.Inventory.Seeds[entry.Id] or 0) + 1
					notify(player, `Bought a rare {Crops.ById[entry.Id].Name} seed!`)
					S.CropService.RefreshAll(player)
				end
			elseif S.CreatureService.CountAll(data) < Config.MaxCreatures and EconomyService.Spend(player, { Coins = rarePrice(entry) }) then
				S.CreatureService.GiveEgg(player, entry.Id, Shop.EggHatchSeconds)
				notify(player, `Bought a rare {Creatures.ById[entry.Id].Name} egg!`)
			end
		end
	elseif kind == "seed" and id then
		buySeed(player, data, id, qty)
	elseif kind == "egg" and id then
		buyEgg(player, data, id)
	elseif itemId == "expand" then
		expandPlot(player, data)
	elseif itemId == "soil" then
		upgradeSoil(player, data)
	end
	S.DataService.MarkChanged(player)
	EconomyService.OpenMerchant(player)
end

local function onSellItems(player: Player, data: any)
	if not nearMerchant(player) then
		return
	end
	local total = 0
	for key, count in data.Inventory.Goods do
		total += GameMath.SellValue(key) * count
	end
	if total <= 0 then
		notify(player, "Nothing to sell yet. Harvest some crops!")
		return
	end
	-- Heist Flag bonus: +20% coins on goods sold while Heist Night runs
	if data.HeistFlag and S.HeistService.IsActive() then
		total = math.floor(total * (1 + Config.Heist.FlagGoodsCoinBonus))
	end
	table.clear(data.Inventory.Goods)
	data.Coins += total
	notify(player, `Sold for {total} coins!`)
	S.ProgressionService.AddXP(player, total // Config.XPSources.CoinsPerSellXP, "Sell")
	S.ObjectiveService.Progress(player, "Sell")
	S.DataService.MarkChanged(player)
	EconomyService.OpenMerchant(player)
end

local function giveDailyGift(player: Player, data: any)
	local today = Util.DayNumber()
	if data.LastLoginDay == today then
		return
	end
	data.LastLoginDay = today
	local gift = Config.DailyLoginGift
	local coins = math.min(math.floor(gift.BaseCoins * (1 + data.GardenLevel / gift.LevelDivisor)), Config.MaxDailyLoginGiftCoins)
	data.Coins += coins
	S.DataService.MarkChanged(player)
	task.delay(4, function()
		if player.Parent then
			notify(player, `Daily gift: +{coins} coins!`)
		end
	end)
end

function EconomyService.Init() end

function EconomyService.Start()
	restock()
	task.spawn(function()
		while true do
			task.wait(Config.MerchantRestockSeconds)
			restock()
		end
	end)
	S.AntiExploit.Bind("BuyItem", onBuyItem)
	S.AntiExploit.Bind("SellItems", onSellItems)
	S.DataService.ProfileLoaded:Connect(giveDailyGift)
end

return EconomyService
