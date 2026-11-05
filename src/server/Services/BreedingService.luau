--!strict
-- BreedingService: breeding nests, pairing, gestation in play time, births, rare powers and the
-- Young training mini-game (Build Spec sections 12.2, 22.1). Two Adults of the same species and
-- opposite sex pair in a nest; after 900 play seconds a baby is born.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Creatures = require(ConfigFolder:WaitForChild("Creatures"))
local Defenses = require(ConfigFolder:WaitForChild("Defenses"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local S = require(script.Parent.Parent.Registry)
local Build = require(script.Parent.Parent.Build)

type NestSlot = { Id: string, Position: Vector3, Anchor: BasePart, Prompt: ProximityPrompt, Label: TextLabel?, Model: Model? }

local BreedingService = {}

local BREED = Config.Breeding
local TRAIN_MIN_TAPS = 15
local nestSlots: { [Player]: { [string]: NestSlot } } = {}

local function notify(player: Player, text: string)
	Remotes.Get("Notify"):FireClient(player, { Text = text })
end

local function slotIds(): { string }
	local ids = {}
	for index in Config.World.NestSpots do
		table.insert(ids, "nest_" .. index)
	end
	return ids
end

-- Nests --------------------------------------------------------------------------------------------------

local function refreshSlot(player: Player, data: any, slot: NestSlot, index: number)
	local record = data.Nests[slot.Id]
	local allowed = index <= GameMath.NestSlots(data)
	if record and slot.Model then
		Build.SetPrompt(slot.Prompt, nil)
	elseif record then
		local model = Instance.new("Model")
		model.Name = "Nest"
		local base = Build.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 5, 5), CFrame = CFrame.new(slot.Position + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(150, 110, 60), Material = Enum.Material.Fabric, Parent = model })
		local gui = Build.Billboard(base, 180, 28, 2.5)
		slot.Label = Build.Label(gui, "Empty nest")
		model.Parent = slot.Anchor
		slot.Model = model
		Build.SetPrompt(slot.Prompt, nil)
	elseif allowed and data.Unlocks.Nests then
		local nest = Defenses.ById.nest
		Build.SetPrompt(slot.Prompt, "Build Nest", S.EconomyService.CostText(nest.Cost), 0.5)
	else
		Build.SetPrompt(slot.Prompt, nil)
	end
end

local function refreshAll(player: Player)
	local data = S.DataService.GetData(player)
	local list = nestSlots[player]
	if not data or not list then
		return
	end
	for index, id in slotIds() do
		if list[id] then
			refreshSlot(player, data, list[id], index)
		end
	end
end

local function buildNest(player: Player, slotId: string)
	local data = S.DataService.GetData(player)
	local slot = nestSlots[player] and nestSlots[player][slotId]
	if not data or not slot or data.Nests[slotId] or not data.Unlocks.Nests then
		return
	end
	if not S.AntiExploit.WithinDistance(player, slot.Position, Config.Distance.Interact) then
		return
	end
	local index = table.find(slotIds(), slotId) or math.huge
	if index > GameMath.NestSlots(data) then
		notify(player, "Level up (or get the Extra Nest pass) for more nest slots.")
		return
	end
	if not S.EconomyService.Spend(player, Defenses.ById.nest.Cost) then
		return
	end
	data.Nests[slotId] = { SlotId = slotId }
	notify(player, "Nest built! Pair two adults in the Creatures menu.")
	S.ObjectiveService.Progress(player, "Build:nest")
	refreshAll(player)
	S.DataService.MarkChanged(player)
end

local function createSlots(player: Player, data: any)
	local plot = S.PlotService.GetPlot(player)
	if not plot then
		return
	end
	local list = {}
	nestSlots[player] = list
	for index, offset in Config.World.NestSpots do
		local id = "nest_" .. index
		local position = plot.Center + offset
		local anchor = Build.Part({ Name = id, Size = Vector3.one, Position = position + Vector3.new(0, 2, 0), Transparency = 1, Parent = plot.Folders.Buildings })
		local prompt = Build.Prompt(anchor, "Build Nest", "", { Distance = 10 })
		prompt.Triggered:Connect(function(who)
			if who == player then
				buildNest(player, id)
			end
		end)
		list[id] = { Id = id, Position = position, Anchor = anchor, Prompt = prompt }
	end
	refreshAll(player)
end

