--!strict
-- UpgradeService: the Upgrade Station in every garden (config/Upgrades.luau). Permanent coin
-- upgrades, kept through Rebirth:
--   Grow  -> GameMath.GrowSeconds (crops grow faster, also offline: growth is timestamp based)
--   Speed -> the character's WalkSpeed (set here on spawn and after buying)
--   Yield -> CropService harvest (chance of one extra crop)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Upgrades = require(ConfigFolder:WaitForChild("Upgrades"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local S = require(script.Parent.Parent.Registry)

local UpgradeService = {}

local function notify(player: Player, text: string)
	Remotes.Get("Notify"):FireClient(player, { Text = text })
end

local function ensure(data: any)
	data.Upgrades = data.Upgrades or {}
	for _, upgrade in Upgrades.List do
		if type(data.Upgrades[upgrade.Id]) ~= "number" then
			data.Upgrades[upgrade.Id] = 0
		end
	end
end

function UpgradeService.ApplySpeed(player: Player)
	local data = S.DataService.GetData(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid then
		return
	end
	humanoid.WalkSpeed = Upgrades.BaseWalkSpeed + Upgrades.ById.Speed.PerLevel * GameMath.UpgradeLevel(data, "Speed")
end

-- Opens the panel for the owner (from the station prompt)
function UpgradeService.Open(player: Player)
	local data = S.DataService.GetData(player)
	if data then
		ensure(data)
		Remotes.Get("OpenUpgrades"):FireClient(player)
	end
end

local function nearStation(player: Player): boolean
	local plot = S.PlotService.GetPlot(player)
	if plot and S.AntiExploit.WithinDistance(player, plot.Center + Config.World.UpgradeStationOffset, Config.Distance.Merchant) then
		return true
	end
	notify(player, "Walk to the Upgrade Station in your garden first.")
	return false
end

local function onBuyUpgrade(player: Player, data: any, upgradeId: any)
	if not S.AntiExploit.IsKeyOf(upgradeId, Upgrades.ById) or not nearStation(player) then
		return
	end
	ensure(data)
	local upgrade = Upgrades.ById[upgradeId]
	local level = data.Upgrades[upgradeId]
	local nextLevel = level + 1
	local cost = upgrade.Costs[nextLevel]
	if not cost then
		notify(player, `{upgrade.Name} is already at max level!`)
		return
	end
	local minLevel = upgrade.MinLevels[nextLevel] or 1
	if data.GardenLevel < minLevel then
		notify(player, `{upgrade.Name} level {nextLevel} unlocks at Garden Level {minLevel}.`)
		return
	end
	if not S.EconomyService.Spend(player, { Coins = cost }) then
		return
	end
	data.Upgrades[upgradeId] = nextLevel
	if upgradeId == "Speed" then
		UpgradeService.ApplySpeed(player)
	elseif upgradeId == "Grow" then
		S.CropService.RefreshAll(player) -- timers on the tiles update right away
	end
	S.DataService.MarkChanged(player)
	Remotes.Get("UnlockBanner"):FireClient(player, { Title = `{upgrade.Icon} {upgrade.Name} level {nextLevel}!`, Text = Upgrades.EffectText(upgradeId, nextLevel) })
end

function UpgradeService.Init() end

function UpgradeService.Start()
	S.AntiExploit.Bind("BuyUpgrade", onBuyUpgrade)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			UpgradeService.ApplySpeed(player)
		end)
		if player.Character then
			task.spawn(UpgradeService.ApplySpeed, player)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	S.DataService.ProfileLoaded:Connect(function(player: Player, data: any)
		ensure(data)
		UpgradeService.ApplySpeed(player)
	end)
end

return UpgradeService
