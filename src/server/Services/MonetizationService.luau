--!strict
-- MonetizationService: game passes, developer products, Garden Club, cosmetic crates and equipping
-- cosmetics (Build Spec section 13). Looks, convenience and capped time-savers only.
-- ProcessReceipt is idempotent: each PurchaseId is stored in the profile and never granted twice;
-- NotProcessedYet is returned while the buyer's profile is not loaded. Daily caps are checked
-- before the purchase prompt, because a paid receipt must always be granted.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Products = require(ConfigFolder:WaitForChild("Products"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))
local GameMath = require(Shared:WaitForChild("GameMath"))

local S = require(script.Parent.Parent.Registry)

local MonetizationService = {}

local function notify(player: Player, text: string)
	Remotes.Get("Notify"):FireClient(player, { Text = text })
end

local function capCount(data: any, id: string): number
	local cap = data.Purchases.DailyCaps[id]
	return if cap and cap.Day == Util.DayNumber() then cap.Count else 0
end

local function bumpCap(data: any, id: string)
	local today = Util.DayNumber()
	local cap = data.Purchases.DailyCaps[id]
	if not cap or cap.Day ~= today then
		cap = { Day = today, Count = 0 }
		data.Purchases.DailyCaps[id] = cap
	end
	cap.Count += 1
end

-- Cosmetics -----------------------------------------------------------------------------------------------

local function giveCosmetic(data: any, cosmetic: any)
	if cosmetic.Kind == "Title" then
		data.Titles[(string.gsub(cosmetic.Name, " %(title%)", ""))] = true
	else
		data.Inventory.Cosmetics[cosmetic.Id] = true
	end
end

