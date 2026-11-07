--!strict
-- Quests panel: today's daily quests (+ bonus for finishing all), the weekly quest and Rebirth.
-- Display only: the server checks every claim and the rebirth level.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local QuestsConfig = require(ConfigFolder:WaitForChild("Quests"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("UI"):WaitForChild("Kit"))
local DataController = require(Client:WaitForChild("Controllers"):WaitForChild("DataController"))
local PanelController = require(Client:WaitForChild("Controllers"):WaitForChild("PanelController"))

local C = Kit.Colors
local REBIRTH = QuestsConfig.Rebirth

local QuestsPanel = {}

local confirmUntil = 0 -- rebirth needs two taps within a few seconds

local function findQuest(pool: { any }, id: string): any
	for _, quest in pool do
		if quest.Id == id then
			return quest
		end
	end
	return nil
end

local function rewardText(reward: any, data: any): string
	local parts = {}
	if reward.CoinMinutes then
		local coins = math.floor(GameMath.CoinPackAmount(reward.CoinMinutes, data.GardenLevel) * GameMath.RebirthCoinMult(data.Rebirths))
		table.insert(parts, `{Kit.Icons.Coins} {Util.FormatNumber(coins)}`)
	end
	if reward.Essence and data.Unlocks.Essence then
		table.insert(parts, `{Kit.Icons.Essence} {reward.Essence}`)
	end
	if reward.SeasonXP then
		table.insert(parts, `{Kit.Icons.Season} {reward.SeasonXP} XP`)
	end
	if reward.Crates then
		table.insert(parts, `ð {reward.Crates} crate`)
	end
	return table.concat(parts, "   ")
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m = seconds // 3600, (seconds % 3600) // 60
	return if h > 0 then `{h}h {m}m` else `{m}m`
end

-- Number of quests (and the all-done bonus) ready to claim, for the menu badge
function QuestsPanel.Claimable(data: any): number
	local q = data and data.Quests
	if not q then
		return 0
	end
	local count, allClaimed = 0, #q.Daily > 0
	for _, list in { q.Daily, q.Weekly } do
		for _, record in list do
			if not record.Claimed and record.Progress >= record.Count then
				count += 1
			end
		end
	end
	for _, record in q.Daily do
		if not record.Claimed then
			allClaimed = false
		end
	end
	if allClaimed and not q.BonusClaimed then
		count += 1
	end
	return count
end

local function questRow(list: Instance, order: number, quest: any, record: any, kind: string, index: number, reward: any, data: any)
	local done = record.Progress >= record.Count
	local row = Kit.Row(list, order, 92)
	local text = string.gsub(quest.Text, "{n}", Util.FormatNumber(record.Count))
	Kit.Label({ Text = text, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -130, 0, 24), ZIndex = 23, Parent = row })
	local _, fill = Kit.Bar({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, -130, 0, 14), ZIndex = 23, Parent = row }, if done then C.Good else C.Coins)
	Kit.SetBar(fill, record.Progress / record.Count)
	Kit.Label({ Text = `{Util.FormatNumber(math.min(record.Progress, record.Count))} / {Util.FormatNumber(record.Count)}`, TextSize = 13, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, -130, 0, 16), ZIndex = 23, Parent = row })
	Kit.Label({ Text = rewardText(reward, data), TextSize = 14, TextColor3 = C.Coins, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, -230, 0, 18), ZIndex = 23, Parent = row })
	if record.Claimed then
		Kit.Chip({ Text = `{Kit.Icons.Check} Claimed`, TextSize = 15, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(112, 40), BackgroundColor3 = C.Locked, TextColor3 = C.Good, ZIndex = 23, Parent = row })
	else
		Kit.RowButton(row, 1, if done then "Claim" else "Not yet", if done then C.Good else C.Locked, function()
			if done then
				Remotes.Get("QuestClaim"):FireServer(kind, index)
			end
		end, 112)
	end
end

