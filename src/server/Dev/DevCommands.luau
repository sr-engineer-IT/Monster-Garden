--!strict
-- Studio-only chat commands for testing. Never loaded in live servers (see Main.server).
--   /data           print your profile summary
--   /coins <n>      add (or remove) coins
--   /essence <n>    add (or remove) essence
--   /xp <n>         add Garden XP (levels up and unlocks stages normally)
--   /night          start the night warning now
--   /level <n>      jump to a Garden Level
--   /age <n>        age all your creatures by n play minutes
--   /hunger <n>     set the server Hunger Meter
--   /feast          start Feast Night now (needs stage 9)
--   /test           run the formula unit tests (results in Output)
--   /resetdata      reset your profile to defaults (rejoin after)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameMath"))

local S = require(script.Parent.Parent.Registry)

local DevCommands = {}

local function handle(player: Player, message: string)
	local command, arg = string.match(message, "^/(%a+)%s*(%S*)")
	if not command then
		return
	end
	local data = S.DataService.GetData(player)
	if not data then
		return
	end
	local amount = tonumber(arg) or 0

	if command == "data" then
		print(`[Dev] {player.Name}: Coins {data.Coins}, Essence {data.Essence}, Level {data.GardenLevel} ({data.GardenXP} XP), Stage {data.Stage}, Nights {data.NightsSurvived}, PlaySeconds {math.floor(data.PlaySeconds)}`)
	elseif command == "coins" then
		data.Coins = math.max(0, data.Coins + amount)
		S.DataService.MarkChanged(player)
	elseif command == "essence" then
		data.Essence = math.max(0, data.Essence + amount)
		S.DataService.MarkChanged(player)
	elseif command == "xp" then
		S.ProgressionService.AddXP(player, amount, "Dev")
	elseif command == "night" then
		S.DayNightService.ForceNight(player)
	elseif command == "age" then
		S.LifecycleService.AgeAll(player, amount)
	elseif command == "hunger" then
		S.HungerService.Set(amount)
	elseif command == "feast" then
		S.FeastService.ForceStart()
	elseif command == "level" then
		-- Jump straight to a Garden Level (stages unlock as usual)
		local target = math.clamp(math.floor(amount), 1, 60)
		while data.GardenLevel < target do
			S.ProgressionService.AddXP(player, GameMath.XPToNext(data.GardenLevel) - data.GardenXP, "Dev")
		end
	elseif command == "test" then
		require(script.Parent.Parent.Tests.RunTests)()
	elseif command == "resetdata" then
		S.DataService.ResetData(player)
		print(`[Dev] {player.Name} profile reset. Stop and play again to start fresh.`)
	end
end

function DevCommands.Start()
	assert(RunService:IsStudio(), "DevCommands are Studio only")
	local function hook(player: Player)
		player.Chatted:Connect(function(message)
			handle(player, message)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	print("[Dev] Commands: /data, /coins <n>, /essence <n>, /xp <n>, /level <n>, /night, /age <n>, /hunger <n>, /feast, /test, /resetdata")
end

return DevCommands