-- Paid random items (Roblox policy) ------------------------------------------------------------------
-- Some countries ban random items bought with Robux. PolicyService tells us per player. For those
-- players crates cannot be bought, and any crate they own or earn opens to a FIXED item (the next
-- cosmetic they don't have yet, in list order) instead of a random one. If the check fails we
-- assume restricted, which is the safe side.
local restricted: { [Player]: boolean } = {}

function MonetizationService.RandomItemsRestricted(player: Player): boolean
	local cached = restricted[player]
	if cached ~= nil then
		return cached
	end
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	local value = true
	if ok and type(info) == "table" and info.ArePaidRandomItemsRestricted ~= nil then
		value = info.ArePaidRandomItemsRestricted == true
	end
	if player.Parent then
		restricted[player] = value
		player:SetAttribute("NoPaidRandom", value) -- the store hides crates and odds
	end
	return value
end

local function isCrate(id: string): boolean
	return id == "dp_crate1" or id == "dp_crate10"
end

-- Fixed (non-random) crate result: the first cosmetic in the list the player doesn't own yet
local function openFixed(player: Player, data: any)
	for _, cosmetic in Products.Cosmetics do
		local owned = if cosmetic.Kind == "Title" then data.Titles[(string.gsub(cosmetic.Name, " %(title%)", ""))] == true else data.Inventory.Cosmetics[cosmetic.Id] == true
		if not owned then
			giveCosmetic(data, cosmetic)
			Remotes.Get("CrateOpened"):FireClient(player, { Name = cosmetic.Name, Rarity = cosmetic.Rarity, Duplicate = false })
			return
		end
	end
	data.Inventory.Items.recolor = (data.Inventory.Items.recolor or 0) + 1
	Remotes.Get("CrateOpened"):FireClient(player, { Name = "Recolor Token", Rarity = "Common", Duplicate = true })
end

-- One crate: odds come from Weight; the pity rule guarantees Rare+ within CratePityCount crates
local function openCrate(player: Player, data: any)
	if MonetizationService.RandomItemsRestricted(player) then
		openFixed(player, data)
		return
	end
	data.CratePity += 1
	local weights: { [string]: number } = {}
	local forceRare = data.CratePity >= Products.CratePityCount
	for _, cosmetic in Products.Cosmetics do
		if not forceRare or cosmetic.Rarity ~= "Common" then
			weights[cosmetic.Id] = cosmetic.Weight
		end
	end
	local id = Util.WeightedPick(weights) :: string
	local cosmetic = Products.CosmeticById[id]
	if cosmetic.Rarity ~= "Common" then
		data.CratePity = 0
	end
	local duplicate = data.Inventory.Cosmetics[id] == true
	if duplicate then
		data.Inventory.Items.recolor = (data.Inventory.Items.recolor or 0) + 1 -- duplicates become a recolor token
	else
		giveCosmetic(data, cosmetic)
	end
	Remotes.Get("CrateOpened"):FireClient(player, { Name = cosmetic.Name, Rarity = cosmetic.Rarity, Duplicate = duplicate })
end

local function onEquip(player: Player, data: any, kind: any, id: any)
	if kind ~= "Glow" and kind ~= "Theme" and kind ~= "Title" then
		return
	end
	if id ~= nil then
		if type(id) ~= "string" then
			return
		end
		local owned = if kind == "Title" then data.Titles[id] == true else data.Inventory.Cosmetics[id] == true
		if not owned then
			return
		end
	end
	data.Equipped[kind] = id
	if kind == "Glow" then
		S.CreatureService.RefreshAllLooks(player)
	elseif kind == "Theme" then
		S.PlotService.ApplyTheme(player)
	else
		S.SocialService.RefreshTitle(player)
	end
	S.DataService.MarkChanged(player)
end

-- Passes ------------------------------------------------------------------------------------------------------

local function applyPass(player: Player, data: any, passId: string)
	data.Purchases.PassesOwned[passId] = true
	if passId == "pass_founder" then
		data.Titles.Founder = true
		data.Inventory.Cosmetics.glow_founder = true
		data.Inventory.Cosmetics.theme_founder = true
	elseif passId == "pass_vipflair" then
		data.Titles.VIP = true
	elseif passId == "pass_plot" then
		S.PlotService.BuildTiles(player)
	elseif passId == "pass_grovetheme" then
		S.LifecycleService.RefreshGrove(player)
	end
	S.DataService.MarkChanged(player)
end

-- Studio test command (/pass <id>): turn a pass on without buying it
function MonetizationService.TestGrantPass(player: Player, passId: string): boolean
	local data = S.DataService.GetData(player)
	if not data or not RunService:IsStudio() then
		return false
	end
	if passId == "premium" then
		-- Pretend to be a Roblox Premium member until the next join
		data.Purchases.PassesOwned.premium = true
		data.Titles[Products.Premium.Title] = true
		S.DataService.MarkChanged(player)
		return true
	end
	if Products.PassById[passId] == nil then
		return false
	end
	applyPass(player, data, passId)
	return true
end

-- Roblox Premium: checked on every join and when membership changes (the bonus ends with the
-- membership; the title is kept, like the Club title)
local function applyPremium(player: Player, data: any): boolean
	local premium = player.MembershipType == Enum.MembershipType.Premium
	data.Purchases.PassesOwned.premium = premium or nil
	if premium then
		data.Titles[Products.Premium.Title] = true
	end
	S.DataService.MarkChanged(player)
	return premium
end

local function checkOwnership(player: Player, data: any)
	applyPremium(player, data)
	for _, pass in Products.Passes do
		-- In Studio the creator (who owns every pass automatically) plays like a new player;
		-- passes bought in Studio (free test purchases) still apply
		local skip = RunService:IsStudio() and Config.StudioIgnoreOwnedPasses
		if pass.AssetId ~= 0 and not skip and not data.Purchases.PassesOwned[pass.Id] then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.AssetId)
			if ok and owns and S.DataService.GetData(player) == data then
				applyPass(player, data, pass.Id)
			end
		end
	end
	-- Garden Club subscription
	if Products.Club.SubscriptionId ~= "" then
		local ok, status = pcall(function()
			return (MarketplaceService :: any):GetUserSubscriptionStatusAsync(player, Products.Club.SubscriptionId)
		end)
		local subscribed = ok and type(status) == "table" and status.IsSubscribed == true
		if S.DataService.GetData(player) == data then
			data.Purchases.PassesOwned.club = subscribed or nil
			if subscribed then
				data.Titles.Club = true
				if data.Purchases.DailyCaps.club_gift == nil or data.Purchases.DailyCaps.club_gift.Day ~= Util.DayNumber() then
					bumpCap(data, "club_gift")
					for _ = 1, Products.Club.DailyCrates do
						openCrate(player, data)
					end
					notify(player, "Garden Club daily gift: a cosmetic crate!")
				end
			end
		end
	end
	S.DataService.MarkChanged(player)