function QuestsPanel.Open()
	local data = DataController.Get()
	if not data or not data.Quests then
		return
	end
	local list = PanelController.Open("Quests", `{Kit.Icons.Quests} Quests`)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local q = data.Quests
	local now = os.time()

	-- Daily
	Kit.Heading(list, "Daily quests", nextOrder())
	Kit.Label({ Text = `New quests in {formatTime(86400 - now % 86400)}`, TextSize = 14, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nextOrder(), ZIndex = 22, Parent = list })
	local allClaimed = #q.Daily > 0
	for index, record in q.Daily do
		local quest = findQuest(QuestsConfig.Daily, record.Id)
		if quest then
			questRow(list, nextOrder(), quest, record, "Daily", index, QuestsConfig.DailyReward, data)
		end
		if not record.Claimed then
			allClaimed = false
		end
	end
	local bonus = Kit.Row(list, nextOrder(), 64)
	Kit.Label({ Text = "Bonus: finish all daily quests", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -130, 0, 22), ZIndex = 23, Parent = bonus })
	Kit.Label({ Text = rewardText(QuestsConfig.AllDailyBonus, data), TextSize = 14, TextColor3 = C.Coins, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -130, 0, 18), ZIndex = 23, Parent = bonus })
	if q.BonusClaimed then
		Kit.Chip({ Text = `{Kit.Icons.Check} Claimed`, TextSize = 15, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(112, 40), BackgroundColor3 = C.Locked, TextColor3 = C.Good, ZIndex = 23, Parent = bonus })
	else
		Kit.RowButton(bonus, 1, if allClaimed then "Claim" else "Not yet", if allClaimed then C.Premium else C.Locked, function()
			if allClaimed then
				Remotes.Get("QuestClaim"):FireServer("Bonus", 1)
			end
		end, 112)
	end

	-- Daily Puzzles (optional)
	local puzzlesLeft = require(script.Parent:WaitForChild("PuzzlePanel")).Remaining(data)
	Kit.Button({ Text = if puzzlesLeft > 0 then `🧩 Daily Puzzles ({3 - puzzlesLeft}/3 solved)` else "🧩 Daily Puzzles: all solved!", TextSize = 18, Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = if puzzlesLeft > 0 then C.Premium else C.Locked, LayoutOrder = nextOrder(), ZIndex = 22, Parent = list }, function()
		require(script.Parent:WaitForChild("PuzzlePanel")).Open()
	end)

	-- Weekly
	Kit.Heading(list, "Weekly quest", nextOrder())
	local daysLeft = 7 - ((now // 86400 + 3) % 7)
	Kit.Label({ Text = `New weekly quest in {daysLeft} day(s)`, TextSize = 14, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nextOrder(), ZIndex = 22, Parent = list })
	for index, record in q.Weekly do
		local quest = findQuest(QuestsConfig.Weekly, record.Id)
		if quest then
			questRow(list, nextOrder(), quest, record, "Weekly", index, QuestsConfig.WeeklyReward, data)
		end
	end

	-- Rebirth
	local rebirths = data.Rebirths or 0
	Kit.Heading(list, `{Kit.Icons.Rebirth} Rebirth`, nextOrder())
	local nextCoin = math.floor((GameMath.RebirthCoinMult(rebirths + 1) - 1) * 100 + 0.5)
	local nextXP = math.floor((GameMath.RebirthXPMult(rebirths + 1) - 1) * 100 + 0.5)
	local info = Kit.Row(list, nextOrder(), 150)
	local lines = {
		if rebirths > 0 then `You have reborn {rebirths} time(s). Current bonus: +{math.floor((GameMath.RebirthCoinMult(rebirths) - 1) * 100 + 0.5)}% coins, +{math.floor((GameMath.RebirthXPMult(rebirths) - 1) * 100 + 0.5)}% XP.` else "Start your garden again, stronger!",
		`Next rebirth: +{nextCoin}% coins and +{nextXP}% Garden XP forever, plus the Reborn title.`,
		"You keep: creatures, Essence, unlocked features, buildings, cosmetics, passes and Season.",
		"You reset: Garden Level, coins, plot size, soil, crops and seeds.",
	}
	Kit.Label({ Text = table.concat(lines, "\n"), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 1, 0), ZIndex = 23, Parent = info })

	local ready = data.GardenLevel >= REBIRTH.MinLevel
	local confirming = ready and os.clock() < confirmUntil
	local text = if not ready then `{Kit.Icons.Lock} Reach Garden Level {REBIRTH.MinLevel} (you are {data.GardenLevel})` elseif confirming then "Tap again to confirm rebirth" else `{Kit.Icons.Rebirth} Rebirth now`
	Kit.Button({ Text = text, TextSize = 18, Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = if not ready then C.Locked elseif confirming then C.Bad else C.Premium, LayoutOrder = nextOrder(), ZIndex = 22, Parent = list }, function()
		if not ready then
			return
		end
		if os.clock() < confirmUntil then
			confirmUntil = 0
			Remotes.Get("Rebirth"):FireServer()
			PanelController.Close()
		else
			confirmUntil = os.clock() + 4
			PanelController.Refresh("Quests", QuestsPanel.Open)
			task.delay(4.1, function()
				PanelController.Refresh("Quests", QuestsPanel.Open)
			end)
		end
	end)
end

function QuestsPanel.Start()
	local last = 0
	DataController.Changed:Connect(function()
		if os.clock() - last < 1 then
			return
		end
		last = os.clock()
		PanelController.Refresh("Quests", QuestsPanel.Open)
	end)
end

return QuestsPanel
