--!strict
-- Store (Robux), Moon Season and Style panels (Build Spec section 13). Prices are always shown,
-- crate odds are shown before buying, Roblox's own purchase prompt is the confirmation, and
-- nothing here is pushed at the player: the store is only opened from the menu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Products = require(ConfigFolder:WaitForChild("Products"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Util = require(Shared:WaitForChild("Util"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("UI"):WaitForChild("Kit"))
local DataController = require(Client:WaitForChild("Controllers"):WaitForChild("DataController"))
local PanelController = require(Client:WaitForChild("Controllers"):WaitForChild("PanelController"))

local C = Kit.Colors

local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local StorePanel = {}

-- Live prices: asked from Roblox for this player (so a price changed on the Creator Dashboard,
-- or a regional price, shows correctly). Until the answer comes, the price in Products is shown.
local livePrices: { [string]: number } = {}

local function price(item: any): number
	return livePrices[item.Id] or item.Price
end

local function fetchPrices()
	local function fetch(item: any, infoType: Enum.InfoType)
		if item.AssetId == 0 then
			return
		end
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, item.AssetId, infoType)
		if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
			livePrices[item.Id] = info.PriceInRobux
			if RunService:IsStudio() and info.PriceInRobux ~= item.Price then
				warn(`[Store] {item.Name}: Roblox price is R$ {info.PriceInRobux}, Products.luau says R$ {item.Price}. The store shows the Roblox price; update Products.luau to match.`)
			end
		end
		task.wait(0.2)
	end
	for _, pass in Products.Passes do
		fetch(pass, Enum.InfoType.GamePass)
	end
	for _, product in Products.DevProducts do
		fetch(product, Enum.InfoType.Product)
	end
end

local starterProduct = Products.ProductById.dp_starter
local supportProduct = Products.ProductById.dp_support

-- The Starter Pack card shows at the top of the store until it is bought
local function starterOffered(data: any): boolean
	return starterProduct ~= nil
		and starterProduct.AssetId ~= 0
		and data.Stage >= starterProduct.OfferedFromStage
		and not data.Purchases.PassesOwned[starterProduct.Id]
end

-- Number on the Store menu button: crates to open, plus 1 while the Starter Pack is on offer
function StorePanel.Badge(data: any): number
	return (data.Inventory.Items.crate or 0) + (if starterOffered(data) then 1 else 0)
end

local function itemRow(list: Instance, order: number, name: string, info: string, buttonText: string, enabled: boolean, onClick: () -> ())
	local row = Kit.Row(list, order, 68)
	Kit.Label({ Text = name, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -110, 0, 22), ZIndex = 23, Parent = row })
	Kit.Label({ Text = info, TextSize = 13, Font = Enum.Font.Gotham, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, -110, 0, 30), ZIndex = 23, Parent = row })
	Kit.RowButton(row, 1, buttonText, if enabled then C.Good else C.Locked, if enabled then onClick else function() end, 100)
end

local function totalWeight(): number
	local total = 0
	for _, cosmetic in Products.Cosmetics do
		total += cosmetic.Weight
	end
	return total
end

