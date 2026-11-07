--!strict
-- Daily Puzzles panel: today's Riddle, Odd One Out and Memory match (config/Puzzles.luau).
-- Opened from Quests or the town notice board. Always optional. The server checks answers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local PuzzlesConfig = require(ConfigFolder:WaitForChild("Puzzles"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("UI"):WaitForChild("Kit"))
local DataController = require(Client:WaitForChild("Controllers"):WaitForChild("DataController"))
local PanelController = require(Client:WaitForChild("Controllers"):WaitForChild("PanelController"))

local C = Kit.Colors
local player = Players.LocalPlayer

local PuzzlePanel = {}

local KINDS = {
	{ Id = "Riddle", Name = "Moon Riddle", Icon = "❓", Info = "Read the riddle, pick the answer" },
	{ Id = "OddOneOut", Name = "Odd One Out", Icon = "🔍", Info = "Which one does not belong?" },
	{ Id = "Memory", Name = "Memory Match", Icon = "🃏", Info = "Flip cards, find the pairs" },
}

local function today(): number
	return Util.DayNumber()
end

local function done(data: any, kind: string): boolean
	return data.Puzzles ~= nil and data.Puzzles.Day == today() and data.Puzzles.Done[kind] == true
end

-- Puzzles left today (for the Quests badge)
function PuzzlePanel.Remaining(data: any): number
	if not data then
		return 0
	end
	local n = 0
	for _, k in KINDS do
		if not done(data, k.Id) then
			n += 1
		end
	end
	return n
end

local function rewardText(data: any): string
	local coins = math.floor(GameMath.CoinPackAmount(PuzzlesConfig.Reward.CoinMinutes, data.GardenLevel) * GameMath.RebirthCoinMult(data.Rebirths))
	return `{Kit.Icons.Coins} {Util.FormatNumber(coins)}   {Kit.Icons.Season} {PuzzlesConfig.Reward.SeasonXP} XP`
end

local function shake(gui: GuiObject)
	local start = gui.Position
	for i = 1, 4 do
		local dx = if i % 2 == 0 then 8 else -8
		TweenService:Create(gui, TweenInfo.new(0.04), { Position = start + UDim2.fromOffset(dx, 0) }):Play()
		task.wait(0.045)
	end
	gui.Position = start
end

-- Menu ----------------------------------------------------------------------------------------------

function PuzzlePanel.Open()
	local data = DataController.Get()
	if not data then
		return
	end
	local list = PanelController.Open("Puzzles", "🧩 Daily Puzzles")
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local now = os.time()
	local left = 86400 - now % 86400
	Kit.Label({ Text = `3 new puzzles every day. Solve all 3 for a bonus! New puzzles in {left // 3600}h {(left % 3600) // 60}m.`, TextSize = 15, TextColor3 = C.Muted, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), ZIndex = 22, Parent = list })
	for _, kind in KINDS do
		local isDone = done(data, kind.Id)
		local row = Kit.Row(list, nextOrder(), 84)
		Kit.Label({ Text = kind.Icon, TextSize = 36, Size = UDim2.fromOffset(52, 64), ZIndex = 23, Parent = row })
		Kit.Label({ Text = kind.Name, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(60, 2), Size = UDim2.new(1, -190, 0, 26), ZIndex = 23, Parent = row })
		Kit.Label({ Text = kind.Info, TextSize = 14, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(60, 28), Size = UDim2.new(1, -190, 0, 18), ZIndex = 23, Parent = row })
		Kit.Label({ Text = rewardText(data), TextSize = 14, TextColor3 = C.Coins, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(60, 48), Size = UDim2.new(1, -190, 0, 18), ZIndex = 23, Parent = row })
		if isDone then
			Kit.Chip({ Text = `{Kit.Icons.Check} Solved`, TextSize = 15, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(112, 42), BackgroundColor3 = C.Locked, TextColor3 = C.Good, ZIndex = 23, Parent = row })
		else
			Kit.RowButton(row, 1, "Play", C.Good, function()
				if kind.Id == "Riddle" then
					PuzzlePanel.OpenRiddle()
				elseif kind.Id == "OddOneOut" then
					PuzzlePanel.OpenOddOneOut()
				else
					PuzzlePanel.OpenMemory()
				end
			end, 112)
		end
	end
	local allDone = PuzzlePanel.Remaining(data) == 0
	Kit.Label({ Text = if allDone then "🧠 All done today! Come back tomorrow for new puzzles." else "🧠 Bonus for solving all 3 today!", TextSize = 16, TextColor3 = if allDone then C.Good else C.Premium, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), ZIndex = 22, Parent = list })
end

-- Riddle ---------------------------------------------------------------------------------------------

