--!strict
-- ExploreService: forest regions with monster nests (Build Spec sections 8, 14; stages 8-9).
-- Guards appear when an eligible player comes near. Defeat them, then hold "Destroy Nest" to clear
-- it: rewards, exploration goods, a chance of a tamable monster egg, and fewer monsters at night.
-- Regions: Whisper Forest (Level 30), Echo Caves (33), Monster Territories (40), Ancient Moonlands (45).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Explore = require(ConfigFolder:WaitForChild("Explore"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local S = require(script.Parent.Parent.Registry)
local Build = require(script.Parent.Parent.Build)

type Nest = {
	Region: Explore.Region,
	Position: Vector3,
	Model: Model?,
	Prompt: ProximityPrompt?,
	Guards: { [string]: boolean },
	Active: boolean,
	Alive: boolean,
	RespawnAt: number,
	IdleSeconds: number,
}

local ExploreService = {}

local nests: { Nest } = {}
local folder: Folder

local function notify(player: Player, text: string)
	Remotes.Get("Notify"):FireClient(player, { Text = text })
end

local function canExplore(player: Player, region: Explore.Region): boolean
	local data = S.DataService.GetData(player)
	return data ~= nil and data.Unlocks[region.Feature] == true and data.GardenLevel >= region.MinLevel
end

local function buildRegion(region: Explore.Region)
	local center = region.Center
	Build.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, region.Radius * 2, region.Radius * 2), CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = region.Ground, Material = Enum.Material.Ground, CanCollide = true, Parent = folder })
	if region.Id == "caves" then
		-- Rocky ring
		for i = 1, 14 do
			local angle = i / 14 * math.pi * 2
			local height = 10 + (i % 3) * 4
			Build.Part({ Size = Vector3.new(10, height, 8), CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * region.Radius, height / 2, math.sin(angle) * region.Radius)) * CFrame.Angles(0, -angle, 0), Color = Color3.fromRGB(70, 70, 85), Material = Enum.Material.Slate, CanCollide = true, Parent = folder })
		end
	elseif region.Id == "moonlands" then
		for i = 1, 10 do
			local angle = i / 10 * math.pi * 2
			local crystal = Build.Part({ Size = Vector3.new(2, 8 + i % 4 * 2, 2), CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * region.Radius * 0.85, 4, math.sin(angle) * region.Radius * 0.85)) * CFrame.Angles(0.2, angle, 0.2), Color = Color3.fromRGB(150, 170, 255), Material = Enum.Material.Neon, Parent = folder })
			local light = Instance.new("PointLight")
			light.Color = crystal.Color
			light.Range = 14
			light.Parent = crystal
		end
	end
	local sign = Build.Part({ Size = Vector3.new(1, 8, 1), Position = center + Vector3.new(0, 4, 0), Color = Color3.fromRGB(90, 70, 50), Parent = folder })
	local gui = Build.Billboard(sign, 260, 54, 6)
	gui.MaxDistance = 300
	Build.Label(gui, `{region.Name}\nLevel {region.MinLevel}+`, { TextColor3 = Color3.fromRGB(255, 230, 160) })
end

