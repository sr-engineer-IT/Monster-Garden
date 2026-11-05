--!strict
-- LifecycleService: aging in play time, life stages, Young training, Elder teaching, end-of-life
-- warnings, death of old age, Spirits, the Spirit Grove and Legacy Traits (Build Spec section 12.1).
-- Aging counts only while the owner is online. Before stage 7 aging stops at Adult.
-- Bonded and Robux creatures stop aging at Elder and never die.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Creatures = require(ConfigFolder:WaitForChild("Creatures"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local S = require(script.Parent.Parent.Registry)
local Build = require(script.Parent.Parent.Build)

local LifecycleService = {}

local LIFE = Config.Lifecycle
local groveModels: { [Player]: Folder } = {}

local function banner(player: Player, title: string, text: string)
	Remotes.Get("UnlockBanner"):FireClient(player, { Title = title, Text = text, Kind = "Creature" })
end

local function addTrait(creature: any, field: string, cap: number): boolean
	if (creature[field] or 0) >= cap then
		return false
	end
	local trait = Creatures.TraitKeys[Util.RandomInt(1, #Creatures.TraitKeys)]
	creature.Traits[trait] = math.min(Creatures.TraitMax, creature.Traits[trait] + 1)
	creature[field] = (creature[field] or 0) + 1
	return true
end

-- Spirits and Legacy Traits ------------------------------------------------------------------------

-- +2% mutation chance per Spirit of the bloodline, capped at +20%
function LifecycleService.SpiritBonus(data: any, bloodlineId: string): number
	local count = 0
	for _, spirit in data.Spirits do
		if spirit.BloodlineId == bloodlineId then
			count += 1
		end
	end
	return math.min(LIFE.SpiritMutationBonusCap, count * LIFE.SpiritMutationBonus)
end

-- Offspring get +2 on each ancestor's Legacy Trait per Spirit (cap +10 per trait)
function LifecycleService.LegacyBonus(data: any, bloodlineId: string): { [string]: number }
	local bonus = { Str = 0, Int = 0, End = 0 }
	for _, spirit in data.Spirits do
		if spirit.BloodlineId == bloodlineId then
			bonus[spirit.LegacyTrait] = math.min(LIFE.LegacyTraitCap, bonus[spirit.LegacyTrait] + LIFE.LegacyTraitPerSpirit)
		end
	end
	return bonus
end

function LifecycleService.RefreshGrove(player: Player)
	local plot = S.PlotService.GetPlot(player)
	local data = S.DataService.GetData(player)
	if not plot or not data then
		return
	end
	if groveModels[player] then
		groveModels[player]:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "SpiritGrove"
	folder.Parent = plot.Folders.Buildings
	groveModels[player] = folder

	local unlocked = data.Unlocks.Spirit == true
	local count = Util.CountKeys(data.Spirits)
	if plot.GroveLabel then
		plot.GroveLabel.Text = if unlocked then `Spirit Grove\n{count} Spirit{if count == 1 then "" else "s"}` else "Spirit Grove\nUnlocks at Level 25"
	end
	if not unlocked then
		return
	end
	local themed = data.Purchases.PassesOwned.pass_grovetheme
	local color = if themed then Color3.fromRGB(255, 230, 150) else Color3.fromRGB(170, 210, 255)
	local index = 0
	for _, spirit in data.Spirits do
		index += 1
		local angle = index * 0.9
		local radius = 4 + (index // 7) * 2.5
		local position = plot.Center + Config.World.SpiritGateOffset + Vector3.new(math.cos(angle) * radius + 4, 3 + (index % 3) * 0.6, math.sin(angle) * radius + 4)
		local orb = Build.Ball({ Size = Vector3.one * 1.4, Position = position, Color = color, Material = Enum.Material.Neon, Transparency = 0.25, Parent = folder })
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 8
		light.Parent = orb
		local gui = Build.Billboard(orb, 140, 26, 1.6)
		gui.MaxDistance = 40
		Build.Label(gui, `{spirit.Name} ({spirit.LegacyTrait})`)
	end
end

local function becomeSpirit(player: Player, data: any, creature: any)
	local best, bestValue = "Str", -1
	for _, trait in Creatures.TraitKeys do
		if creature.Traits[trait] > bestValue then
			best, bestValue = trait, creature.Traits[trait]
		end
	end
	local name = GameMath.CreatureName(creature)
	local spiritId = Util.NewId()
	data.Spirits[spiritId] = {
		Id = spiritId,
		BloodlineId = creature.BloodlineId,
		LegacyTrait = best,
		Species = creature.Species,
		Name = name,
		Mutations = table.clone(creature.Mutations),
	}
	S.CreatureService.RemoveCreature(player, creature.Id)
	banner(player, `Farewell, {name}`, `{name} became a Spirit in your Spirit Grove. Its bloodline gains +2% mutation chance and the Legacy Trait {best}.`)
	LifecycleService.RefreshGrove(player)
	S.ObjectiveService.Progress(player, "Spirit")
end

-- Aging -------------------------------------------------------------------------------------------------

local function ageCreature(player: Player, data: any, creature: any, minutes: number)
	local elderEnabled = data.Unlocks.Elder == true
	local elderStart = GameMath.StageStartMinutes(creature, "Elder")
	local lifespan = GameMath.Lifespan(creature)
	local protected = GameMath.IsProtected(creature)
	local wasStage = creature.Stage
	local wasAge = creature.AgeMinutes

	creature.AgeMinutes += minutes
	if not elderEnabled or protected then
		-- Stop at Adult before stage 7; protected creatures stop at Elder and never die
		local limit = if elderEnabled then elderStart else elderStart - 0.01
		creature.AgeMinutes = math.min(creature.AgeMinutes, math.max(limit, wasAge))
	end

	-- Young creatures train themselves: +1 trait per 30 play minutes (cap +5)
	if creature.Stage == "Young" then
		local before = wasAge // LIFE.YoungTrainEveryMinutes
		local after = creature.AgeMinutes // LIFE.YoungTrainEveryMinutes
		for _ = 1, after - before do
			addTrait(creature, "TrainedTotal", LIFE.YoungTrainCap)
		end
	end

	local stage = GameMath.LifeStageFor(creature, elderEnabled)
	if stage ~= wasStage then
		creature.Stage = stage
		S.CreatureService.RefreshLook(player, creature.Id)
		local text = if stage == "Adult" then "It can now work, breed and defend." elseif stage == "Elder" then "Elders make fewer goods but teach babies nearby." else "Young creatures train their traits as they grow."
		banner(player, `{GameMath.CreatureName(creature)} is now {if stage == "Elder" then "an" else "a"} {stage}!`, text)
		if stage == "Adult" then
			S.ProgressionService.CheckStage(player)
		end
	end

	if not elderEnabled or protected then
		return
	end
	local share = creature.AgeMinutes / lifespan
	if share >= LIFE.WarnAtShare and not creature.Warned then
		creature.Warned = true
		banner(player, `{GameMath.CreatureName(creature)} is nearing the end of its life`, `About {math.ceil(lifespan - creature.AgeMinutes)} play minutes left. Breed it now to keep its bloodline going.`)
	end
	if share >= 1 then
		becomeSpirit(player, data, creature)
	end
end

local function tick(player: Player, data: any, minutes: number)
	local hasElder = false
	for _, creature in data.Creatures do
		if creature.Stage == "Elder" and not creature.CaptiveAt then
			hasElder = true
		end
	end
	for _, creature in data.Creatures do
		if not creature.CaptiveAt then
			-- Elders teach babies: +1 trait per hour (cap +5)
			if hasElder and creature.Stage == "Baby" then
				local before = creature.AgeMinutes // 60
				local after = (creature.AgeMinutes + minutes) // 60
				if after > before then
					addTrait(creature, "TaughtTotal", LIFE.ElderTeachCap)
				end
			end
			ageCreature(player, data, creature, minutes)
		end
	end
	S.DataService.MarkChanged(player)
end

-- Studio testing: age every creature of a player by some play minutes
function LifecycleService.AgeAll(player: Player, minutes: number)
	local data = S.DataService.GetData(player)
	if data then
		tick(player, data, minutes)
	end
end

-- Surviving a night with Moonlit extends life: +10 minutes, capped at +20% of base lifespan
function LifecycleService.OnNightSurvived(player: Player)
	local data = S.DataService.GetData(player)
	if not data then
		return
	end
	for _, creature in data.Creatures do
		if table.find(creature.Mutations, "Moonlit") then
			local base = LIFE.BaseLifespanMinutes + creature.Traits.End * LIFE.LifespanPerEndurance
			creature.ExtendMinutes = math.min(base * LIFE.MoonlitExtendCapShare, (creature.ExtendMinutes or 0) + LIFE.MoonlitNightExtendMinutes)
		end
	end
end

function LifecycleService.Init() end

function LifecycleService.Start()
	S.DataService.ProfileLoaded:Connect(function(player: Player, data: any)
		-- Fix stages saved by older versions
		for _, creature in data.Creatures do
			creature.Stage = GameMath.LifeStageFor(creature, data.Unlocks.Elder == true)
		end
		LifecycleService.RefreshGrove(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		groveModels[player] = nil
	end)

	task.spawn(function()
		while true do
			local elapsed = task.wait(LIFE.AgeTickSeconds)
			for _, player in Players:GetPlayers() do
				local data = S.DataService.GetData(player)
				if data then
					local ok, err = pcall(tick, player, data, elapsed / 60)
					if not ok then
						warn(`[LifecycleService] {player.Name}: {err}`)
					end
				end
			end
		end
	end)
end

return LifecycleService