function StorePanel.Open()
	local data = DataController.Get()
	if not data then
		return
	end
	local list = PanelController.Open("Store", "Store")
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	Kit.Label({ Text = "You can play the whole game for free. The store sells looks and time-savers.", TextSize = 14, TextColor3 = C.Muted, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), ZIndex = 22, Parent = list })

	-- Players in countries where paid random items are not allowed see no crates or odds
	local noRandom = Players.LocalPlayer:GetAttribute("NoPaidRandom") == true

	-- Starter Pack: best value, one time only
	if starterOffered(data) then
		local pack = Products.StarterPack
		Kit.Heading(list, "⭐ Starter Pack: one time only", nextOrder())
		local crates = if noRandom then `{pack.Crates} cosmetics` else `{pack.Crates} cosmetic crates`
		local info = `+{Util.FormatNumber(GameMath.CoinPackAmount(pack.CoinMinutes, data.GardenLevel))} coins, {crates}, 30 min Growth Boost, Rename Token, "{pack.Title}" title`
		itemRow(list, nextOrder(), `Starter Pack  (best value)`, info, `R$ {price(starterProduct)}`, true, function()
			Remotes.Get("PurchaseRequest"):FireServer(starterProduct.Id)
		end)
	end
	if (data.Inventory.Items.crate or 0) > 0 then
		local info = if noRandom then "Gives the next cosmetic you don't have yet" else "Earned from the Moon Season"
		itemRow(list, nextOrder(), `Open a crate ({data.Inventory.Items.crate} left)`, info, "Open", true, function()
			Remotes.Get("PurchaseRequest"):FireServer("open_crate")
		end)
	end

	-- Coin packs first: the exact amount for your level and how many are left today
	Kit.Heading(list, `{Kit.Icons.Coins} Coins`, nextOrder())
	local today = Util.DayNumber()
	for _, product in Products.DevProducts do
		local minutes = (Products.CoinPackMinutes :: any)[product.Id]
		if minutes then
			local amount = GameMath.CoinPackAmount(minutes, data.GardenLevel)
			local cap = (data.Purchases.DailyCaps or {})[product.Id]
			local used = if cap and cap.Day == today then cap.Count else 0
			local left = (product.DailyCap or 99) - used
			local soon = product.AssetId == 0
			local text = if soon then "Soon" elseif left <= 0 then "Tomorrow" else `R$ {price(product)}`
			local info = if left <= 0 then "Daily limit reached, come back tomorrow" else `{left} left today · grows with your level`
			itemRow(list, nextOrder(), `+{Util.FormatNumber(amount)} coins  ({product.Name})`, info, text, not soon and left > 0, function()
				Remotes.Get("PurchaseRequest"):FireServer(product.Id)
			end)
		end
	end

	Kit.Heading(list, "Passes", nextOrder())
	for _, pass in Products.Passes do
		local owned = data.Purchases.PassesOwned[pass.Id] == true
		local soon = pass.AssetId == 0
		local locked = data.Stage < pass.OfferedFromStage
		local text = if owned then "Owned" elseif soon then "Soon" elseif locked then "Locked" else `R$ {price(pass)}`
		itemRow(list, nextOrder(), pass.Name, pass.Effect, text, not owned and not soon and not locked, function()
			Remotes.Get("PurchaseRequest"):FireServer(pass.Id)
		end)
	end

	Kit.Heading(list, "Items", nextOrder())
	for _, product in Products.DevProducts do
		local crate = product.Id == "dp_crate1" or product.Id == "dp_crate10"
		local coinPack = (Products.CoinPackMinutes :: any)[product.Id] ~= nil -- shown in Coins above
		local ownSpot = product == starterProduct or product == supportProduct -- shown at the top / bottom
		if not (crate and noRandom) and not coinPack and not ownSpot then
			local soon = product.AssetId == 0
			local locked = data.Stage < product.OfferedFromStage
			local cap = if product.DailyCap then ` (max {product.DailyCap} per day)` else ""
			local text = if soon then "Soon" elseif locked then "Locked" else `R$ {price(product)}`
			itemRow(list, nextOrder(), product.Name, product.Effect .. cap, text, not soon and not locked, function()
				Remotes.Get("PurchaseRequest"):FireServer(product.Id)
			end)
		end
	end

	if not noRandom then
		Kit.Heading(list, "Crate odds", nextOrder())
		local total = totalWeight()
		for _, cosmetic in Products.Cosmetics do
			Kit.Label({ Text = `{cosmetic.Name} ({cosmetic.Rarity}): {string.format("%.1f", cosmetic.Weight / total * 100)}%`, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nextOrder(), ZIndex = 22, Parent = list })
		end
		Kit.Label({ Text = `A Rare or better cosmetic is guaranteed within {Products.CratePityCount} crates (you are at {data.CratePity}).`, TextSize = 13, TextColor3 = C.Muted, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), ZIndex = 22, Parent = list })
	end

	-- Garden Club (subscription) only shows once it exists: set Products.Club.SubscriptionId
	local club = data.Purchases.PassesOwned.club == true
	if Products.Club.SubscriptionId ~= "" or club then
		Kit.Heading(list, Products.Club.Name, nextOrder())
		itemRow(list, nextOrder(), Products.Club.Name, Products.Club.Effect, if club then "Member" else Products.Club.PriceText, not club, function()
			Remotes.Get("PurchaseRequest"):FireServer("club")
		end)
	end

	-- Roblox Premium: members get a bonus here; others can open Roblox's own Premium offer
	Kit.Heading(list, `{Kit.Icons.Crown} Roblox Premium`, nextOrder())
	local premium = Players.LocalPlayer.MembershipType == Enum.MembershipType.Premium
	itemRow(list, nextOrder(), if premium then "Premium bonus active" else "Roblox Premium bonus", Products.Premium.Effect, if premium then "Active" else "Get", not premium, function()
		Remotes.Get("PurchaseRequest"):FireServer("premium")
	end)

	-- Support the developer (can be bought any number of times)
	if supportProduct and supportProduct.AssetId ~= 0 then
		Kit.Heading(list, "❤ Support", nextOrder())
		local supporter = data.Titles.Supporter == true
		itemRow(list, nextOrder(), supportProduct.Name, if supporter then "Thank you, Supporter! You can tip again any time." else supportProduct.Effect, `R$ {price(supportProduct)}`, true, function()
			Remotes.Get("PurchaseRequest"):FireServer(supportProduct.Id)
		end)
	end