-- Where a breeding creature waits (CreatureService movement)
function BreedingService.GetNestPosition(player: Player, creatureId: string): Vector3?
	local data = S.DataService.GetData(player)
	local list = nestSlots[player]
	if not data or not list then
		return nil
	end
	for slotId, record in data.Nests do
		if (record.MotherId == creatureId or record.FatherId == creatureId) and list[slotId] then
			local side = if record.MotherId == creatureId then -1.5 else 1.5
			return list[slotId].Position + Vector3.new(side, 0, 2.5)
		end
	end
	return nil
end

-- Called when a creature leaves the garden: cancels any breeding it was part of
function BreedingService.ReleaseCreature(player: Player, creatureId: string)
	local data = S.DataService.GetData(player)
	if not data then
		return
	end
	for _, record in data.Nests do
		if record.MotherId == creatureId or record.FatherId == creatureId then
			record.MotherId, record.FatherId, record.StartedAt = nil, nil, nil
		end
	end
end

-- Breeding -------------------------------------------------------------------------------------------------

local function isRelated(a: any, b: any): boolean
	return a.ParentA == b.Id or a.ParentB == b.Id or b.ParentA == a.Id or b.ParentB == a.Id
end

local function inNest(data: any, creatureId: string): boolean
	for _, record in data.Nests do
		if record.MotherId == creatureId or record.FatherId == creatureId then
			return true
		end
	end
	return false
end

local function onStartBreeding(player: Player, data: any, firstId: any, secondId: any)
	if not data.Unlocks.Breeding or type(firstId) ~= "string" or type(secondId) ~= "string" or firstId == secondId then
		return
	end
	local a, b = data.Creatures[firstId], data.Creatures[secondId]
	if not a or not b then
		return
	end
	local function fail(text: string)
		notify(player, text)
	end
	if a.Stage ~= "Adult" or b.Stage ~= "Adult" then
		return fail("Both creatures must be Adults.")
	elseif a.Species ~= b.Species then
		return fail("Only the same species can breed.")
	elseif a.Sex == b.Sex then
		return fail("You need a boy and a girl.")
	elseif isRelated(a, b) then
		return fail("Parents and their children cannot breed.")
	elseif a.CaptiveAt or b.CaptiveAt or a.InjuredUntil ~= 0 or b.InjuredUntil ~= 0 then
		return fail("Both creatures must be home and healthy.")
	elseif inNest(data, a.Id) or inNest(data, b.Id) then
		return fail("One of them is already in a nest.")
	end
	for _, creature in { a, b } do
		local last = creature.LastBredAt or -math.huge
		if data.PlaySeconds - last < BREED.CooldownPlaySeconds then
			return fail(`{GameMath.CreatureName(creature)} needs {math.ceil((BREED.CooldownPlaySeconds - (data.PlaySeconds - last)) / 60)} more minutes of rest.`)
		end
	end
	if S.CreatureService.CountAll(data) >= Config.MaxCreatures then
		return fail(`Your garden is full ({Config.MaxCreatures} creatures).`)
	end
	local freeSlot = nil
	for _, slotId in slotIds() do
		local record = data.Nests[slotId]
		if record and not record.MotherId then
			freeSlot = record
			break
		end
	end
	if not freeSlot then
		return fail("Build an empty nest first (stage 4, near your creature area).")
	end
	local mother, father = if a.Sex == "Girl" then a else b, if a.Sex == "Girl" then b else a
	freeSlot.MotherId, freeSlot.FatherId, freeSlot.StartedAt = mother.Id, father.Id, data.PlaySeconds
	a.LastBredAt, b.LastBredAt = data.PlaySeconds, data.PlaySeconds
	notify(player, `{GameMath.CreatureName(mother)} and {GameMath.CreatureName(father)} are nesting!`)
	S.DataService.MarkChanged(player)
end