local function rewardPlayer(player: Player, region: Explore.Region)
	local data = S.DataService.GetData(player)
	if not data then
		return
	end
	local reward = region.Reward
	local lines = { `+{reward.Coins} coins` }
	data.Coins += reward.Coins
	S.EconomyService.AddEssence(player, reward.Essence)
	table.insert(lines, `+{reward.Essence} Essence`)
	for key, qty in reward.Goods or {} do
		local room = GameMath.InventoryCapacity(data) - GameMath.GoodsCount(data)
		local given = math.min(qty, math.max(0, room))
		if given > 0 then
			data.Inventory.Goods[key] = (data.Inventory.Goods[key] or 0) + given
			table.insert(lines, `+{given} {GameMath.GoodsName(key)}`)
		end
	end
	for seed, qty in reward.Seeds or {} do
		data.Inventory.Seeds[seed] = (data.Inventory.Seeds[seed] or 0) + qty
		table.insert(lines, `+{qty} {seed} seed`)
	end
	if data.Unlocks.Taming and Util.Chance(reward.EggChance) and S.CreatureService.CountAll(data) < Config.MaxCreatures then
		local species = reward.EggPool[Util.RandomInt(1, #reward.EggPool)]
		S.CreatureService.GiveEgg(player, species, Explore.EggHatchSeconds, true)
		table.insert(lines, "a monster egg to tame!")
	end
	if reward.StarTouchedChance and Util.Chance(reward.StarTouchedChance) then
		local ids = {}
		for id, creature in data.Creatures do
			if not creature.CaptiveAt then
				table.insert(ids, id)
			end
		end
		if #ids > 0 then
			S.MutationService.Grant(player, ids[Util.RandomInt(1, #ids)], "StarTouched", "Moonlands discovery")
		end
	end
	-- Fewer monsters come from the forest after a nest is cleared
	data.NestPopulation = math.max(0, data.NestPopulation - Config.NestPopulation.ClearReduction)
	data.Stats.NestsCleared = (data.Stats.NestsCleared or 0) + 1
	S.ProgressionService.AddXP(player, 100, "Nest")
	S.ObjectiveService.Progress(player, "NestCleared")
	Remotes.Get("UnlockBanner"):FireClient(player, { Title = "Nest destroyed!", Text = table.concat(lines, ", "), Kind = "Stage" })
	S.DataService.MarkChanged(player)
end

local function refreshPrompt(nest: Nest)
	if nest.Prompt then
		if Util.CountKeys(nest.Guards) > 0 then
			Build.SetPrompt(nest.Prompt, nil)
		else
			Build.SetPrompt(nest.Prompt, "Destroy Nest", nest.Region.Name, nest.Region.NestHealth / 100)
		end
	end
end

local function despawnGuards(nest: Nest)
	for guardId in nest.Guards do
		S.MonsterService.Remove(guardId)
	end
	table.clear(nest.Guards)
	nest.Active = false
	refreshPrompt(nest)
end

local function destroyNest(player: Player, nest: Nest)
	if not nest.Alive or Util.CountKeys(nest.Guards) > 0 or not canExplore(player, nest.Region) then
		if not canExplore(player, nest.Region) then
			notify(player, `Reach Garden Level {nest.Region.MinLevel} and unlock this area first.`)
		end
		return
	end
	if not S.AntiExploit.WithinDistance(player, nest.Position, Config.Distance.Interact) then
		return
	end
	nest.Alive = false
	nest.Active = false
	nest.RespawnAt = os.clock() + Explore.RespawnSeconds
	if nest.Model then
		nest.Model:Destroy()
		nest.Model, nest.Prompt = nil, nil
	end
	-- Everyone eligible nearby shares the reward
	for _, other in Players:GetPlayers() do
		local root = S.AntiExploit.GetRootPosition(other)
		if root and (root - nest.Position).Magnitude <= 40 and canExplore(other, nest.Region) then
			rewardPlayer(other, nest.Region)
		end
	end
end

local function buildNest(nest: Nest)
	local model = Instance.new("Model")
	model.Name = "MonsterNest"
	local base = Build.Ball({ Size = Vector3.new(7, 7, 7), Position = nest.Position + Vector3.new(0, 1.5, 0), Color = Color3.fromRGB(80, 55, 45), Material = Enum.Material.Grass, CanCollide = true, Parent = model })
	local core = Build.Ball({ Size = Vector3.one * 2.4, Position = nest.Position + Vector3.new(0, 5, 0), Color = Color3.fromRGB(200, 60, 200), Material = Enum.Material.Neon, Parent = model })
	local light = Instance.new("PointLight")
	light.Color = core.Color
	light.Range = 14
	light.Parent = core
	local prompt = Build.Prompt(base, "Destroy Nest", nest.Region.Name, { Distance = 10, Hold = nest.Region.NestHealth / 100 })
	prompt.Triggered:Connect(function(player)
		destroyNest(player, nest)
	end)
	model.Parent = folder
	nest.Model, nest.Prompt = model, prompt
	refreshPrompt(nest)
end

local function activate(nest: Nest)
	nest.Active = true
	nest.IdleSeconds = 0
	local region = nest.Region
	local count = Util.RandomInt(region.GuardMin, region.GuardMax)
	for i = 1, count do
		local angle = i / count * math.pi * 2
		local typeId = region.Guards[Util.RandomInt(1, #region.Guards)]
		local guard = S.MonsterService.SpawnGuard(typeId, nest.Position + Vector3.new(math.cos(angle) * 9, 0, math.sin(angle) * 9), folder, {
			HealthMult = Explore.GuardHealthMult,
			OnKilled = function(monster: any)
				nest.Guards[monster.Id] = nil
				refreshPrompt(nest)
			end,
		})
		nest.Guards[guard.Id] = true
	end
	refreshPrompt(nest)
end

function ExploreService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Explore"
	folder.Parent = Workspace
	for _, region in Explore.Regions do
		buildRegion(region)
		for i = 1, region.NestCount do
			local angle = i / region.NestCount * math.pi * 2 + 0.4
			local nest: Nest = {
				Region = region,
				Position = region.Center + Vector3.new(math.cos(angle) * region.Radius * 0.55, 0, math.sin(angle) * region.Radius * 0.55),
				Guards = {},
				Active = false,
				Alive = true,
				RespawnAt = 0,
				IdleSeconds = 0,
			}
			buildNest(nest)
			table.insert(nests, nest)
		end
	end
end

function ExploreService.Start()
	task.spawn(function()
		while true do
			local dt = task.wait(1)
			for _, nest in nests do
				if not nest.Alive then
					if os.clock() >= nest.RespawnAt then
						nest.Alive = true
						buildNest(nest)
					end
				else
					local nearby = false
					for _, player in Players:GetPlayers() do
						local root = S.AntiExploit.GetRootPosition(player)
						if root and (root - nest.Position).Magnitude <= Explore.ActivateDistance and canExplore(player, nest.Region) then
							nearby = true
						end
					end
					if nearby and not nest.Active then
						activate(nest)
					elseif nest.Active and not nearby then
						-- Reset guards after a minute with nobody around
						nest.IdleSeconds += dt
						if nest.IdleSeconds >= 60 then
							despawnGuards(nest)
						end
					elseif nearby then
						nest.IdleSeconds = 0
					end
				end
			end
		end
	end)
end

return ExploreService
