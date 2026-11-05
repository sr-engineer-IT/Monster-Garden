--!strict
-- ShopService: player shop stalls (Build Spec sections 6, 15; stage 5). Owners list goods or
-- eligible creatures; listed items move into the stall (escrow, saved in the owner's profile).
-- Visitors buy at the stall while the owner is in the server. Every sale is one server-side step
-- with no yields, so items can never be duplicated. A 5% fee is a coin sink.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Shop = require(ConfigFolder:WaitForChild("Shop"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local S = require(script.Parent.Parent.Registry)
local Build = require(script.Parent.Parent.Build)

local ShopService = {}

local SHOP = Shop.PlayerShop
local stalls: { [Player]: Model } = {}

local function notify(player: Player, text: string)
	Remotes.Get("Notify"):FireClient(player, { Text = text })
end

local function stallPosition(owner: Player): Vector3?
	local plot = S.PlotService.GetPlot(owner)
	return if plot then plot.Center + Config.World.StallOffset else nil
end

local function listingView(listing: any): any
	local name = if listing.Kind == "Creature" then GameMath.CreatureName(listing.Record) else GameMath.GoodsName(listing.Key)
	local info = ""
	if listing.Kind == "Creature" then
		local record = listing.Record
		info = `{record.Sex}, {record.Stage}, Str {record.Traits.Str} Int {record.Traits.Int} End {record.Traits.End}`
		if #record.Mutations > 0 then
			info ..= ", " .. table.concat(record.Mutations, ", ")
		end
	end
	return { Id = listing.Id, Kind = listing.Kind, Name = name, Info = info, Qty = listing.Qty, Price = listing.Price }
end

-- Items the owner could list (for the manage view)
local function listable(data: any): any
	local goods, creatures = {}, {}
	for key, count in data.Inventory.Goods do
		table.insert(goods, { Key = key, Name = GameMath.GoodsName(key), Count = count, Value = GameMath.SellValue(key) })
	end
	for id, creature in data.Creatures do
		if ShopService.CanTradeCreature(data, creature) then
			table.insert(creatures, { Id = id, Name = GameMath.CreatureName(creature), Value = GameMath.CreatureValue(creature) })
		end
	end
	return { Goods = goods, Creatures = creatures }
end

function ShopService.CanTradeCreature(data: any, creature: any): boolean
	if GameMath.IsProtected(creature) or creature.CaptiveAt or creature.InPen or creature.InShelter or (creature.HotUntil or 0) > os.time() then
		return false
	end
	for _, nest in data.Nests do
		if nest.MotherId == creature.Id or nest.FatherId == creature.Id then
			return false
		end
	end
	return true
end

local function sendStall(viewer: Player, owner: Player)
	local data = S.DataService.GetData(owner)
	if not data then
		return
	end
	local listings = {}
	for _, listing in data.ShopListings do
		table.insert(listings, listingView(listing))
	end
	local isOwner = viewer == owner
	Remotes.Get("StallOpen"):FireClient(viewer, {
		OwnerUserId = owner.UserId,
		OwnerName = owner.DisplayName,
		IsOwner = isOwner,
		Listings = listings,
		Listable = if isOwner then listable(data) else nil,
		FeeShare = SHOP.FeeShare,
		MinPriceMult = SHOP.MinPriceMult,
		MaxPriceMult = SHOP.MaxPriceMult,
		MaxListings = SHOP.MaxListings,
	})
end

local function onOpenStall(player: Player, data: any, ownerUserId: any)
	local owner = type(ownerUserId) == "number" and Players:GetPlayerByUserId(ownerUserId)
	if owner then
		sendStall(player, owner)
	end
end

local function priceOk(price: number, value: number): boolean
	return price >= math.max(1, math.floor(value * SHOP.MinPriceMult)) and price <= math.max(1, math.ceil(value * SHOP.MaxPriceMult))
end

local function onList(player: Player, data: any, kind: any, key: any, qty: any, price: any)
	if not data.Unlocks.PlayerShop or not S.AntiExploit.IsString(key, 64) or not S.AntiExploit.IsInteger(price, 1, 10000000) then
		return
	end
	if Util.CountKeys(data.ShopListings) >= SHOP.MaxListings then
		notify(player, `Your stall holds {SHOP.MaxListings} listings.`)
		return
	end
	local listingId = Util.NewId()
	if kind == "Goods" then
		if not S.AntiExploit.IsInteger(qty, 1, 999) or (data.Inventory.Goods[key] or 0) < qty then
			return
		end
		if not priceOk(price, GameMath.SellValue(key)) then
			notify(player, "That price is outside the allowed range for this item.")
			return
		end
		data.Inventory.Goods[key] -= qty
		if data.Inventory.Goods[key] <= 0 then
			data.Inventory.Goods[key] = nil
		end
		data.ShopListings[listingId] = { Id = listingId, Kind = "Goods", Key = key, Qty = qty, Price = price }
	elseif kind == "Creature" then
		local creature = data.Creatures[key]
		if not creature or not ShopService.CanTradeCreature(data, creature) then
			notify(player, "That creature cannot be sold right now.")
			return
		end
		if not priceOk(price, GameMath.CreatureValue(creature)) then
			notify(player, "That price is outside the allowed range for this creature.")
			return
		end
		local record = S.CreatureService.RemoveCreature(player, key)
		data.ShopListings[listingId] = { Id = listingId, Kind = "Creature", Key = key, Qty = 1, Price = price, Record = record }
	else
		return
	end
	notify(player, "Listed in your stall!")
	S.ObjectiveService.Progress(player, "List")
	S.DataService.MarkChanged(player)
	sendStall(player, player)
end

local function returnListing(player: Player, data: any, listing: any)
	if listing.Kind == "Goods" then
		data.Inventory.Goods[listing.Key] = (data.Inventory.Goods[listing.Key] or 0) + listing.Qty
	elseif listing.Record then
		S.CreatureService.AddCreature(player, listing.Record)
	end
end

local function onUnlist(player: Player, data: any, listingId: any)
	local listing = type(listingId) == "string" and data.ShopListings[listingId]
	if not listing then
		return
	end
	data.ShopListings[listingId] = nil
	returnListing(player, data, listing)
	S.DataService.MarkChanged(player)
	sendStall(player, player)
end

local function onBuy(buyer: Player, buyerData: any, ownerUserId: any, listingId: any, qty: any)
	if Config.KillSwitches.PlayerShop or type(ownerUserId) ~= "number" or type(listingId) ~= "string" then
		return
	end
	qty = if qty == nil then 1 else qty
	if not S.AntiExploit.IsInteger(qty, 1, 999) then
		return
	end
	local owner = Players:GetPlayerByUserId(ownerUserId)
	local ownerData = owner and S.DataService.GetData(owner)
	local listing = ownerData and ownerData.ShopListings[listingId]
	local stall = owner and stallPosition(owner)
	if not owner or owner == buyer or not ownerData or not listing or not stall then
		return
	end
	if not S.AntiExploit.WithinDistance(buyer, stall, Config.Distance.Merchant) then
		notify(buyer, "Walk up to the stall first.")
		return
	end
	qty = math.min(qty, listing.Qty)
	local total = listing.Price * qty
	if buyerData.Coins < total then
		notify(buyer, `You need {total} coins.`)
		return
	end
	if listing.Kind == "Goods" and GameMath.GoodsCount(buyerData) + qty > GameMath.InventoryCapacity(buyerData) then
		notify(buyer, "Your bag is too full.")
		return
	end
	if listing.Kind == "Creature" and S.CreatureService.CountAll(buyerData) >= Config.MaxCreatures then
		notify(buyer, "Your garden is full.")
		return
	end

	-- Atomic transfer (no yields from here)
	buyerData.Coins -= total
	ownerData.Coins += math.floor(total * (1 - SHOP.FeeShare))
	listing.Qty -= qty
	if listing.Qty <= 0 then
		ownerData.ShopListings[listingId] = nil
	end
	if listing.Kind == "Goods" then
		buyerData.Inventory.Goods[listing.Key] = (buyerData.Inventory.Goods[listing.Key] or 0) + qty
	else
		local record = listing.Record
		record.InPen, record.InShelter = nil, nil
		S.CreatureService.AddCreature(buyer, record)
	end
	notify(buyer, `Bought for {total} coins!`)
	notify(owner, `{buyer.DisplayName} bought from your stall: +{math.floor(total * (1 - SHOP.FeeShare))} coins`)
	S.DataService.MarkChanged(buyer)
	S.DataService.MarkChanged(owner)
	sendStall(buyer, owner)
end

local function buildStall(owner: Player)
	local plot = S.PlotService.GetPlot(owner)
	local data = S.DataService.GetData(owner)
	if not plot or not data or stalls[owner] or not data.Unlocks.PlayerShop then
		return
	end
	local base = plot.Center + Config.World.StallOffset
	local golden = data.Purchases.PassesOwned.pass_shoptheme
	local model = Instance.new("Model")
	model.Name = "ShopStall"
	local counter = Build.Part({ Size = Vector3.new(6, 3, 3), Position = base + Vector3.new(0, 1.5, 0), Color = if golden then Color3.fromRGB(230, 190, 80) else Color3.fromRGB(160, 120, 80), Material = Enum.Material.WoodPlanks, CanCollide = true, Parent = model })
	Build.Part({ Size = Vector3.new(7, 0.4, 4), Position = base + Vector3.new(0, 5.5, 0), Color = if golden then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(90, 160, 220), Parent = model })
	local gui = Build.Billboard(counter, 220, 36, 5)
	gui.MaxDistance = 120
	Build.Label(gui, `{owner.DisplayName}'s Shop`, { TextColor3 = Color3.fromRGB(150, 220, 255) })
	local prompt = Build.Prompt(counter, "Shop Stall", owner.DisplayName, { Distance = 12 })
	prompt:SetAttribute("Public", true)
	prompt.Triggered:Connect(function(viewer)
		sendStall(viewer, owner)
	end)
	model.Parent = plot.Folders.Buildings
	stalls[owner] = model
end

function ShopService.Init() end

function ShopService.Start()
	S.AntiExploit.Bind("OpenStall", onOpenStall)
	S.AntiExploit.Bind("ListShopItem", onList, { KillSwitch = "PlayerShop" })
	S.AntiExploit.Bind("UnlistShopItem", onUnlist)
	S.AntiExploit.Bind("BuyShopItem", onBuy, { KillSwitch = "PlayerShop" })
	Players.PlayerRemoving:Connect(function(player)
		stalls[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				buildStall(player)
			end
		end
	end)
end

return ShopService