function PuzzlePanel.OpenRiddle()
	local riddle = PuzzlesConfig.Riddles[GameMath.DailyPuzzle("Riddle", today(), player.UserId)]
	if not riddle then
		return
	end
	local list = PanelController.Open("PuzzleGame", "❓ Moon Riddle")
	local card = Kit.Row(list, 1, 130)
	Kit.Label({ Text = riddle.Q, TextSize = 22, Size = UDim2.fromScale(1, 1), ZIndex = 23, Parent = card })
	local grid = Kit.New("Frame", { Size = UDim2.new(1, 0, 0, 120), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 22, Parent = list }, {
		Kit.New("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 54), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, option in riddle.Options do
		local button: TextButton
		button = Kit.Button({ Text = option, TextSize = 20, BackgroundColor3 = C.Accent, LayoutOrder = i, ZIndex = 23, Parent = grid }, function()
			Remotes.Get("PuzzleSolve"):FireServer("Riddle", i)
			if i == riddle.Answer then
				button.BackgroundColor3 = C.Good
				task.delay(0.8, PuzzlePanel.Open)
			else
				button.BackgroundColor3 = C.Bad
				task.spawn(shake, button)
			end
		end)
	end
	Kit.Button({ Text = "← Back", TextSize = 16, Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.Header, LayoutOrder = 3, ZIndex = 22, Parent = list }, PuzzlePanel.Open)
end

-- Odd One Out ---------------------------------------------------------------------------------------

function PuzzlePanel.OpenOddOneOut()
	local puzzle = PuzzlesConfig.OddOneOut[GameMath.DailyPuzzle("OddOneOut", today(), player.UserId)]
	if not puzzle then
		return
	end
	local list = PanelController.Open("PuzzleGame", "🔍 Odd One Out")
	Kit.Label({ Text = "Which one does NOT belong with the others?", TextSize = 22, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, ZIndex = 22, Parent = list })
	local grid = Kit.New("Frame", { Size = UDim2.new(1, 0, 0, 190), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 22, Parent = list }, {
		Kit.New("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 88), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local why = Kit.Label({ Text = "", TextSize = 17, TextColor3 = C.Coins, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, ZIndex = 22, Parent = list })
	for i, item in puzzle.Items do
		local button: TextButton
		button = Kit.Button({ Text = item, TextSize = 24, BackgroundColor3 = C.Header, LayoutOrder = i, ZIndex = 23, Parent = grid }, function()
			Remotes.Get("PuzzleSolve"):FireServer("OddOneOut", i)
			if i == puzzle.Answer then
				button.BackgroundColor3 = C.Good
				why.Text = `✔ {puzzle.Why}`
				task.delay(2, PuzzlePanel.Open)
			else
				button.BackgroundColor3 = C.Bad
				task.spawn(shake, button)
			end
		end)
	end
	Kit.Button({ Text = "← Back", TextSize = 16, Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.Header, LayoutOrder = 4, ZIndex = 22, Parent = list }, PuzzlePanel.Open)
end

-- Memory ----------------------------------------------------------------------------------------------

function PuzzlePanel.OpenMemory()
	local seed = GameMath.DailyPuzzle("Memory", today(), player.UserId)
	local rng = Random.new(seed)
	-- pick pairs and shuffle the cards (same layout all day)
	local icons = table.clone(PuzzlesConfig.MemoryIcons)
	local deck = {}
	for _ = 1, PuzzlesConfig.MemoryPairs do
		local icon = table.remove(icons, rng:NextInteger(1, #icons))
		table.insert(deck, icon)
		table.insert(deck, icon)
	end
	for i = #deck, 2, -1 do
		local j = rng:NextInteger(1, i)
		deck[i], deck[j] = deck[j], deck[i]
	end

	local list = PanelController.Open("PuzzleGame", "🃏 Memory Match")
	local status = Kit.Label({ Text = "Find all the pairs! Moves: 0", TextSize = 20, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, ZIndex = 22, Parent = list })
	local grid = Kit.New("Frame", { Size = UDim2.new(1, 0, 0, 3 * 96 + 20), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 22, Parent = list }, {
		Kit.New("UIGridLayout", { CellSize = UDim2.new(0.25, -8, 0, 92), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	Remotes.Get("PuzzleBegin"):FireServer("Memory")

	local buttons: { TextButton } = {}
	local matched: { [number]: boolean } = {}
	local open: { number } = {}
	local moves, pairsFound, busy = 0, 0, false
	for i, icon in deck do
		buttons[i] = Kit.Button({ Text = "?", TextSize = 40, BackgroundColor3 = C.Premium, LayoutOrder = i, ZIndex = 23, Parent = grid }, function()
			if busy or matched[i] or table.find(open, i) then
				return
			end
			buttons[i].Text = icon
			buttons[i].BackgroundColor3 = C.Header
			table.insert(open, i)
			if #open == 2 then
				moves += 1
				local a, b = open[1], open[2]
				if deck[a] == deck[b] then
					matched[a], matched[b] = true, true
					buttons[a].BackgroundColor3 = C.Good
					buttons[b].BackgroundColor3 = C.Good
					pairsFound += 1
					open = {}
					if pairsFound == PuzzlesConfig.MemoryPairs then
						status.Text = `🎉 You did it in {moves} moves!`
						task.delay(0.6, function()
							Remotes.Get("PuzzleSolve"):FireServer("Memory", moves)
						end)
						task.delay(2, PuzzlePanel.Open)
					end
				else
					busy = true
					task.delay(0.8, function()
						for _, k in { a, b } do
							if buttons[k].Parent then
								buttons[k].Text = "?"
								buttons[k].BackgroundColor3 = C.Premium
							end
						end
						open = {}
						busy = false
					end)
				end
				if pairsFound < PuzzlesConfig.MemoryPairs then
					status.Text = `Find all the pairs! Moves: {moves}`
				end
			end
		end)
	end
	Kit.Button({ Text = "← Back", TextSize = 16, Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.Header, LayoutOrder = 3, ZIndex = 22, Parent = list }, PuzzlePanel.Open)
end

function PuzzlePanel.Start()
	Remotes.Get("OpenPuzzles").OnClientEvent:Connect(PuzzlePanel.Open)
	local last = 0
	DataController.Changed:Connect(function()
		if os.clock() - last < 1 then
			return
		end
		last = os.clock()
		PanelController.Refresh("Puzzles", PuzzlePanel.Open)
	end)
end

return PuzzlePanel
