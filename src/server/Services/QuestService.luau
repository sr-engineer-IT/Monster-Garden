--!strict
-- QuestService: daily and weekly quests (config/Quests.luau). New quests each UTC day / week,
-- picked per player. Progress comes from the same game events as the goal chain
-- (ObjectiveService.Progress forwards every event here). Rewards are claimed in the Quests panel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local QuestsConfig = require(ConfigFolder:WaitForChild("Quests"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local S = require(script.Parent.Parent.Registry)

local QuestService = {}

local function notify(player: Player, text: string)
	Remotes.Get("Notify"):FireClient(player, { Text = text, Kind = "Goal" })
end

local function weekNumber(): number
	return (Util.DayNumber() + 3) // 7 -- weeks start on Monday (UTC)
end

-- Picks `count` different quests from a pool, the same picks all day for this player
local function pick(pool: { any }, count: number, stage: number, seed: number): { any }
	local available = {}
	for _, quest in pool do
		if stage >= quest.MinStage then
			table.insert(available, quest)
		end
	end
	local rng = Random.new(seed)
	local chosen = {}
	while #chosen < count and #available > 0 do
		table.insert(chosen, table.remove(available, rng:NextInteger(1, #available)))
	end
	return chosen
end

local function makeList(quests: { any }, level: number): { any }
	local list = {}
	for _, quest in quests do
		table.insert(list, { Id = quest.Id, Count = GameMath.QuestCount(quest, level), Progress = 0, Claimed = false })
	end
	return list
end

local function findQuest(pool: { any }, id: string): any
	for _, quest in pool do
		if quest.Id == id then
			return quest
		end
	end
	return nil
end

-- New quests when the day or week changes. Returns true if anything was replaced.
local function ensure(player: Player, data: any): boolean
	local q = data.Quests
	local changed = false
	local today = Util.DayNumber()
	if q.Day ~= today then
		q.Day = today
		q.BonusClaimed = false
		q.Daily = makeList(pick(QuestsConfig.Daily, QuestsConfig.DailyCount, data.Stage, today * 7919 + player.UserId), data.GardenLevel)
		changed = true
	end
	local week = weekNumber()
	if q.Week ~= week then
		q.Week = week
		q.Weekly = makeList(pick(QuestsConfig.Weekly, 1, data.Stage, week * 104729 + player.UserId), data.GardenLevel)
		changed = true
	end
	return changed
end

-- Maps a game event to a quest event ("Kill:brute" -> "Kill", "Pet"/"Feed" -> "Care")
local function questEvent(event: string): string
	if string.sub(event, 1, 5) == "Kill:" then
		return "Kill"
	elseif event == "Pet" or event == "Feed" then
		return "Care"
	end
	return event
end

function QuestService.Progress(player: Player, event: string, amount: number?)
	local data = S.DataService.GetData(player)
	if not data then
		return
	end
	ensure(player, data)
	local name = questEvent(event)
	local any = false
	for _, entry in { { List = data.Quests.Daily, Pool = QuestsConfig.Daily }, { List = data.Quests.Weekly, Pool = QuestsConfig.Weekly } } do
		for _, record in entry.List do
			local quest = findQuest(entry.Pool, record.Id)
			if quest and quest.Event == name and not record.Claimed and record.Progress < record.Count then
				record.Progress = math.min(record.Count, record.Progress + (amount or 1))
				any = true
				if record.Progress >= record.Count then
					notify(player, `Quest complete: {string.gsub(quest.Text, "{n}", tostring(record.Count))}! Claim it in Quests.`)
				end
			end
		end
	end
	if any then
		S.DataService.MarkChanged(player)
	end
end

local function grant(player: Player, data: any, reward: any): string
	local parts = {}
	if reward.CoinMinutes then
		local coins = math.floor(GameMath.CoinPackAmount(reward.CoinMinutes, data.GardenLevel) * GameMath.RebirthCoinMult(data.Rebirths))
		data.Coins += coins
		table.insert(parts, `{Util.FormatNumber(coins)} coins`)
	end
	if reward.Essence and data.Unlocks.Essence then
		data.Essence += reward.Essence
		table.insert(parts, `{reward.Essence} Essence`)
	end
	if reward.SeasonXP then
		S.SeasonService.AddXP(player, reward.SeasonXP)
		table.insert(parts, `{reward.SeasonXP} Season XP`)
	end
	if reward.Crates then
		data.Inventory.Items.crate = (data.Inventory.Items.crate or 0) + reward.Crates
		table.insert(parts, `{reward.Crates} cosmetic crate`)
	end
	return table.concat(parts, ", ")
end

local function onClaim(player: Player, data: any, kind: any, index: any)
	ensure(player, data)
	local q = data.Quests
	if kind == "Bonus" then
		if q.BonusClaimed then
			return
		end
		for _, record in q.Daily do
			if not record.Claimed then
				return
			end
		end
		q.BonusClaimed = true
		notify(player, `All daily quests done! Bonus: {grant(player, data, QuestsConfig.AllDailyBonus)}`)
		S.DataService.MarkChanged(player)
		return
	end
	local list = if kind == "Daily" then q.Daily elseif kind == "Weekly" then q.Weekly else nil
	if not list or not S.AntiExploit.IsInteger(index, 1, #list) then
		return
	end
	local record = list[index]
	if record.Claimed or record.Progress < record.Count then
		return
	end
	record.Claimed = true
	local reward = if kind == "Daily" then QuestsConfig.DailyReward else QuestsConfig.WeeklyReward
	notify(player, `Quest reward: {grant(player, data, reward)}`)
	S.DataService.MarkChanged(player)
end

function QuestService.Init() end

function QuestService.Start()
	S.AntiExploit.Bind("QuestClaim", onClaim)
	S.DataService.ProfileLoaded:Connect(function(player: Player, data: any)
		if ensure(player, data) then
			S.DataService.MarkChanged(player)
		end
	end)
	-- New quests appear at midnight UTC even for players who are online
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				local data = S.DataService.GetData(player)
				if data and ensure(player, data) then
					notify(player, "New daily quests are here!")
					S.DataService.MarkChanged(player)
				end
			end
		end
	end)
end

return QuestService