local function birth(player: Player, data: any, record: any)
	local mother, father = data.Creatures[record.MotherId], data.Creatures[record.FatherId]
	record.MotherId, record.FatherId, record.StartedAt = nil, nil, nil
	if not mother or not father then
		return
	end
	local legacy = S.LifecycleService.LegacyBonus(data, mother.BloodlineId)
	local traits = GameMath.BreedTraits(mother.Traits, father.Traits, legacy)
	local powers = {}
	local firstBaby = not data.TutorialDone.FirstBaby
	local powerChance = BREED.RarePowerChance + S.LifecycleService.SpiritBonus(data, mother.BloodlineId)
	if (firstBaby and BREED.FirstBabyRarePower) or Util.Chance(powerChance) then
		table.insert(powers, Creatures.RarePowers[Util.RandomInt(1, #Creatures.RarePowers)])
	end
	data.TutorialDone.FirstBaby = true

	local baby = S.CreatureService.NewCreature(mother.Species, {
		Stage = "Baby",
		Traits = traits,
		ParentA = mother.Id,
		ParentB = father.Id,
		BloodlineId = mother.BloodlineId,
		Generation = math.max(mother.Generation or 1, father.Generation or 1) + 1,
		Powers = powers,
	})
	S.CreatureService.AddCreature(player, baby)
	data.Stats.Babies = (data.Stats.Babies or 0) + 1

	local species = Creatures.ById[mother.Species]
	local powerText = if #powers > 0 then ` It has a rare power: {powers[1]}!` else ""
	Remotes.Get("UnlockBanner"):FireClient(player, { Title = `A baby {species.Name} was born!`, Text = `Generation {baby.Generation}.{powerText} Name it in the Creatures menu.`, Kind = "Creature" })
	S.ProgressionService.AddXP(player, Config.XPSources.BabyBorn, "Baby")
	S.ObjectiveService.Progress(player, "Baby")
	S.SeasonService.AddXP(player, Config.Season.XP.Baby)
end

-- Training mini-game: a Young or Baby creature gains +1 trait (shares the Young training cap)
local function onTrain(player: Player, data: any, creatureId: any, taps: any)
	local creature = type(creatureId) == "string" and data.Creatures[creatureId]
	if not creature or not data.Unlocks.Training or not S.AntiExploit.IsInteger(taps, 0, 200) then
		return
	end
	if creature.Stage ~= "Young" and creature.Stage ~= "Baby" then
		notify(player, "Only babies and young creatures can train.")
		return
	end
	local last = creature.LastTrainedAt or -math.huge
	if data.PlaySeconds - last < Config.Engagement.TrainingCooldownSeconds then
		notify(player, `{GameMath.CreatureName(creature)} is tired. Try again in {math.ceil((Config.Engagement.TrainingCooldownSeconds - (data.PlaySeconds - last)) / 60)} min.`)
		return
	end
	creature.LastTrainedAt = data.PlaySeconds
	if taps < TRAIN_MIN_TAPS then
		notify(player, "Keep tapping faster next time!")
	elseif (creature.TrainedTotal or 0) >= Config.Lifecycle.YoungTrainCap then
		notify(player, `{GameMath.CreatureName(creature)} has learned all it can from training.`)
	else
		local trait = Creatures.TraitKeys[Util.RandomInt(1, #Creatures.TraitKeys)]
		creature.Traits[trait] = math.min(Creatures.TraitMax, creature.Traits[trait] + 1)
		creature.TrainedTotal = (creature.TrainedTotal or 0) + 1
		notify(player, `Great training! {trait} +1`)
		S.ProgressionService.AddXP(player, 10, "Train")
		S.ObjectiveService.Progress(player, "Train")
	end
	S.DataService.MarkChanged(player)
end

function BreedingService.Init() end

function BreedingService.Start()
	S.DataService.ProfileLoaded:Connect(createSlots)
	Players.PlayerRemoving:Connect(function(player)
		nestSlots[player] = nil
	end)
	S.AntiExploit.Bind("StartBreeding", onStartBreeding)
	S.AntiExploit.Bind("TrainCreature", onTrain)

	task.spawn(function()
		while true do
			task.wait(1)
			for player, list in nestSlots do
				local data = S.DataService.GetData(player)
				if data then
					for slotId, record in data.Nests do
						local slot = list[slotId]
						if record.StartedAt then
							local left = BREED.GestationPlaySeconds - (data.PlaySeconds - record.StartedAt)
							if left <= 0 then
								birth(player, data, record)
							elseif slot and slot.Label then
								slot.Label.Text = string.format("Baby in %d:%02d", left // 60, left % 60)
							end
						elseif slot and slot.Label then
							slot.Label.Text = "Empty nest"
						end
					end
					-- Prompts follow level-ups and unlocks
					refreshAll(player)
				end
			end
		end
	end)
end

return BreedingService
