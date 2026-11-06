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
--   /pass <id>      turn a game pass on for testing (e.g. /pass pass_autoharvest)
--   /zoo            line up every creature and monster model to check which way they face
--   /test           run the formula unit tests (results in Output)
--   /resetdata      reset your profile to defaults (rejoin after)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameMath"))

local S = require(script.Parent.Parent.Registry)
local Assets = require(script.Parent.Parent.Assets)
local Build = require(script.Parent.Parent.Build)

local DevCommands = {}

-- /zoo: every Creature_ and Monster_ model in two rows in front of you, placed exactly as the game
-- places them. They should all LOOK AT YOU. Any that do not need a Turn in ModelFixes.luau.
local function zoo(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local folder = ReplicatedStorage:FindFirstChild("Models")
	if not root or not folder then
		return
	end
	local old = workspace:FindFirstChild("Zoo")
	if old then
		old:Destroy()
		return -- /zoo again removes it
	end
	local zooFolder = Instance.new("Folder")
	zooFolder.Name = "Zoo"
	zooFolder.Parent = workspace
	local rows: { { string } } = { {}, {} }
	for _, item in folder:GetChildren() do
		if string.sub(item.Name, 1, 9) == "Creature_" then
			table.insert(rows[1], item.Name)
		elseif string.sub(item.Name, 1, 8) == "Monster_" then
			table.insert(rows[2], item.Name)
		end
	end
	local ground = root.Position.Y - 3
	for r, names in rows do
		table.sort(names)
		for i, name in names do
			local side = (i - (#names + 1) / 2) * 8
			local p = root.Position + root.CFrame.LookVector * (14 + r * 10) + root.CFrame.RightVector * side
			p = Vector3.new(p.X, ground, p.Z)
			local facing = CFrame.lookAt(p, Vector3.new(root.Position.X, ground, root.Position.Z))
			local model = Assets.Place(name, facing, zooFolder, { Height = 4, AlignLength = true })
			local tag = Build.Part({ Size = Vector3.one, Position = p + Vector3.new(0, 6, 0), Transparency = 1, Parent = zooFolder })
			local gui = Build.Billboard(tag, 160, 30, 0)
			Build.Label(gui, if model then name else name .. " (skipped)")
		end
	end
	print("[Dev] /zoo: every model should LOOK AT YOU. Tell Claude the names of any that face sideways or away. Type /zoo again to remove them.")
	task.delay(180, function()
		if zooFolder.Parent then
			zooFolder:Destroy()
		end
	end)
end

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
	elseif command == "pass" then
		-- /pass pass_autoharvest : turn a pass on for testing (/pass alone lists the ids)
		if S.MonetizationService.TestGrantPass(player, arg) then
			print(`[Dev] {arg} is now on for {player.Name}`)
		else
			print("[Dev] Pass ids: pass_plot, pass_nest, pass_inventory, pass_autoharvest, pass_founder, pass_shoptheme, pass_grovetheme, pass_vipflair, pass_season")
		end
	elseif command == "zoo" then
		zoo(player)
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
