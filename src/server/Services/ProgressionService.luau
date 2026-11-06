--!strict
-- ProgressionService: Garden Level, XP, stages and feature unlocks (Build Spec section 4).
-- Every other service asks ProgressionService.IsUnlocked(player, featureKey) before acting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Stages = require(ConfigFolder:WaitForChild("Stages"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local S = require(script.Parent.Parent.Registry)

local ProgressionService = {}

local function banner(player: Player, title: string, text: string, kind: string)
	Remotes.Get("UnlockBanner"):FireClient(player, { Title = title, Text = text, Kind = kind })
end

local function triggerMet(player: Player, data: any, trigger: Stages.Trigger): boolean
	local adults = if trigger.AdultCreatures then S.CreatureService.CountAdults(data) else 0
	return GameMath.StageTriggerMet(trigger, data.GardenLevel, data.NightsSurvived, adults)
end

-- Make sure every feature of every reached stage is unlocked (also fixes old saves after config edits)
local function syncUnlocks(data: any)
	for _, stage in Stages.List do
		if stage.Id <= data.Stage then
			for _, feature in stage.Features do
				data.Unlocks[feature] = true
			end
		end
	end
end

function ProgressionService.IsUnlocked(player: Player, feature: string): boolean
	local data = S.DataService.GetData(player)
	return data ~= nil and data.Unlocks[feature] == true
end

-- Checks stage triggers in order; a player can climb several stages at once
function ProgressionService.CheckStage(player: Player)
	local data = S.DataService.GetData(player)
	if not data then
		return
	end
	while data.Stage < math.min(#Stages.List, Config.MaxStageEnabled) do
		local nextStage = Stages.Get(data.Stage + 1)
		if not triggerMet(player, data, nextStage.Trigger) then
			break
		end
		data.Stage = nextStage.Id
		syncUnlocks(data)

		local gift = Config.StageGiftCoins[nextStage.Id]
		local giftText = if gift then ` Gift: {gift} coins!` else ""
		if gift then
			data.Coins += gift
		end
		banner(player, `New: {nextStage.Name}!`, nextStage.Tip .. giftText, "Stage")
		S.LifecycleService.RefreshGrove(player)
		print(`[Progression] {player.Name} reached stage {nextStage.Id} ({nextStage.Name})`)
	end
	S.DataService.MarkChanged(player)
end

local function onLevelUp(player: Player, data: any, level: number)
	local parts = {}
	local micro = Stages.MicroUnlocks[level]
	if micro then
		if micro.Seeds then
			table.insert(parts, "New seeds at the merchant")
		end
		if micro.MerchantShows then
			table.insert(parts, "New seeds at the merchant")
		end
		if micro.PlotOffered then
			table.insert(parts, "Bigger plot available")
		end
		if micro.Title then
			data.Titles[micro.Title] = true
			table.insert(parts, `Title: {micro.Title}`)
		end
		if micro.GiftCoins then
			data.Coins += micro.GiftCoins
			table.insert(parts, `Gift: {micro.GiftCoins} coins`)
		end
		if micro.MysteryEgg and not data.TutorialDone.MysteryEgg then
			data.TutorialDone.MysteryEgg = true
			S.CreatureService.GiveMysteryEgg(player)
			table.insert(parts, "A Mystery Egg appeared!")
		end
	end
	-- Only one "new seeds" line even if two micro-unlock kinds match
	local seen, text = {}, {}
	for _, part in parts do
		if not seen[part] then
			seen[part] = true
			table.insert(text, part)
		end
	end
	banner(player, `Garden Level {level}!`, table.concat(text, " - "), "Level")
	S.ObjectiveService.Refresh(player)
	ProgressionService.CheckStage(player)
end

function ProgressionService.AddXP(player: Player, amount: number, _reason: string?)
	local data = S.DataService.GetData(player)
	if not data or amount <= 0 then
		return
	end
	data.GardenXP += math.floor(amount * GameMath.RebirthXPMult(data.Rebirths)) -- rebirth bonus
	while data.GardenLevel < Config.Level.MaxLevel do
		local need = GameMath.XPToNext(data.GardenLevel)
		if data.GardenXP < need then
			break
		end
		data.GardenXP -= need
		data.GardenLevel += 1
		onLevelUp(player, data, data.GardenLevel)
	end
	S.DataService.MarkChanged(player)
end

-- Section 4.3: "I know this game" skips stages 1-2 once, for a fresh account only
local function onVeteranSkip(player: Player, data: any)
	if data.VeteranSkipUsed or data.NightsSurvived > 0 or data.Stage > 1 or data.GardenLevel > 2 then
		return
	end
	local skip = Stages.VeteranSkip
	data.VeteranSkipUsed = true
	data.NightsSurvived = 1
	data.Stage = skip.TargetStage
	syncUnlocks(data)
	data.Coins += skip.GiftCoins
	data.Inventory.Seeds.tomato = (data.Inventory.Seeds.tomato or 0) + skip.GiftSeeds
	-- Jump the goal chain past the first-night tutorial goals
	data.ObjectiveIndex = math.max(data.ObjectiveIndex, 7)
	data.ObjectiveProgress = 0
	banner(player, "Welcome back, gardener!", `Stages 1-2 skipped. Gift: {skip.GiftCoins} coins and {skip.GiftSeeds} tomato seeds.`, "Stage")
	S.LifecycleService.RefreshGrove(player)
	S.DataService.MarkChanged(player)
end

-- Tutorial tips the client may mark as seen, and player settings it may change
local CLIENT_TIPS = { Guide = true }
local CLIENT_SETTINGS = { SoundOn = true, GuideArrow = true }

local function onMarkTip(player: Player, data: any, tipId: any)
	if type(tipId) == "string" and CLIENT_TIPS[tipId] then
		data.TutorialDone[tipId] = true
		S.DataService.MarkChanged(player)
	end
end

local function onSetSetting(player: Player, data: any, key: any, value: any)
	if type(key) == "string" and CLIENT_SETTINGS[key] and type(value) == "boolean" then
		data.Settings[key] = value
		S.DataService.MarkChanged(player)
	end
end

function ProgressionService.Init() end

function ProgressionService.Start()
	S.AntiExploit.Bind("VeteranSkip", onVeteranSkip)
	S.AntiExploit.Bind("MarkTip", onMarkTip)
	S.AntiExploit.Bind("SetSetting", onSetSetting)
	S.DataService.ProfileLoaded:Connect(function(player: Player, data: any)
		syncUnlocks(data)
		ProgressionService.CheckStage(player)
	end)
end

return ProgressionService
