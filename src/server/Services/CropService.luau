--!strict
-- CropService: plant, water, grow (timestamps) and harvest (Build Spec section 5, 22.1).
-- One prompt per tile; its action depends on the tile state: Plant -> Water -> Harvest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Crops = require(ConfigFolder:WaitForChild("Crops"))
local Products = require(ConfigFolder:WaitForChild("Products"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local S = require(script.Parent.Parent.Registry)
local Build = require(script.Parent.Parent.Build)
local CropArt = require(script.Parent.Parent.CropArt)

local CropService = {}

local selectedSeed: { [Player]: string } = {}
local visualKeys: { [Player]: { [string]: string } } = {} -- tileId -> last built visual key


local function notify(player: Player, text: string)
	Remotes.Get("Notify"):FireClient(player, { Text = text })
end

local function isMoonlit(record: any): boolean
	return table.find(record.Mutations, "Moonlit") ~= nil
end

-- Seed the Plant prompt uses: the selected seed if owned, else the first owned seed
local function seedFor(player: Player, data: any): string?
	local seeds = data.Inventory.Seeds
	local selected = selectedSeed[player]
	if selected and (seeds[selected] or 0) > 0 then
		return selected
	end
	for _, crop in Crops.List do
		if (seeds[crop.Id] or 0) > 0 then
			return crop.Id
		end
	end
	return nil
end

local function buildVisual(tile: BasePart, crop: Crops.Crop, stage: number, moonlit: boolean)
	local old = tile:FindFirstChild("Crop")
	if old then
		old:Destroy()
	end
	if stage == 0 then
		return
	end
	CropArt.Build(tile, crop, stage, moonlit) -- blocky crop looks, see CropArt.luau
end

local function refreshTile(player: Player, data: any, tileId: string, now: number)
	local tile = S.PlotService.GetTilePart(player, tileId)
	if not tile then
		return
	end
	local prompt = tile:FindFirstChildOfClass("ProximityPrompt")
	local record = data.Crops[tileId]
	local stage, moonlit = 0, false
	local crop: Crops.Crop? = nil

	if record == nil then
		local seed = seedFor(player, data)
		if prompt then
			if seed then
				Build.SetPrompt(prompt, "Plant", `{Crops.ById[seed].Name} seed ({data.Inventory.Seeds[seed]})`)
			else
				Build.SetPrompt(prompt, "Plant", "No seeds - visit the merchant")
			end
		end
	else
		crop = Crops.ById[record.Type]
		if crop == nil then
			data.Crops[tileId] = nil -- crop removed from config
			return
		end
		moonlit = isMoonlit(record)
		local progress = GameMath.CropProgress(record, data.Plot.SoilLevel, now)
		local name = if moonlit then "Moonlit " .. crop.Name else crop.Name
		if progress >= 1 then
			stage = 3
			if prompt then
				Build.SetPrompt(prompt, "Harvest", name)
			end
		else
			stage = if progress < 0.4 then 1 else 2
			local left = math.ceil(GameMath.CropSecondsLeft(record, data.Plot.SoilLevel, now))
			local tapsLeft = Config.Engagement.WaterTapMaxPerGrowth - record.WaterTaps
			if prompt then
				if tapsLeft > 0 then
					Build.SetPrompt(prompt, `Water ({tapsLeft})`, `{name} - {left}s`)
				else
					Build.SetPrompt(prompt, nil)
				end
			end
		end
	end

	local keys = visualKeys[player]
	if keys == nil then
		keys = {}
		visualKeys[player] = keys
	end
	local key = `{if record then record.Type else ""}:{stage}:{moonlit}`
	if keys[tileId] ~= key then
		keys[tileId] = key
		if crop or stage == 0 then
			buildVisual(tile, crop or Crops.List[1], stage, moonlit)
		end
	end
end

function CropService.RefreshAll(player: Player)
	local data = S.DataService.GetData(player)
	local plot = S.PlotService.GetPlot(player)
	if not data or not plot then
		return
	end
	visualKeys[player] = {}
	local now = os.time()
	for tileId in plot.TileParts do
		refreshTile(player, data, tileId, now)
	end
end

local function plant(player: Player, data: any, tileId: string)
	if not S.ProgressionService.IsUnlocked(player, "Plant") then
		return
	end
	local seed = seedFor(player, data)
	if seed == nil then
		notify(player, "No seeds! Buy some at the merchant cart.")
		return
	end
	local crop = Crops.ById[seed]
	data.Inventory.Seeds[seed] -= 1
	if data.Inventory.Seeds[seed] <= 0 then
		data.Inventory.Seeds[seed] = nil
	end
	data.Crops[tileId] = { Type = seed, PlantedAt = os.time(), Mutations = {}, HarvestsLeft = crop.Harvests, WaterTaps = 0 }
	S.ObjectiveService.Progress(player, "Plant")
end

local function harvest(player: Player, data: any, tileId: string, record: any, auto: boolean?): boolean
	if not auto and not S.AntiExploit.CheckRate(player, "Harvest", Config.AntiExploit.MaxHarvestsPerSecond) then
		S.AntiExploit.Flag(player, "HarvestSpam")
		return false
	end
	if GameMath.GoodsCount(data) >= GameMath.InventoryCapacity(data) then
		if not auto then
			notify(player, if data.Purchases.PassesOwned.pass_inventory then "Your bag is full! Sell at the merchant cart." else "Your bag is full! Sell at the merchant cart, or get Bigger Inventory (+100) in the Store.")
		end
		return false
	end
	local crop = Crops.ById[record.Type]
	local key = GameMath.CropGoodsKey(crop.Id, isMoonlit(record))
	data.Inventory.Goods[key] = (data.Inventory.Goods[key] or 0) + 1

	record.HarvestsLeft -= 1
	if record.HarvestsLeft > 0 then
		record.PlantedAt = os.time() -- regrow
		record.WaterTaps = 0
	else
		data.Crops[tileId] = nil
	end
	if not auto then
		notify(player, `+1 {GameMath.GoodsName(key)}`)
	end
	S.ProgressionService.AddXP(player, crop.XP, "Harvest")
	S.ObjectiveService.Progress(player, "Harvest")
	S.SeasonService.AddXP(player, Config.Season.XP.Harvest)
	return true
end

function CropService.OnTileTriggered(player: Player, tileId: string)
	local data = S.DataService.GetData(player)
	local tile = S.PlotService.GetTilePart(player, tileId)
	if not data or not tile then
		return
	end
	if not S.AntiExploit.WithinDistance(player, tile.Position, Config.Distance.Plant) then
		S.AntiExploit.Flag(player, "TileTooFar", tileId)
		return
	end

	local now = os.time()
	local record = data.Crops[tileId]
	if record == nil then
		plant(player, data, tileId)
	elseif GameMath.CropProgress(record, data.Plot.SoilLevel, now) >= 1 then
		if harvest(player, data, tileId, record) then
			CropArt.Burst(tile, "Harvest")
		end
	elseif record.WaterTaps < Config.Engagement.WaterTapMaxPerGrowth then
		record.PlantedAt -= Config.Engagement.WaterTapSeconds
		record.WaterTaps += 1
		CropArt.Burst(tile, "Water")
	end
	refreshTile(player, data, tileId, now)
	S.DataService.MarkChanged(player)
end

-- Monsters --------------------------------------------------------------------------------

-- Planted tiles as monster targets
function CropService.GetTargets(player: Player): { { TileId: string, Position: Vector3, Weight: number } }
	local data = S.DataService.GetData(player)
	local targets = {}
	if not data then
		return targets
	end
	for tileId, record in data.Crops do
		local tile = S.PlotService.GetTilePart(player, tileId)
		local crop = Crops.ById[record.Type]
		if tile and crop then
			local weight = Config.TargetWeights.CropTile * (if crop.Glowing then Config.TargetWeights.GlowingCropMult else 1)
			table.insert(targets, { TileId = tileId, Position = tile.Position, Weight = weight })
		end
	end
	return targets
end

function CropService.HasCrop(player: Player, tileId: string): boolean
	local data = S.DataService.GetData(player)
	return data ~= nil and data.Crops[tileId] ~= nil
end

function CropService.EatCrop(player: Player, tileId: string)
	local data = S.DataService.GetData(player)
	if not data or not data.Crops[tileId] then
		return
	end
	data.Crops[tileId] = nil
	refreshTile(player, data, tileId, os.time())
	S.DataService.MarkChanged(player)
end

-- Night end: crops still in the ground roll their Moonlit chance (section 5)
function CropService.RollMoonlit(player: Player): number
	local data = S.DataService.GetData(player)
	if not data or not S.ProgressionService.IsUnlocked(player, "Moonlit") then
		return 0
	end
	local heistBonus = if data.HeistFlag and S.HeistService.IsActive() then Config.Heist.FlagMoonlitBonus else 0
	local count = 0
	for _, record in data.Crops do
		local crop = Crops.ById[record.Type]
		if crop and not isMoonlit(record) and Util.Chance(crop.MoonlitChance + heistBonus) then
			table.insert(record.Mutations, "Moonlit")
			count += 1
		end
	end
	-- First night: at least one crop always turns Moonlit, so new players see it right away
	if count == 0 and data.NightsSurvived == 1 then
		for _, record in data.Crops do
			if Crops.ById[record.Type] and not isMoonlit(record) then
				table.insert(record.Mutations, "Moonlit")
				count = 1
				break
			end
		end
	end
	if count > 0 then
		CropService.RefreshAll(player)
	end
	return count
end

-- Farmers ----------------------------------------------------------------------------------------

-- Nearest ready crop to a position (Farmer creatures walk there)
function CropService.FindReadyTile(player: Player, from: Vector3): (string?, Vector3?)
	local data = S.DataService.GetData(player)
	if not data or GameMath.GoodsCount(data) >= GameMath.InventoryCapacity(data) then
		return nil, nil
	end
	local now = os.time()
	local bestId, bestPosition, best = nil, nil, math.huge
	for tileId, record in data.Crops do
		if GameMath.CropProgress(record, data.Plot.SoilLevel, now) >= 1 then
			local tile = S.PlotService.GetTilePart(player, tileId)
			if tile then
				local distance = (tile.Position - from).Magnitude
				if distance < best then
					bestId, bestPosition, best = tileId, tile.Position, distance
				end
			end
		end
	end
	return bestId, bestPosition
end

-- Harvest without the player standing there (Farmer role, Auto-Harvest pass)
function CropService.AutoHarvest(player: Player, tileId: string): boolean
	local data = S.DataService.GetData(player)
	local record = data and data.Crops[tileId]
	if not data or not record or GameMath.CropProgress(record, data.Plot.SoilLevel, os.time()) < 1 then
		return false
	end
	local done = harvest(player, data, tileId, record, true)
	refreshTile(player, data, tileId, os.time())
	S.DataService.MarkChanged(player)
	return done
end

function CropService.Init() end

function CropService.Start()
	S.AntiExploit.Bind("SelectSeed", function(player: Player, data: any, cropId: any)
		if not S.AntiExploit.IsKeyOf(cropId, Crops.ById) then
			return
		end
		selectedSeed[player] = cropId
		CropService.RefreshAll(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		selectedSeed[player] = nil
		visualKeys[player] = nil
	end)

	-- Growth is timestamp based; this loop updates visuals and prompt text, applies the Growth
	-- Boost (crops gain extra seconds while it lasts) and runs the Auto-Harvest pass
	local autoTimer = 0
	task.spawn(function()
		while true do
			local dt = task.wait(1)
			autoTimer += dt
			local runAuto = autoTimer >= 10
			if runAuto then
				autoTimer = 0
			end
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local data = S.DataService.GetData(player)
				local plot = S.PlotService.GetPlot(player)
				if data and plot then
					if data.Boosts.GrowthUntil > now then
						local extra = (Products.GrowthBoost.Mult - 1) * dt
						for _, record in data.Crops do
							record.PlantedAt -= extra
						end
					end
					if runAuto and data.Purchases.PassesOwned.pass_autoharvest then
						for tileId, record in data.Crops do
							if GameMath.CropProgress(record, data.Plot.SoilLevel, now) >= 1 then
								CropService.AutoHarvest(player, tileId)
							end
						end
					end
					for tileId in plot.TileParts do
						refreshTile(player, data, tileId, now)
					end
				end
			end
		end
	end)
end

return CropService
