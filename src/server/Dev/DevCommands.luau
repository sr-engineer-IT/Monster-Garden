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
--   /sandbox        everything at once: Level 45, coins, Essence, seeds, max plot, every creature, every defense
--   /follow         all your creatures follow you everywhere (type again to stop)
--   /attack         start the night and send one of every monster type to attack your garden
--   /gates wood|stone|iron|moon  put that gate type on all 4 sides of your garden
--   /parade         one of every monster walks in a circle around you (type again to stop)
--   /turn <n> <deg> try a direction fix live, e.g. /turn pip 90 (then tell Claude the number)
--   /zoo            line up every creature and monster model to check which way they face
--   /test           run the formula unit tests (results in Output)
--   /resetdata      reset your profile to defaults (rejoin after)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameMath"))
local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Crops = require(ConfigFolder:WaitForChild("Crops"))
local Creatures = require(ConfigFolder:WaitForChild("Creatures"))

local S = require(script.Parent.Parent.Registry)
local Assets = require(script.Parent.Parent.Assets)
local Build = require(script.Parent.Parent.Build)

local DevCommands = {}

-- /sandbox: everything at once for testing: Level 45 (all stages), lots of coins and Essence,
-- 20 of every seed, the biggest plot and best soil, one adult of every creature, and every
-- defense built. Your save is changed for real (in the Studio test save only): /resetdata to undo.
local function sandbox(player: Player, data: any)
	while data.GardenLevel < 45 do
		S.ProgressionService.AddXP(player, GameMath.XPToNext(data.GardenLevel) - data.GardenXP, "Dev")
	end
	data.Coins += 1000000
	data.Essence += 50000
	for _, crop in Crops.List do
		data.Inventory.Seeds[crop.Id] = (data.Inventory.Seeds[crop.Id] or 0) + 20
	end
	data.Plot.SizeIndex = #Config.PlotSizes
	while Crops.SoilUpgradeCost[data.Plot.SoilLevel + 1] do
		data.Plot.SoilLevel += 1
	end
	local owned: { [string]: boolean } = {}
	local count = 0
	for _, creature in data.Creatures do
		owned[creature.Species] = true
		count += 1
	end
	for _, species in Creatures.List do
		if not owned[species.Id] and count < Config.MaxCreatures then
			S.CreatureService.GiveCreature(player, species.Id, { Stage = "Adult" })
			count += 1
		end
	end
	S.PlotService.BuildTiles(player)
	local built = S.DefenseService.TestBuildAll(player)
	S.DataService.MarkChanged(player)
	print(`[Dev] /sandbox: Level {data.GardenLevel}, +1,000,000 coins, +50,000 Essence, seeds, max plot and soil, {count} creatures, {built} defenses built.`)
end

-- /parade: one of every monster walks in a slow circle around you (harmless). Type again to stop.
local paradeIds: { string } = {}
local function parade(player: Player)
	if #paradeIds > 0 then
		for _, id in paradeIds do
			S.MonsterService.Remove(id)
		end
		table.clear(paradeIds)
		print("[Dev] /parade removed")
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local kinds = { "swarmer", "brute", "trickster", "stalker", "alpha" }
	for i, kind in kinds do
		local monster = S.MonsterService.SpawnParade(kind, Vector3.new(root.Position.X, 0, root.Position.Z), (i - 1) / #kinds * math.pi * 2, 18)
		if monster then
			table.insert(paradeIds, monster.Id)
		end
	end
	print("[Dev] /parade: 5 monsters walk in a circle around you. Each should walk HEAD FIRST. Type /parade again to stop.")
end

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
			print("[Dev] Pass ids: pass_plot, pass_nest, pass_inventory, pass_autoharvest, pass_founder, pass_shoptheme, pass_grovetheme, pass_vipflair, pass_season, premium (Roblox Premium bonus)")
		end
	elseif command == "sandbox" then
		sandbox(player, data)
	elseif command == "follow" then
		local on = not player:GetAttribute("DevFollow")
		player:SetAttribute("DevFollow", on or nil)
		print(if on then "[Dev] /follow ON: all your creatures follow you. Type /follow again to stop." else "[Dev] /follow OFF")
	elseif command == "turn" then
		-- /turn <name> <degrees>: try a direction fix live, e.g. /turn pip 90 (tamed swarmer)
		local name, degrees = string.match(message, "^/turn%s+(%S+)%s+(%-?%d+)")
		local folder = ReplicatedStorage:FindFirstChild("Models")
		if not name or not folder then
			print("[Dev] Use: /turn <name> <degrees>   e.g. /turn pip 90   or   /turn Monster_brute 180")
			return
		end
		local full = if folder:FindFirstChild(name) then name elseif folder:FindFirstChild("Creature_" .. name) then "Creature_" .. name elseif folder:FindFirstChild("Monster_" .. name) then "Monster_" .. name else nil
		if not full then
			print(`[Dev] No model called {name}`)
			return
		end
		local fixes = require(ConfigFolder:WaitForChild("ModelFixes")) :: any
		fixes[full] = fixes[full] or {}
		fixes[full].Turn = tonumber(degrees)
		S.CreatureService.RefreshAllLooks(player)
		print(`[Dev] {full} is now turned {degrees} degrees (creatures update now; monsters on the next /parade or night). When it looks right, tell Claude: {full} = {degrees}`)
	elseif command == "attack" then
		-- /attack: start the night and send one of every monster type through your gates
		if not S.MonsterService.IsNight(player) then
			S.DayNightService.ForceNight(player)
		end
		task.spawn(function()
			for _ = 1, 120 do
				if S.MonsterService.TestSpawnAll(player) then
					print("[Dev] /attack: Swarmer (N gate), Brute (E), Trickster (S), Stalker (W) and an Elder Brute (N) are coming!")
					return
				end
				task.wait(0.5)
			end
			print("[Dev] /attack: night did not start, try /night first")
		end)
	elseif command == "gates" then
		-- /gates wood  or  /gates stone : all 4 garden gates become that type (to check directions)
		local id = if arg == "stone" or arg == "reinforced" then "reinforced_fence" elseif arg == "iron" then "iron_fence" elseif arg == "moon" then "moon_fence" else "wood_fence"
		local n = S.DefenseService.TestSetGates(player, id)
		print(`[Dev] /gates: {n} gates are now {id}. Walk to each side of your garden: the gate should close the gap in line with the fence.`)
	elseif command == "parade" then
		parade(player)
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