end

-- One reward cell (Free or Premium) inside a tier row
local function seasonCell(row: Frame, xScale: number, reward: any, isPremium: boolean, state: string, onClaim: () -> ())
	local accent = if isPremium then C.Premium else C.Good
	local cell = Kit.New("Frame", {
		Position = UDim2.new(xScale, if xScale == 0 then 52 else 4, 0, 0),
		Size = UDim2.new(0.5, if xScale == 0 then -56 else -4, 1, 0),
		BackgroundColor3 = if state == "Claim" then accent:Lerp(C.Panel, 0.4) else C.Panel,
		BackgroundTransparency = 0.15,
		ZIndex = 23,
		Parent = row,
	}, { Kit.Corner(12), Kit.Stroke(if state == "Claim" then C.Coins else C.Stroke, if state == "Claim" then 3 else 2) })
	Kit.Label({
		Text = reward.Text,
		Font = Kit.Fonts.Bold,
		TextSize = 13,
		TextColor3 = if state == "Locked" or state == "NeedPass" then C.Muted else C.Text,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(8, 5),
		Size = UDim2.new(1, -16, 0, 30),
		ZIndex = 24,
		Parent = cell,
	})
	local bottom = { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(1, -12, 0, 26), ZIndex = 24, Parent = cell }
	if state == "Claim" then
		local props: { [string]: any } = { Text = "Claim", TextSize = 15, BackgroundColor3 = accent }
		for key, value in bottom do
			props[key] = value
		end
		Kit.Button(props, onClaim)
	else
		local text = if state == "Claimed" then `{Kit.Icons.Check} Claimed` elseif state == "NeedPass" then `{Kit.Icons.Crown} Premium` else `{Kit.Icons.Lock} Locked`
		local props: { [string]: any } = { Text = text, TextSize = 13, BackgroundColor3 = C.Locked, TextColor3 = if state == "Claimed" then C.Good else C.Muted }
		for key, value in bottom do
			props[key] = value
		end
		Kit.Chip(props)
	end
end

