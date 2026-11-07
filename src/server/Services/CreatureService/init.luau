--!strict
-- CreatureService: creature records, models, eggs, care (Fed, pet, feed), goods production,
-- roles, naming and recolors, shelter, monster targeting and injuries (Build Spec sections 7, 10.4).
-- Movement and creature fighting live in Behavior.luau; models in Models.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Creatures = require(ConfigFolder:WaitForChild("Creatures"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local S = require(script.Parent.Parent.Registry)
local Build = require(script.Parent.Parent.Build)
local Models = require(script.Models)
local Behavior = require(script.Behavior)

export type Runtime = {
	Model: Model,
	Body: BasePart,
	Size: number,
	Footprint: number?, -- half the width of the visible model, for spacing
	Position: Vector3,
	Facing: Vector3,
	Health: number,
	MaxHealth: number,
	Status: TextLabel,
	FedBar: Frame,
	PetPrompt: ProximityPrompt,
	FeedPrompt: ProximityPrompt,
	LastFed: number,
	AttackTimer: number,
	FarmTimer: number,
}

local CreatureService = {}

local runtimes: { [Player]: { [string]: Runtime } } = {}
local eggModels: { [Player]: { [string]: { Model: Model, Label: TextLabel } } } = {}

local function notify(player: Player, text: string)
	Remotes.Get("Notify"):FireClient(player, { Text = text })
end

local function banner(player: Player, title: string, text: string)
	Remotes.Get("UnlockBanner"):FireClient(player, { Title = title, Text = text, Kind = "Creature" })
end

function CreatureService.CountAdults(data: any): number
	local count = 0
	for _, creature in data.Creatures do
		if (creature.Stage == "Adult" or creature.Stage == "Elder") and not creature.CaptiveAt then
			count += 1
		end
	end
	return count
end

function CreatureService.CountAll(data: any): number
	return Util.CountKeys(data.Creatures) + Util.CountKeys(data.Eggs)
end

function CreatureService.GetRuntimes(player: Player): { [string]: Runtime }
	return runtimes[player] or {}
end

local function cheapestCropFood(data: any): string?
	local best, bestValue = nil, math.huge
	for key, count in data.Inventory.Goods do
		if count > 0 and GameMath.IsCropGoods(key) then
			local value = GameMath.SellValue(key)
			if value < bestValue then
				best, bestValue = key, value
			end
		end
	end
	return best
end

-- Models --------------------------------------------------------------------------------------------

local function despawnModel(player: Player, creatureId: string)
	local list = runtimes[player]
	local runtime = list and list[creatureId]
	if runtime then
		runtime.Model:Destroy()
		list[creatureId] = nil
	end
end

local function spawnModel(player: Player, creature: any)
	local plot = S.PlotService.GetPlot(player)
	local data = S.DataService.GetData(player)
	if not plot or not data or creature.CaptiveAt then
		return
	end
	local list = runtimes[player]
	if list == nil then
		list = {}
		runtimes[player] = list
	end
	local old = list[creature.Id]
	local position = if old then old.Position else plot.Center + Config.World.CreatureHome + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
	if old then
		old.Model:Destroy()
	end

	local parts = Models.Build(creature, data.Equipped.Glow)
	parts.PetPrompt.Triggered:Connect(function(who)
		if who == player then
			CreatureService.Pet(player, creature.Id)
		end
	end)
	parts.FeedPrompt.Triggered:Connect(function(who)
		if who == player then
			CreatureService.Feed(player, creature.Id)
		end
	end)
	parts.Model.Parent = plot.Folders.Creatures
	local maxHealth = GameMath.CreatureMaxHealth(creature)
	local runtime: Runtime = {
		Model = parts.Model,
		Body = parts.Body,
		Size = parts.Size,
		Footprint = parts.Footprint,
		Position = Vector3.new(position.X, Behavior.GroundY(parts.Size), position.Z),
		Facing = Vector3.new(0, 0, -1),
		Health = maxHealth,
		MaxHealth = maxHealth,
		Status = parts.Status,
		FedBar = parts.FedBar,
		PetPrompt = parts.PetPrompt,
		FeedPrompt = parts.FeedPrompt,
		LastFed = -1,
		AttackTimer = 0,
		FarmTimer = 0,
	}
	parts.Model:PivotTo(CFrame.new(runtime.Position))
	list[creature.Id] = runtime
end

-- Rebuild a creature's model (after a mutation, stage change, recolor or glow change)
function CreatureService.RefreshLook(player: Player, creatureId: string)
	local data = S.DataService.GetData(player)
	local creature = data and data.Creatures[creatureId]
	if creature then
		spawnModel(player, creature)
	end
end

function CreatureService.RefreshAllLooks(player: Player)
	local data = S.DataService.GetData(player)
	for id in (data and data.Creatures or {}) do
		CreatureService.RefreshLook(player, id)
	end
end

local function spawnEgg(player: Player, eggId: string)
	local plot = S.PlotService.GetPlot(player)
	if not plot then
		return
	end
	local list = eggModels[player]
	if list == nil then
		list = {}
		eggModels[player] = list
	end
	local model = Instance.new("Model")
	model.Name = "Egg"
	local index = Util.CountKeys(list)
	local position = plot.Center + Config.World.CreatureHome + Vector3.new(6 + (index % 4) * 3, 1.4, -6 - (index // 4) * 3)
	local shell = Build.Ball({ Size = Vector3.one * 2.2, Position = position, Color = Color3.fromRGB(255, 245, 210), Material = Enum.Material.Pebble, Parent = model })
	local gui = Build.Billboard(shell, 170, 30, 2.4)
	local label = Build.Label(gui, "Egg")
	model.Parent = plot.Folders.Creatures
	list[eggId] = { Model = model, Label = label }
end

-- Records ---------------------------------------------------------------------------------------------

export type NewOptions = { Bonded: boolean?, RobuxBought: boolean?, Name: string?, Stage: string?, Traits: any?, ParentA: string?, ParentB: string?, BloodlineId: string?, Generation: number?, Powers: { string }? }

function CreatureService.NewCreature(speciesId: string, options: NewOptions?): any
	local opts: NewOptions = options or {}
	local species = Creatures.ById[speciesId]
	local traits = opts.Traits
	if traits == nil then
		traits = {}
		for trait, range in species.Traits :: any do
			traits[trait] = Util.RandomInt(range.Min, range.Max)
		end
	end
	local creature = {
		Id = Util.NewId(),
		Species = speciesId,
		Sex = Creatures.Sexes[Util.RandomInt(1, #Creatures.Sexes)],
		Traits = traits,
		Role = nil,
		Stage = opts.Stage or "Adult",
		AgeMinutes = 0,
		Fed = Config.Fed.Start,
		Mutations = {},
		Powers = opts.Powers or {},
		ParentA = opts.ParentA,
		ParentB = opts.ParentB,
		BloodlineId = opts.BloodlineId or Util.NewId(),
		Generation = opts.Generation or 1,
		Bonded = opts.Bonded == true,
		RobuxBought = opts.RobuxBought == true,
		Stolen = false,
		HotUntil = 0,
		InjuredUntil = 0,
		Name = opts.Name,
		LastProducedAt = os.time(),
		BondXP = 0,
	}
	-- Hatched and gifted creatures start as adults; babies come from breeding
	creature.AgeMinutes = GameMath.StageStartMinutes(creature, creature.Stage)
	return creature
end

-- Adds an existing record (new, traded, bought or stolen) to a garden and spawns it
function CreatureService.AddCreature(player: Player, creature: any)
	local data = S.DataService.GetData(player)
	if not data then
		return
	end
	creature.InShelter = nil
	creature.InPen = nil
	data.Creatures[creature.Id] = creature
	spawnModel(player, creature)
	S.DataService.MarkChanged(player)
end

-- Removes a record from a garden (trade, sale, theft, death). Returns the record.
function CreatureService.RemoveCreature(player: Player, creatureId: string): any
	local data = S.DataService.GetData(player)
	local creature = data and data.Creatures[creatureId]
	if not data or not creature then
		return nil
	end
	data.Creatures[creatureId] = nil
	despawnModel(player, creatureId)
	S.BreedingService.ReleaseCreature(player, creatureId)
	S.DataService.MarkChanged(player)
	return creature
end

function CreatureService.GiveCreature(player: Player, speciesId: string, options: NewOptions?): any
	local data = S.DataService.GetData(player)
	if not data or not Creatures.ById[speciesId] then
		return nil
	end
	local creature = CreatureService.NewCreature(speciesId, options)
	CreatureService.AddCreature(player, creature)
	return creature
end

function CreatureService.GiveEgg(player: Player, speciesId: string, hatchSeconds: number, tamed: boolean?)
	local data = S.DataService.GetData(player)
	if not data then
		return
	end
	local eggId = Util.NewId()
	data.Eggs[eggId] = { Species = speciesId, HatchAt = os.time() + hatchSeconds, Tamed = tamed }
	spawnEgg(player, eggId)
	S.DataService.MarkChanged(player)
end

-- Section 22.2: a free Mystery Egg hatches at once into a common creature
function CreatureService.GiveMysteryEgg(player: Player)
	local pool = Creatures.MysteryEgg.Pool
	local creature = CreatureService.GiveCreature(player, pool[Util.RandomInt(1, #pool)])
	if creature then
		local traits = creature.Traits
		banner(player, `Mystery Egg: a {Creatures.ById[creature.Species].Name}!`, `Strength {traits.Str} - Intelligence {traits.Int} - Endurance {traits.End}. Breeding unlocks at Level 10.`)
	end
end

local function hatch(player: Player, data: any, eggId: string)
	local egg = data.Eggs[eggId]
	data.Eggs[eggId] = nil
	local models = eggModels[player]
	if models and models[eggId] then
		models[eggId].Model:Destroy()
		models[eggId] = nil
	end
	local creature = CreatureService.GiveCreature(player, egg.Species)
	if creature then
		local species = Creatures.ById[egg.Species]
		banner(player, `Your {species.Name} hatched!`, if species.Tamed then "A tamed monster! Give it the Guardian role to protect your garden." else "Keep it fed so it can work for you.")
		S.ObjectiveService.Progress(player, if egg.Tamed then "Tame" else "Hatch")
	end
end

-- Care ----------------------------------------------------------------------------------------------------

local function near(player: Player, creatureId: string): (any, Runtime?)
	local data = S.DataService.GetData(player)
	local runtime = runtimes[player] and runtimes[player][creatureId]
	local creature = data and data.Creatures[creatureId]
	if not creature or not runtime or not S.AntiExploit.WithinDistance(player, runtime.Position, Config.Distance.Interact) then
		return nil, nil
	end
	return creature, runtime
end

function CreatureService.Pet(player: Player, creatureId: string)
	local creature, runtime = near(player, creatureId)
	if not creature or not runtime then
		return
	end
	if not S.AntiExploit.TryCooldown(player, "Pet:" .. creatureId, Config.Engagement.PetCooldownSeconds) then
		notify(player, `{GameMath.CreatureName(creature)} is already happy!`)
		return
	end
	creature.Fed = math.min(Config.Fed.Max, creature.Fed + Config.Engagement.PetFedGain)
	creature.BondXP = (creature.BondXP or 0) + Config.Engagement.PetBondXP
	runtime.Model:SetAttribute("HappyAt", os.clock()) -- happy spin-jump on every player's screen
	notify(player, `{GameMath.CreatureName(creature)} loves you!`)
	S.ObjectiveService.Progress(player, "Pet")
	S.DataService.MarkChanged(player)
end

function CreatureService.Feed(player: Player, creatureId: string)
	local data = S.DataService.GetData(player)
	local creature = near(player, creatureId)
	if not data or not creature then
		return
	end
	local food = cheapestCropFood(data)
	if not food then
		notify(player, "Harvest a crop first to feed your creature.")
		return
	end
	if creature.Fed >= Config.Fed.Max then
		notify(player, `{GameMath.CreatureName(creature)} is full!`)
		return
	end
	data.Inventory.Goods[food] -= 1
	if data.Inventory.Goods[food] <= 0 then
		data.Inventory.Goods[food] = nil
	end
	creature.Fed = math.min(Config.Fed.Max, creature.Fed + Config.Fed.FeedAmount)
	notify(player, `Yum! {GameMath.CreatureName(creature)} ate a {GameMath.GoodsName(food)}.`)
	S.ObjectiveService.Progress(player, "Feed")
	S.DataService.MarkChanged(player)
end

-- Monster API ---------------------------------------------------------------------------------------------

export type TargetOptions = { IncludeEdible: boolean?, ForStalker: boolean? }

-- Creatures monsters may go after. Sheltered and captive creatures are never targets.
function CreatureService.GetTargets(player: Player, options: TargetOptions?): { { Id: string, Position: Vector3, Weight: number } }
	local data = S.DataService.GetData(player)
	local targets = {}
	if not data then
		return targets
	end
	local starving = S.HungerService.GetLevelName() == "Starving"
	for id, runtime in runtimes[player] or {} do
		local creature = data.Creatures[id]
		if creature and not creature.InShelter and not creature.CaptiveAt then
			local edible = options ~= nil and options.IncludeEdible == true and CreatureService.CanBeEaten(player, creature)
			local stalkable = options ~= nil and options.ForStalker == true and not GameMath.IsProtected(creature) and not creature.InPen
			local healthy = creature.InjuredUntil == 0
			if (options and options.ForStalker and stalkable) or (not (options and options.ForStalker) and (healthy or edible)) then
				local weight = Config.TargetWeights.Creature
				if starving and #creature.Mutations > 0 then
					weight *= Config.TargetWeights.StarvingRareMult
				end
				table.insert(targets, { Id = id, Position = runtime.Position, Weight = weight })
			end
		end
	end
	return targets
end

function CreatureService.GetPosition(player: Player, creatureId: string): Vector3?
	local runtime = runtimes[player] and runtimes[player][creatureId]
	return if runtime then runtime.Position else nil
end

function CreatureService.IsInjured(player: Player, creatureId: string): boolean
	local data = S.DataService.GetData(player)
	local creature = data and data.Creatures[creatureId]
	return creature ~= nil and creature.InjuredUntil ~= 0
end

-- Section 10.4: eaten only when Injured, from stage 5, without shield, not protected or sheltered
function CreatureService.CanBeEaten(player: Player, creature: any): boolean
	local data = S.DataService.GetData(player)
	return data ~= nil
		and creature.InjuredUntil ~= 0
		and data.Stage >= Config.Night.CreatureEatMinStage
		and data.ShieldNightsLeft <= 0
		and not creature.InShelter
		and not GameMath.IsProtected(creature)
end

-- Damage first, delete last: at 0 health a creature is only Injured
function CreatureService.Damage(player: Player, creatureId: string, amount: number): boolean
	local data = S.DataService.GetData(player)
	local list = runtimes[player]
	local runtime = list and list[creatureId]
	local creature = data and data.Creatures[creatureId]
	if not data or not creature or not runtime or creature.InjuredUntil ~= 0 then
		return false
	end
	amount *= Behavior.GuardianReduction(data, list :: any, creatureId, runtime.Position)
	runtime.Health -= amount
	if runtime.Health > 0 then
		return false
	end
	runtime.Health = 0
	creature.InjuredUntil = data.PlaySeconds + Config.InjuredSeconds
	notify(player, `{GameMath.CreatureName(creature)} is hurt and will rest for a while.`)
	S.DataService.MarkChanged(player)
	return true
end

function CreatureService.OnNightStart(player: Player)
	local data = S.DataService.GetData(player)
	for id, runtime in runtimes[player] or {} do
		local creature = data and data.Creatures[id]
		if creature then
			local bonus = if creature.Fed >= Config.Fed.NightBonusAtOrAbove then 1 + Config.Fed.NightHealthBonus else 1
			local elder = if creature.Stage == "Elder" then Config.Lifecycle.ElderDefenseMult else 1
			runtime.MaxHealth = GameMath.CreatureMaxHealth(creature) * bonus * elder
			if creature.InjuredUntil == 0 then
				runtime.Health = runtime.MaxHealth
			end
		end
	end
end

-- Hides or shows a creature while it is kidnapped (KidnapService owns the rules)
function CreatureService.SetCaptive(player: Player, creatureId: string, captive: boolean)
	local data = S.DataService.GetData(player)
	local creature = data and data.Creatures[creatureId]
	if not creature then
		return
	end
	creature.CaptiveAt = if captive then os.time() else nil
	if captive then
		despawnModel(player, creatureId)
		S.BreedingService.ReleaseCreature(player, creatureId)
	else
		creature.InjuredUntil = 0
		spawnModel(player, creature)
	end
	S.DataService.MarkChanged(player)
end

-- Remotes ---------------------------------------------------------------------------------------------------

local function ownCreature(data: any, creatureId: any): any
	if type(creatureId) ~= "string" then
		return nil
	end
	return data.Creatures[creatureId]
end

local function onSetRole(player: Player, data: any, creatureId: any, role: any)
	local creature = ownCreature(data, creatureId)
	if not creature or creature.CaptiveAt then
		return
	end
	if role == nil or role == "" then
		creature.Role = nil
	else
		local roleConfig = (Creatures.Roles :: any)[role]
		local species = Creatures.ById[creature.Species]
		if not roleConfig or not table.find(species.Roles, role) or data.Stage < roleConfig.Stage or not data.Unlocks.Jobs then
			notify(player, "That role is not available yet.")
			return
		end
		if creature.Stage == "Baby" then
			notify(player, "Babies are too young to work.")
			return
		end
		local last = creature.RoleChangedAt or -math.huge
		if data.PlaySeconds - last < Config.RoleChangeCooldownSeconds then
			notify(player, `Wait {math.ceil(Config.RoleChangeCooldownSeconds - (data.PlaySeconds - last))}s to change roles again.`)
			return
		end
		creature.Role = role
		creature.RoleChangedAt = data.PlaySeconds
	end
	notify(player, `{GameMath.CreatureName(creature)} is now {if creature.Role then "a " .. creature.Role else "resting"}.`)
	S.DataService.MarkChanged(player)
end

local function onSetShelter(player: Player, data: any, creatureId: any, inShelter: any)
	local creature = ownCreature(data, creatureId)
	if not creature or type(inShelter) ~= "boolean" then
		return
	end
	if inShelter then
		if not S.DefenseService.HasBuilding(player, "shelter") then
			notify(player, "Build a Shelter first.")
			return
		end
		local count = 0
		for _, other in data.Creatures do
			if other.InShelter then
				count += 1
			end
		end
		if count >= 4 then
			notify(player, "The Shelter is full (4 creatures).")
			return
		end
		creature.InPen = nil
	end
	creature.InShelter = inShelter or nil
	S.DataService.MarkChanged(player)
end

-- Babies can be named once for free; renaming otherwise uses a Rename token (dp_rename)
local function onRename(player: Player, data: any, creatureId: any, name: any)
	local creature = ownCreature(data, creatureId)
	if not creature or not S.AntiExploit.IsString(name, Creatures.MaxNameLength) then
		return
	end
	local free = creature.Name == nil and creature.Stage == "Baby"
	if not free and (data.Inventory.Items.rename or 0) <= 0 then
		notify(player, "You need a Rename token (see the Store).")
		return
	end
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(name, player.UserId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or type(filtered) ~= "string" or filtered == "" then
		notify(player, "That name could not be used. Try another.")
		return
	end
	-- The profile may have been released while filtering yielded
	if S.DataService.GetData(player) ~= data or data.Creatures[creature.Id] ~= creature then
		return
	end
	if not free then
		data.Inventory.Items.rename -= 1
	end
	creature.Name = filtered
	CreatureService.RefreshLook(player, creature.Id)
	notify(player, `Named {filtered}!`)
	S.DataService.MarkChanged(player)
end

local function onRecolor(player: Player, data: any, creatureId: any, colorIndex: any)
	local creature = ownCreature(data, creatureId)
	if not creature or not S.AntiExploit.IsInteger(colorIndex, 1, #Creatures.RecolorPalette) then
		return
	end
	if (data.Inventory.Items.recolor or 0) <= 0 then
		notify(player, "You need a Recolor token (see the Store).")
		return
	end
	data.Inventory.Items.recolor -= 1
	creature.ColorIndex = colorIndex
	CreatureService.RefreshLook(player, creature.Id)
	S.DataService.MarkChanged(player)
end

-- Loops ---------------------------------------------------------------------------------------------------------

local function produce(data: any, creature: any, now: number, capSeconds: number): number
	local species = Creatures.ById[creature.Species]
	local goods = species and species.Goods
	local working = creature.Role == nil or creature.Role == "Producer"
	if not goods or not working or creature.Stage == "Baby" or creature.CaptiveAt or creature.Fed < Config.Fed.StopWorkBelow or creature.InjuredUntil ~= 0 then
		creature.LastProducedAt = now
		return 0
	end
	local every = goods.EverySeconds / (if creature.Stage == "Elder" then Config.Lifecycle.ElderProductionMult else 1)
	local last = creature.LastProducedAt or now
	local elapsed = math.min(now - last, capSeconds)
	local count = GameMath.ProductionCount(now - last, capSeconds, every)
	if count <= 0 then
		creature.LastProducedAt = math.max(last, now - capSeconds)
		return 0
	end
	local resourceBonus = table.find(creature.Mutations, "ResourceBonus") ~= nil
	local extra = 0
	if resourceBonus then
		for _ = 1, count do
			if Util.Chance(0.15) then
				extra += 1
			end
		end
	end
	local room = GameMath.InventoryCapacity(data) - GameMath.GoodsCount(data)
	local made = math.max(0, math.min(count + extra, room))
	if made > 0 then
		data.Inventory.Goods[goods.Id] = (data.Inventory.Goods[goods.Id] or 0) + made
	end
	creature.LastProducedAt = now - (elapsed - count * every)
	return made
end

local function careTick(player: Player, data: any, dt: number)
	local now = os.time()
	local changed = false
	local food = cheapestCropFood(data)
	for id, creature in data.Creatures do
		local runtime = runtimes[player] and runtimes[player][id]
		local drain = Config.Fed.DrainAmount / Config.Fed.DrainIntervalSeconds * (1 + Config.Fed.StrDrainPer10 * creature.Traits.Str / 10)
		if not creature.CaptiveAt then
			creature.Fed = math.max(0, creature.Fed - drain * dt)
		end

		if creature.InjuredUntil ~= 0 and data.PlaySeconds >= creature.InjuredUntil then
			creature.InjuredUntil = 0
			if runtime then
				runtime.Health = runtime.MaxHealth
			end
			notify(player, `{GameMath.CreatureName(creature)} feels better!`)
			changed = true
		end

		local made = produce(data, creature, now, Config.OfflineProductionCapHours * 3600)
		if made > 0 then
			local goods = Creatures.ById[creature.Species].Goods
			notify(player, `{GameMath.CreatureName(creature)} made {made} {goods and goods.Name or "goods"}!`)
			changed = true
		end

		if runtime then
			local fed = math.floor(creature.Fed)
			if fed ~= runtime.LastFed then
				runtime.LastFed = fed
				changed = true
			end
			runtime.FedBar.Size = UDim2.fromScale(creature.Fed / Config.Fed.Max, 1)
			runtime.FedBar.BackgroundColor3 = if creature.Fed < Config.Fed.StopWorkBelow then Color3.fromRGB(240, 120, 60) else Color3.fromRGB(110, 220, 90)
			local status = creature.Role or ""
			if creature.InjuredUntil ~= 0 then
				status = `Resting {math.ceil(creature.InjuredUntil - data.PlaySeconds)}s`
			elseif creature.Fed < Config.Fed.StopWorkBelow then
				status = "Hungry! Needs care"
			elseif creature.InShelter then
				status = "In shelter"
			elseif creature.InPen then
				status = "In Heist Pen"
			end
			runtime.Status.Text = status
			Build.SetPrompt(runtime.FeedPrompt, if food then "Feed" else nil, `Fed {fed}%`)
		end
	end

	for eggId, egg in data.Eggs do
		local entry = eggModels[player] and eggModels[player][eggId]
		local left = egg.HatchAt - now
		if left <= 0 then
			hatch(player, data, eggId)
			changed = true
		elseif entry then
			entry.Label.Text = `{Creatures.ById[egg.Species].Name} egg - {left}s`
		end
	end

	if changed then
		S.DataService.MarkChanged(player)
	end
end

local function cleanup(player: Player)
	for _, runtime in runtimes[player] or {} do
		runtime.Model:Destroy()
	end
	for _, entry in eggModels[player] or {} do
		entry.Model:Destroy()
	end
	runtimes[player] = nil
	eggModels[player] = nil
end

function CreatureService.Init() end

function CreatureService.Start()
	S.DataService.ProfileLoaded:Connect(function(player: Player, data: any)
		runtimes[player] = runtimes[player] or {}
		if not data.TutorialDone.Starter then
			data.TutorialDone.Starter = true
			local starter = CreatureService.NewCreature(Creatures.StarterSpecies, { Bonded = true, Name = "Bun" })
			data.Creatures[starter.Id] = starter
		end
		-- Offline production (timestamp based, capped)
		local now = os.time()
		local made = 0
		for _, creature in data.Creatures do
			made += produce(data, creature, now, Config.OfflineProductionCapHours * 3600)
		end
		if made > 0 then
			task.delay(5, function()
				if player.Parent then
					notify(player, `While you were away your creatures made {made} goods!`)
				end
			end)
		end
		for _, creature in data.Creatures do
			spawnModel(player, creature)
		end
		for eggId in data.Eggs do
			spawnEgg(player, eggId)
		end
		S.DataService.MarkChanged(player)
	end)
	Players.PlayerRemoving:Connect(cleanup)

	S.AntiExploit.Bind("SetRole", onSetRole)
	S.AntiExploit.Bind("SetShelter", onSetShelter)
	S.AntiExploit.Bind("RenameCreature", onRename)
	S.AntiExploit.Bind("RecolorCreature", onRecolor)

	task.spawn(function()
		while true do
			local dt = task.wait(1)
			for player in runtimes do
				local data = S.DataService.GetData(player)
				if data then
					careTick(player, data, dt)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			local dt = task.wait(Config.CreatureMove.TickSeconds)
			local clock = os.clock()
			for player, list in runtimes do
				local data = S.DataService.GetData(player)
				local plot = S.PlotService.GetPlot(player)
				if data and plot then
					Behavior.Tick(player, data, plot, list :: any, dt, clock)
				end
			end
		end
	end)
end

return CreatureService
