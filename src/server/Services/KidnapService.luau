--!strict
-- KidnapService: Monster Kidnapping (Build Spec section 14.1, stage 7). A Stalker grabs a creature
-- and runs for the forest. Dealing 120 damage to it drops the creature (+8 Essence, +12 XP). If it
-- escapes, the creature waits in a Rescue Nest outside the west gate guarded by 3-5 Swarmers;
-- defeat them and free the creature to earn the Escaped mutation. A creature is never lost here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local S = require(script.Parent.Parent.Registry)
local Build = require(script.Parent.Parent.Build)

type RescueNest = { Model: Model, Prompt: ProximityPrompt, Guards: { [string]: boolean }, Position: Vector3 }

local KidnapService = {}

local KIDNAP = Config.Kidnap
local nests: { [Player]: { [string]: RescueNest } } = {}

local function banner(player: Player, title: string, text: string, kind: string?)
	Remotes.Get("UnlockBanner"):FireClient(player, { Title = title, Text = text, Kind = kind or "Warning" })
end

local function nestPosition(player: Player, index: number): Vector3?
	local plot = S.PlotService.GetPlot(player)
	if not plot then
		return nil
	end
	local gate = plot.Center + Config.World.Gates.W
	return gate + Vector3.new(-Config.World.RescueNestOutside, 0, (index - 1) * 14 - 14)
end

local function refreshPrompt(nest: RescueNest, creatureName: string)
	local guardsLeft = Util.CountKeys(nest.Guards)
	if guardsLeft > 0 then
		Build.SetPrompt(nest.Prompt, nil)
	else
		Build.SetPrompt(nest.Prompt, `Free {creatureName}`, "Rescue Nest", 1)
	end
end

local function removeNest(player: Player, creatureId: string)
	local list = nests[player]
	local nest = list and list[creatureId]
	if not nest then
		return
	end
	for guardId in nest.Guards do
		S.MonsterService.Remove(guardId)
	end
	nest.Model:Destroy()
	list[creatureId] = nil
end

local function rescue(player: Player, creatureId: string)
	local data = S.DataService.GetData(player)
	local list = nests[player]
	local nest = list and list[creatureId]
	local creature = data and data.Creatures[creatureId]
	if not data or not nest or not creature or Util.CountKeys(nest.Guards) > 0 then
		return
	end
	if not S.AntiExploit.WithinDistance(player, nest.Position, Config.Distance.Interact) then
		return
	end
	removeNest(player, creatureId)
	S.CreatureService.SetCaptive(player, creatureId, false)
	S.MutationService.Grant(player, creatureId, "Escaped", "Rescued from a monster nest")
	S.ProgressionService.AddXP(player, Config.XPSources.RescueCreature, "Rescue")
	banner(player, `{GameMath.CreatureName(creature)} is free!`, "It earned the Escaped mutation (+5 Endurance).", "Creature")
end

local function buildNest(player: Player, creatureId: string)
	local data = S.DataService.GetData(player)
	local plot = S.PlotService.GetPlot(player)
	local creature = data and data.Creatures[creatureId]
	if not data or not plot or not creature then
		return
	end
	local list = nests[player]
	if list == nil then
		list = {}
		nests[player] = list
	end
	if list[creatureId] then
		return
	end
	local position = nestPosition(player, Util.CountKeys(list) + 1) :: Vector3
	local model = Instance.new("Model")
	model.Name = "RescueNest"
	local base = Build.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, 9, 9), CFrame = CFrame.new(position + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(70, 50, 60), Material = Enum.Material.Slate, Parent = model })
	local cage = Build.Ball({ Size = Vector3.one * 3, Position = position + Vector3.new(0, 3, 0), Color = Color3.fromRGB(255, 240, 150), Material = Enum.Material.ForceField, Parent = model })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 240, 150)
	light.Range = 18
	light.Parent = cage
	local gui = Build.Billboard(base, 220, 40, 6)
	gui.MaxDistance = 200
	Build.Label(gui, `Rescue {GameMath.CreatureName(creature)}!\nDefeat the guards`, { TextColor3 = Color3.fromRGB(255, 220, 140) })
	model.Parent = plot.Folders.Buildings

	local prompt = Build.Prompt(cage, "Free", "Rescue Nest", { Distance = 10 })
	local nest: RescueNest = { Model = model, Prompt = prompt, Guards = {}, Position = position }
	list[creatureId] = nest
	prompt.Triggered:Connect(function(who)
		if who == player then
			rescue(player, creatureId)
		end
	end)

	local name = GameMath.CreatureName(creature)
	for i = 1, Util.RandomInt(KIDNAP.NestGuardsMin, KIDNAP.NestGuardsMax) do
		local angle = i * 2 * math.pi / KIDNAP.NestGuardsMax
		local guard = S.MonsterService.SpawnGuard("swarmer", position + Vector3.new(math.cos(angle) * 6, 0, math.sin(angle) * 6), plot.Folders.Monsters, {
			OnKilled = function(monster: any)
				nest.Guards[monster.Id] = nil
				refreshPrompt(nest, name)
			end,
		})
		nest.Guards[guard.Id] = true
	end
	refreshPrompt(nest, name)
end

-- Monster hooks ------------------------------------------------------------------------------------------

-- A Stalker reached a creature. Returns true when it may carry it off.
function KidnapService.OnGrab(player: Player, creatureId: string): boolean
	local data = S.DataService.GetData(player)
	local creature = data and data.Creatures[creatureId]
	if not data or not creature or not data.Unlocks.Kidnap or GameMath.IsProtected(creature) or creature.InShelter or creature.CaptiveAt then
		return false
	end
	S.CreatureService.SetCaptive(player, creatureId, true)
	banner(player, `{GameMath.CreatureName(creature)} was grabbed!`, "Chase the glowing Stalker and hit it before it reaches the forest!")
	return true
end

function KidnapService.OnDropped(player: Player, creatureId: string, attacker: Player?)
	local data = S.DataService.GetData(player)
	local creature = data and data.Creatures[creatureId]
	if not creature then
		return
	end
	S.CreatureService.SetCaptive(player, creatureId, false)
	local hero = attacker or player
	S.EconomyService.AddEssence(hero, KIDNAP.RescueEssence)
	S.ProgressionService.AddXP(hero, KIDNAP.RescueXP, "Rescue")
	banner(player, `{GameMath.CreatureName(creature)} is safe!`, `The Stalker dropped it. +{KIDNAP.RescueEssence} Essence`, "Creature")
end

function KidnapService.OnEscaped(player: Player, creatureId: string)
	local data = S.DataService.GetData(player)
	local creature = data and data.Creatures[creatureId]
	if not creature then
		return
	end
	buildNest(player, creatureId)
	banner(player, `The Stalker escaped with {GameMath.CreatureName(creature)}`, "It is safe in a Rescue Nest outside your west gate. Defeat the guards to free it.")
end

function KidnapService.Init() end

function KidnapService.Start()
	S.DataService.ProfileLoaded:Connect(function(player: Player, data: any)
		for id, creature in data.Creatures do
			if creature.CaptiveAt then
				buildNest(player, id)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for creatureId in nests[player] or {} do
			removeNest(player, creatureId)
		end
		nests[player] = nil
	end)
end

return KidnapService
