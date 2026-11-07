--!strict
-- PuzzleService: three optional Daily Puzzles (config/Puzzles.luau): Riddle, Odd One Out, Memory.
-- New puzzles every UTC day, picked per player (GameMath.DailyPuzzle, same on the client).
-- The server checks answers (riddle / odd one out) and a believable time (memory), then rewards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local PuzzlesConfig = require(ConfigFolder:WaitForChild("Puzzles"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local S = require(script.Parent.Parent.Registry)

local PuzzleService = {}

local KINDS = { "Riddle", "OddOneOut", "Memory" }
local memoryStart: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.Get("Notify"):FireClient(player, { Text = text, Kind = kind })
end

local function ensure(data: any)
	local today = Util.DayNumber()
	if data.Puzzles.Day ~= today then
		data.Puzzles.Day = today
		data.Puzzles.Done = {}
		data.Puzzles.BonusClaimed = false
	end
end

local function grant(player: Player, data: any, reward: any): string
	local coins = math.floor(GameMath.CoinPackAmount(reward.CoinMinutes, data.GardenLevel) * GameMath.RebirthCoinMult(data.Rebirths))
	data.Coins += coins
	S.SeasonService.AddXP(player, reward.SeasonXP)
	return `{Util.FormatNumber(coins)} coins and {reward.SeasonXP} Season XP`
end

local function solved(player: Player, data: any, kind: string)
	data.Puzzles.Done[kind] = true
	notify(player, `🧩 Puzzle solved! +{grant(player, data, PuzzlesConfig.Reward)}`, "Goal")
	local all = true
	for _, k in KINDS do
		if not data.Puzzles.Done[k] then
			all = false
		end
	end
	if all and not data.Puzzles.BonusClaimed then
		data.Puzzles.BonusClaimed = true
		notify(player, `🧠 All 3 puzzles done! Bonus: +{grant(player, data, PuzzlesConfig.AllDoneBonus)}`, "Goal")
	end
	S.QuestService.Progress(player, "Puzzle")
	S.DataService.MarkChanged(player)
end

local function onBegin(player: Player, data: any, kind: any)
	if kind == "Memory" then
		ensure(data)
		memoryStart[player] = os.clock()
	end
end

local function onSolve(player: Player, data: any, kind: any, answer: any)
	if type(kind) ~= "string" or not table.find(KINDS, kind) then
		return
	end
	ensure(data)
	if data.Puzzles.Done[kind] then
		return
	end
	local day = data.Puzzles.Day
	if kind == "Riddle" then
		local riddle = PuzzlesConfig.Riddles[GameMath.DailyPuzzle("Riddle", day, player.UserId)]
		if riddle and answer == riddle.Answer then
			solved(player, data, kind)
		else
			notify(player, "Not quite! Read it again and try another answer.")
		end
	elseif kind == "OddOneOut" then
		local puzzle = PuzzlesConfig.OddOneOut[GameMath.DailyPuzzle("OddOneOut", day, player.UserId)]
		if puzzle and answer == puzzle.Answer then
			solved(player, data, kind)
		else
			notify(player, "Not that one! Look again: which one is different?")
		end
	elseif kind == "Memory" then
		local started = memoryStart[player]
		if started and os.clock() - started >= PuzzlesConfig.MemoryMinSeconds then
			memoryStart[player] = nil
			solved(player, data, kind)
		end
	end
end

-- Opens the puzzles panel on the player's screen (town notice board)
function PuzzleService.Open(player: Player)
	Remotes.Get("OpenPuzzles"):FireClient(player)
end

function PuzzleService.Init() end

function PuzzleService.Start()
	S.AntiExploit.Bind("PuzzleBegin", onBegin)
	S.AntiExploit.Bind("PuzzleSolve", onSolve)
	S.DataService.ProfileLoaded:Connect(function(player: Player, data: any)
		ensure(data)
		S.DataService.MarkChanged(player)
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		memoryStart[player] = nil
	end)
end

return PuzzleService