function StorePanel.OpenSeason()
	local data = DataController.Get()
	if not data then
		return
	end
	local fresh = not PanelController.IsOpen("Season")
	local season = Config.Season
	local tier = data.Season.XP // season.XPPerTier
	local maxed = tier >= season.Tiers
	local list = PanelController.Open("Season", `{Kit.Icons.Season} {season.Name}`)
	local premium = data.Purchases.PassesOwned.pass_season == true

	-- Progress header
	local head = Kit.Row(list, 1, 96)
	Kit.Label({ Text = `Tier {tier}`, Font = Kit.Fonts.Title, TextSize = 30, TextColor3 = C.Coins, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.5, 0, 0, 34), ZIndex = 23, Parent = head })
	Kit.Label({ Text = `of {season.Tiers}`, Font = Kit.Fonts.Body, TextSize = 15, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.5, 0, 0, 34), ZIndex = 23, Parent = head })
	local _, fill = Kit.Bar({ Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 14), ZIndex = 23, Parent = head }, C.Coins)
	local into = data.Season.XP % season.XPPerTier
	Kit.SetBar(fill, if maxed then 1 else into / season.XPPerTier)
	Kit.Label({
		Text = if maxed then "Season complete! Thanks for playing." else `{into}/{season.XPPerTier} XP to Tier {tier + 1}  ·  earn XP from nights, harvests and battles`,
		Font = Kit.Fonts.Body,
		TextSize = 13,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 0, 20),
		ZIndex = 23,
		Parent = head,
	})

	-- Premium strip and Claim all
	local claimable = 0
	for t = 1, math.min(tier, season.Tiers) do
		if not data.Season.Claimed[`{t}:f`] then
			claimable += 1
		end
		if premium and not data.Season.Claimed[`{t}:p`] then
			claimable += 1
		end
	end
	local strip = Kit.New("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 22, Parent = list })
	local seasonPass: any = nil
	for _, pass in Products.Passes do
		if pass.Id == "pass_season" then
			seasonPass = pass
		end
	end
	local half = UDim2.new(0.5, -4, 1, 0)
	if premium then
		Kit.Chip({ Text = `{Kit.Icons.Crown} Premium active`, TextSize = 16, Size = half, BackgroundColor3 = C.Premium, ZIndex = 23, Parent = strip })
	else
		local soon = seasonPass == nil or seasonPass.AssetId == 0
		Kit.Button({ Text = if soon then `{Kit.Icons.Crown} Premium soon` else `{Kit.Icons.Crown} Premium  R$ {price(seasonPass)}`, TextSize = 16, Size = half, BackgroundColor3 = if soon then C.Locked else C.Premium, ZIndex = 23, Parent = strip }, function()
			if not soon then
				Remotes.Get("PurchaseRequest"):FireServer("pass_season")
			end
		end)
	end
	Kit.Button({ Text = if claimable > 0 then `Claim all ({claimable})` else "Nothing to claim", TextSize = 16, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = half, BackgroundColor3 = if claimable > 0 then C.Good else C.Locked, ZIndex = 23, Parent = strip }, function()
		if claimable > 0 then
			Remotes.Get("SeasonClaim"):FireServer(0, false)
		end
	end)

	-- Column titles
	local titles = Kit.New("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 3, ZIndex = 22, Parent = list })
	Kit.Label({ Text = "Free", Font = Kit.Fonts.Title, TextSize = 16, TextColor3 = C.Good, Position = UDim2.fromOffset(60, 0), Size = UDim2.new(0.5, -56, 1, 0), ZIndex = 23, Parent = titles })
	Kit.Label({ Text = `{Kit.Icons.Crown} Premium`, Font = Kit.Fonts.Title, TextSize = 16, TextColor3 = C.Premium, Position = UDim2.new(0.5, 8, 0, 0), Size = UDim2.new(0.5, -8, 1, 0), ZIndex = 23, Parent = titles })

	local currentRow: Frame? = nil
	for t = 1, season.Tiers do
		local reached = t <= tier
		local row = Kit.Row(list, 10 + t, 80)
		if t == tier + 1 then
			currentRow = row
			local stroke = row:FindFirstChildOfClass("UIStroke") :: UIStroke
			stroke.Color = C.Coins
			stroke.Transparency = 0
			stroke.Thickness = 2
		end
		local badge = Kit.Label({
			Text = tostring(t),
			Font = Kit.Fonts.Title,
			TextSize = 18,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(42, 42),
			BackgroundTransparency = 0,
			BackgroundColor3 = if reached then C.Accent else C.Locked,
			TextColor3 = C.Text,
			ZIndex = 23,
			Parent = row,
		})
		Kit.Corner(21).Parent = badge
		Kit.Stroke(C.Stroke, 2.5).Parent = badge

		local freeState = if data.Season.Claimed[`{t}:f`] then "Claimed" elseif reached then "Claim" else "Locked"
		local paidState = if data.Season.Claimed[`{t}:p`] then "Claimed" elseif not premium then "NeedPass" elseif reached then "Claim" else "Locked"
		seasonCell(row, 0, GameMath.SeasonReward(t, false), false, freeState, function()
			Remotes.Get("SeasonClaim"):FireServer(t, false)
		end)
		seasonCell(row, 0.5, GameMath.SeasonReward(t, true), true, paidState, function()
			Remotes.Get("SeasonClaim"):FireServer(t, true)
		end)
	end

	-- On a fresh open, scroll so the next tier is in view
	if fresh and currentRow then
		local target = currentRow
		task.defer(function()
			task.wait()
			if target.Parent then
				local offset = target.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y - 140
				list.CanvasPosition = Vector2.new(0, math.max(0, offset))
			end
		end)
	end
end

function StorePanel.OpenStyle()
	local data = DataController.Get()
	if not data then
		return
	end
	local list = PanelController.Open("Style", "Style")
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local function cosmeticName(id: string): (string, string?)
		local cosmetic = Products.CosmeticById[id] or (Products.PassCosmetics :: any)[id]
		return if cosmetic then cosmetic.Name else id, if cosmetic then cosmetic.Kind else nil
	end
	for _, kind in { "Glow", "Theme" } do
		Kit.Heading(list, if kind == "Glow" then "Creature glows" else "Garden themes", nextOrder())
		local any = false
		for id in data.Inventory.Cosmetics do
			local name, cosmeticKind = cosmeticName(id)
			if cosmeticKind == kind then
				any = true
				local equipped = data.Equipped[kind] == id
				local row = Kit.Row(list, nextOrder(), 52)
				Kit.Label({ Text = name, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -100, 1, 0), ZIndex = 23, Parent = row })
				Kit.RowButton(row, 1, if equipped then "Remove" else "Equip", if equipped then C.PanelLight else C.Good, function()
					Remotes.Get("EquipCosmetic"):FireServer(kind, if equipped then nil else id)
				end, 90)
			end
		end
		if not any then
			Kit.Label({ Text = "None yet: earn them from the Moon Season or crates.", TextSize = 14, TextColor3 = C.Muted, LayoutOrder = nextOrder(), ZIndex = 22, Parent = list })
		end
	end
	Kit.Heading(list, "Titles", nextOrder())
	for title in data.Titles do
		local equipped = data.Equipped.Title == title
		local row = Kit.Row(list, nextOrder(), 52)
		Kit.Label({ Text = title, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -100, 1, 0), ZIndex = 23, Parent = row })
		Kit.RowButton(row, 1, if equipped then "Remove" else "Wear", if equipped then C.PanelLight else C.Good, function()
			Remotes.Get("EquipCosmetic"):FireServer("Title", if equipped then nil else title)
		end, 90)
	end
end

function StorePanel.Start()
	task.spawn(function()
		fetchPrices()
		PanelController.Refresh("Store", StorePanel.Open)
		PanelController.Refresh("Season", StorePanel.OpenSeason)
	end)
	Players.LocalPlayer:GetPropertyChangedSignal("MembershipType"):Connect(function()
		PanelController.Refresh("Store", StorePanel.Open)
	end)
	local last = 0
	DataController.Changed:Connect(function()
		if os.clock() - last < 1 then
			return
		end
		last = os.clock()
		PanelController.Refresh("Store", StorePanel.Open)
		PanelController.Refresh("Season", StorePanel.OpenSeason)
		PanelController.Refresh("Style", StorePanel.OpenStyle)
	end)
end

return StorePanel
