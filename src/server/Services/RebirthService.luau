--!strict
-- RebirthService: at Quests.Rebirth.MinLevel a player can rebirth (config/Quests.luau).
-- Resets: Garden Level and XP, coins, plot size, soil, crops, seeds and unsold goods.
-- Keeps: creatures, Essence, stages and unlocked features, buildings, cosmetics, titles, passes,
-- Season progress and quests. Gives a permanent coin and XP bonus per rebirth and a "Reborn" title.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Crops = require(ConfigFolder:WaitForChild("Crops"))
local QuestsConfig = require(ConfigFolder:WaitForChild("Quests"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local S = require(script.Parent.Parent.Registry)

local RebirthService = {}

local REBIRTH = QuestsConfig.Rebirth

local function onRebirth(player: Player, data: any)
	if data.GardenLevel < REBIRTH.MinLevel then
		Remotes.Get("Notify"):FireClient(player, { Text = `Rebirth unlocks at Garden Level {REBIRTH.MinLevel}.` })
		return
	end
	local phase = player:GetAttribute("Phase")
	if phase == "Night" or phase == "Warning" then
		Remotes.Get("Notify"):FireClient(player, { Text = "You can't rebirth during the night. Wait for the day!" })
		return
	end

	data.Rebirths = (data.Rebirths or 0) + 1
	data.GardenLevel = 1
	data.GardenXP = 0
	data.Coins = Config.StarterCoins
	data.Plot.SizeIndex = 1
	data.Plot.SoilLevel = 1
	data.Crops = {}
	data.Inventory.Seeds = table.clone(Crops.StarterSeeds)
	data.Inventory.Goods = {}
	data.Titles.Reborn = true
	if data.Equipped.Title == nil then
		data.Equipped.Title = "Reborn"
	end

	player:SetAttribute("GardenLevel", 1)
	S.PlotService.BuildTiles(player)
	S.SocialService.RefreshTitle(player)
	S.DataService.MarkChanged(player)

	local coinBonus = math.floor((GameMath.RebirthCoinMult(data.Rebirths) - 1) * 100 + 0.5)
	local xpBonus = math.floor((GameMath.RebirthXPMult(data.Rebirths) - 1) * 100 + 0.5)
	Remotes.Get("UnlockBanner"):FireClient(player, {
		Title = `Reborn! (x{data.Rebirths})`,
		Text = `Permanent bonus: +{coinBonus}% coins and +{xpBonus}% Garden XP. Your creatures came with you!`,
		Kind = "Rebirth",
	})
end

function RebirthService.Init() end

function RebirthService.Start()
	S.AntiExploit.Bind("Rebirth", onRebirth)
end

return RebirthService