end

-- Products ------------------------------------------------------------------------------------------------------

local function grantProduct(player: Player, data: any, product: Products.Product)
	local id = product.Id
	if id == "dp_rename" then
		data.Inventory.Items.rename = (data.Inventory.Items.rename or 0) + 1
	elseif id == "dp_recolor" then
		data.Inventory.Items.recolor = (data.Inventory.Items.recolor or 0) + 1
	elseif id == "dp_crate1" then
		openCrate(player, data)
	elseif id == "dp_crate10" then
		for _ = 1, 10 do
			openCrate(player, data)
		end
	elseif id == "dp_growth" then
		-- Does not stack: buying again only refreshes the timer
		data.Boosts.GrowthUntil = os.time() + Products.GrowthBoost.DurationSeconds
	elseif Products.CoinPackMinutes[id] then
		data.Coins += GameMath.CoinPackAmount(Products.CoinPackMinutes[id], data.GardenLevel)
	elseif id == "dp_tierskip" then
		S.SeasonService.AddXP(player, Config.Season.XPPerTier)
	elseif id == "dp_starter" then
		-- Granted even if somehow bought twice: a paid receipt must always be granted
		local pack = Products.StarterPack
		data.Coins += GameMath.CoinPackAmount(pack.CoinMinutes, data.GardenLevel)
		data.Inventory.Items.rename = (data.Inventory.Items.rename or 0) + pack.RenameTokens
		if pack.GrowthBoost then
			data.Boosts.GrowthUntil = math.max(data.Boosts.GrowthUntil, os.time()) + Products.GrowthBoost.DurationSeconds
		end
		data.Titles[pack.Title] = true
		for _ = 1, pack.Crates do
			openCrate(player, data)
		end
	elseif id == "dp_support" then
		data.Titles.Supporter = true
	end
	if product.Once then
		data.Purchases.PassesOwned[id] = true
	end
	bumpCap(data, id)
	bumpCap(data, "all")
	if capCount(data, "all") >= Products.SpendingReminderAfterPurchases then
		notify(player, "You've made several purchases today. Remember: you can play the whole game for free!")
	end
	notify(player, `Thanks! {product.Name} received.`)
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and S.DataService.GetProfile(player)
	if not player or not profile or not profile:IsActive() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = profile.Data
	local purchaseId = tostring(receipt.PurchaseId)
	if data.Purchases.Ids[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = Products.ProductByAssetId[receipt.ProductId]
	if not product then
		warn(`[Monetization] Unknown product {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Record first, then grant, then save
	data.Purchases.Ids[purchaseId] = os.time()
	local ok, err = pcall(grantProduct, player, data, product)
	if not ok then
		data.Purchases.Ids[purchaseId] = nil
		warn(`[Monetization] Grant failed: {err}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Trim the oldest receipt ids
	local ids = {}
	for id, at in data.Purchases.Ids do
		table.insert(ids, { Id = id, At = at })
	end
	if #ids > Config.MaxStoredPurchaseIds then
		table.sort(ids, function(a, b)
			return a.At < b.At
		end)
		for i = 1, #ids - Config.MaxStoredPurchaseIds do
			data.Purchases.Ids[ids[i].Id] = nil
		end
	end
	profile:Save()
	S.DataService.MarkChanged(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function onPurchaseRequest(player: Player, data: any, id: any)
	if Config.KillSwitches.Purchases or type(id) ~= "string" then
		return
	end
	if id == "open_crate" then
		-- Crates earned from the Moon Season
		if (data.Inventory.Items.crate or 0) > 0 then
			data.Inventory.Items.crate -= 1
			openCrate(player, data)
			S.DataService.MarkChanged(player)
		end
		return
	end
	if id == "club" then
		if Products.Club.SubscriptionId == "" then
			notify(player, "Garden Club is coming soon!")
			return
		end
		pcall(function()
			(MarketplaceService :: any):PromptSubscriptionPurchase(player, Products.Club.SubscriptionId)
		end)
		return
	end
	if id == "premium" then
		if player.MembershipType == Enum.MembershipType.Premium then
			notify(player, "You already have Roblox Premium. Your bonus is active!")
			return
		end
		pcall(MarketplaceService.PromptPremiumPurchase, MarketplaceService, player)
		return
	end
	local pass = Products.PassById[id]
	local product = Products.ProductById[id]
	local item = pass or product
	if not item then
		return
	end
	if item.AssetId == 0 then
		notify(player, `{item.Name} is coming soon!`)
		return
	end
	if data.Stage < item.OfferedFromStage then
		notify(player, "This item unlocks later in the game.")
		return
	end
	if isCrate(item.Id) and MonetizationService.RandomItemsRestricted(player) then
		notify(player, "Crates are not available in your region.")
		return
	end
	if pass then
		if data.Purchases.PassesOwned[pass.Id] then
			notify(player, "You already own this.")
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.AssetId)
	elseif product then
		if product.Once and data.Purchases.PassesOwned[product.Id] then
			notify(player, `You already got the {product.Name}.`)
			return
		end
		if product.DailyCap and capCount(data, product.Id) >= product.DailyCap then
			notify(player, `Daily limit reached for {product.Name}. Come back tomorrow!`)
			return
		end
		if product.Id == "dp_growth" and data.Boosts.GrowthUntil > os.time() then
			notify(player, "A Growth Boost is already active (boosts do not stack).")
			return
		end
		MarketplaceService:PromptProductPurchase(player, product.AssetId)
	end
end

function MonetizationService.Init()
	MarketplaceService.ProcessReceipt = processReceipt
end

function MonetizationService.Start()
	S.AntiExploit.Bind("PurchaseRequest", onPurchaseRequest, { KillSwitch = "Purchases" })
	S.AntiExploit.Bind("EquipCosmetic", onEquip)
	S.DataService.ProfileLoaded:Connect(function(player: Player, data: any)
		task.spawn(checkOwnership, player, data)
	end)
	-- Look up each player's paid-random-items policy as they join (cached for the session)
	local function lookup(player: Player)
		task.spawn(MonetizationService.RandomItemsRestricted, player)
	end
	Players.PlayerAdded:Connect(lookup)
	for _, player in Players:GetPlayers() do
		lookup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		restricted[player] = nil
	end)
	-- Someone buys Roblox Premium while playing: the bonus starts right away
	Players.PlayerMembershipChanged:Connect(function(player)
		local data = S.DataService.GetData(player)
		if data and applyPremium(player, data) then
			notify(player, `Welcome to Premium! You get {Products.Premium.Effect}.`)
		end
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, assetId, purchased)
		local data = S.DataService.GetData(player)
		if not purchased or not data then
			return
		end
		for _, pass in Products.Passes do
			if pass.AssetId == assetId then
				applyPass(player, data, pass.Id)
				notify(player, `Thanks! {pass.Name} unlocked.`)
			end
		end
	end)
end

return MonetizationService
