--!strict
-- MonsterService: night waves per garden, damage and rewards, plus nest guards and the Feast
-- Night Alpha (Build Spec sections 8, 10, 11, 14). Behavior lives in AI.luau, models in Models.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Creatures = require(ConfigFolder:WaitForChild("Creatures"))
local Monsters = require(ConfigFolder:WaitForChild("Monsters"))
local Shop = require(ConfigFolder:WaitForChild("Shop"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local S = require(script.Parent.Parent.Registry)
local Models = require(script.Models)
local AI = require(script.AI)

export type Night = {
	Number: number,
	WaveBudget: number,
	Bank: number,
	WavesLeft: number,
	WaveTimer: number,
	Spawned: number,
	Repelled: number,
	Killed: number,
	Ate: number,
	CreaturesLost: number,
	PlannedGate: string?,
	Alerted: boolean,
}

type Garden = { Monsters: { [string]: any }, Night: Night? }

local MonsterService = {}

local gardens: { [Player]: Garden } = {}
local allMonsters: { [string]: any } = {}
local plannedGates: { [Player]: string } = {}
local GATES = { "N", "E", "S", "W" }

local function notify(player: Player, text: string)
	Remotes.Get("Notify"):FireClient(player, { Text = text })
end

local function getGarden(player: Player): Garden
	local garden = gardens[player]
	if garden == nil then
		garden = { Monsters = {}, Night = nil }
		gardens[player] = garden
	end
	return garden
end

local function updateAliveCount(player: Player?)
	if not player then
		return
	end
	local garden = gardens[player]
	local count = 0
	for _, monster in garden and garden.Monsters or {} do
		if monster.State ~= "Retreat" then
			count += 1
		end
	end
	player:SetAttribute("MonstersAlive", count)
end

local function hungerFor(player: Player): any?
	local data = S.DataService.GetData(player)
	if data and data.Unlocks.Hunger and S.HungerService.IsActive() then
		return GameMath.HungerLevel(S.HungerService.GetValue())
	end
	return nil
end

-- Spawning --------------------------------------------------------------------------------------

export type SpawnOptions = {
	Kind: string?, -- "Night" (default), "Guard", "Alpha"
	Elder: boolean?,
	Position: Vector3?,
	Gate: string?,
	HealthMult: number?,
	Health: number?,
	Folder: Instance?,
	OnKilled: ((monster: any, attacker: Player?) -> ())?,
}

local function create(owner: Player?, typeId: string, options: SpawnOptions): any
	local def = if typeId == "alpha" then { Id = "alpha", Name = "Alpha", Speed = Monsters.Alpha.Speed, DamagePerSecond = Monsters.Alpha.DamagePerSecond, Health = Monsters.Alpha.HealthBase, XP = Monsters.Alpha.XP, Essence = 0 } else Monsters.ById[typeId]
	local elder = options.Elder == true
	local id = Util.NewId()
	local str = Util.RandomInt(Monsters.Traits.RandomMin, Monsters.Traits.RandomMax)
	local endurance = Util.RandomInt(Monsters.Traits.RandomMin, Monsters.Traits.RandomMax)
	local int = Util.RandomInt(Monsters.Traits.RandomMin, Monsters.Traits.RandomMax)
	local plot = if owner then S.PlotService.GetPlot(owner) else nil
	local folder = options.Folder or (plot and plot.Folders.Monsters) or workspace
	local model, body, fill, size = Models.Build(typeId, def.Name, id, elder, folder)

	local health = options.Health or (def.Health * (Monsters.Traits.HealthBase + endurance / Monsters.Traits.Divisor))
	health *= (options.HealthMult or 1) * (if elder then Monsters.Elder.HealthMult else 1)
	local damage = def.DamagePerSecond * (Monsters.Traits.DamageBase + str / Monsters.Traits.Divisor) * (if elder then Monsters.Elder.DamageMult else 1)
	local ability = if elder then Monsters.Elder.AbilityOrder[Util.RandomInt(1, #Monsters.Elder.AbilityOrder)] else nil
	local speed = def.Speed * (if ability == "Frenzied" then Monsters.Elder.Abilities.Frenzied.SpeedMult else 1)
	if owner then
		local hunger = hungerFor(owner)
		speed *= if hunger then hunger.Speed else 1
	end
	local position = options.Position or Vector3.zero
	position = Vector3.new(position.X, Config.World.GroundY + 0.2 + size / 2, position.Z)

	local monster = {
		Id = id,
		Def = def,
		Kind = options.Kind or "Night",
		Owner = owner,
		Model = model,
		Body = body,
		BodyColor = body.Color,
		HealthFill = fill,
		Size = size,
		Position = position,
		Facing = Vector3.new(0, 0, -1),
		Spawn = position,
		Anchor = position,
		Gate = options.Gate or "N",
		Health = health,
		MaxHealth = health,
		DamageTaken = 0,
		Damage = damage,
		Speed = speed,
		Int = int,
		Elder = elder,
		Ability = ability,
		CanEat = def.CanEat == true or elder,
		State = "Approach",
		Timer = 0,
		LightChecked = false,
		TrapChecked = {},
		Contrib = {},
		OnKilled = options.OnKilled,
	}
	model:PivotTo(CFrame.new(position))
	allMonsters[id] = monster
	return monster
end

local function spawnNightMonster(player: Player, garden: Garden, typeId: string, gate: string, elder: boolean?)
	local plot = S.PlotService.GetPlot(player)
	local gatePosition = S.DefenseService.GetGatePosition(player, gate)
	local night = garden.Night
	if not plot or not gatePosition or not night then
		return
	end
	local outward = Vector3.new(gatePosition.X - plot.Center.X, 0, gatePosition.Z - plot.Center.Z).Unit
	local lateral = Vector3.new(-outward.Z, 0, outward.X) * Util.RandomInt(-6, 6)
	local monster = create(player, typeId, { Gate = gate, Elder = elder, Position = gatePosition + outward * Config.World.MonsterSpawnOutside + lateral })
	monster.Facing = -outward
	garden.Monsters[monster.Id] = monster
	night.Spawned += 1

	local data = S.DataService.GetData(player)
	if data and typeId == "brute" and not data.TutorialDone.FirstBrute then
		data.TutorialDone.FirstBrute = true
		Remotes.Get("UnlockBanner"):FireClient(player, { Title = "Something big is coming!", Text = "A Brute breaks fences fast. Fight it before it reaches your creatures!", Kind = "Warning" })
	end
	if not night.Alerted and (typeId == "brute" or elder or Util.CountKeys(garden.Monsters) >= 8) then
		night.Alerted = true
		S.SocialService.NeighborAlert(player)
	end
end

local function nightBudget(data: any): number
	local hunger = if data.Unlocks.Hunger and S.HungerService.IsActive() then S.HungerService.GetValue() else nil
	return GameMath.WaveBudget(data, hunger)
end

local function pickGate(player: Player, typeId: string): string
	local planned = plannedGates[player]
	if planned then
		plannedGates[player] = nil
		return planned
	end
	if Monsters.ById[typeId] and Monsters.ById[typeId].PrefersUndefendedSide then
		local open = {}
		for _, gate in GATES do
			if not S.DefenseService.IsGateBlocked(player, gate) then
				table.insert(open, gate)
			end
		end
		if #open > 0 then
			return open[Util.RandomInt(1, #open)]
		end
	end
	return GATES[Util.RandomInt(1, #GATES)]
end

local function spawnWave(player: Player, garden: Garden, data: any)
	local night = garden.Night :: Night
	if night.Number == 1 then
		-- Night 1 is fixed: exactly 3 Swarmers, no budget
		local gate = pickGate(player, "swarmer")
		for _ = 1, Config.Night.FirstNightSwarmers do
			spawnNightMonster(player, garden, "swarmer", gate)
		end
		night.WavesLeft = 0
		return
	end

	night.Bank += night.WaveBudget
	local starving = S.HungerService.GetLevelName() == "Starving" and data.Unlocks.Hunger
	local weights: { [string]: number } = {}
	for _, def in Monsters.List do
		if def.Stage <= data.Stage and night.Number >= def.FirstNight then
			weights[def.Id] = def.SpawnWeight * (if def.Grabs and starving then Config.Hunger.StarvingStalkerMult else 1)
		end
	end
	if data.Stage >= Monsters.Elder.Stage and night.Number >= Monsters.Elder.FirstNight then
		weights.elder = Monsters.Elder.SpawnWeight
	end

	local alive = Util.CountKeys(garden.Monsters)
	while alive < Config.Night.MaxMonstersAlivePerGarden do
		local affordable: { [string]: number } = {}
		for typeId, weight in weights do
			local cost = if typeId == "elder" then Monsters.Elder.WaveCost else Monsters.ById[typeId].WaveCost
			if cost <= night.Bank then
				affordable[typeId] = weight
			end
		end
		local typeId = Util.WeightedPick(affordable)
		if typeId == nil then
			break
		end
		local elder = typeId == "elder"
		if elder then
			-- An Elder is a long-lived version of a base monster
			typeId = ({ "swarmer", "brute", "trickster" })[Util.RandomInt(1, if data.Stage >= 5 then 3 else 2)]
		end
		local def = Monsters.ById[typeId]
		local cost = if elder then Monsters.Elder.WaveCost else def.WaveCost
		local count = 1
		if not elder and def.GroupMin and def.GroupMax then
			count = math.max(1, math.min(Util.RandomInt(def.GroupMin, def.GroupMax), night.Bank // cost, Config.Night.MaxMonstersAlivePerGarden - alive))
		end
		local gate = pickGate(player, typeId)
		for _ = 1, count do
			spawnNightMonster(player, garden, typeId, gate, elder)
		end
		night.Bank -= cost * count
		alive += count
	end
end

-- Damage and rewards -----------------------------------------------------------------------------------

local function despawn(monster: any)
	allMonsters[monster.Id] = nil
	if monster.Owner then
		local garden = gardens[monster.Owner]
		if garden then
			garden.Monsters[monster.Id] = nil
		end
	end
	monster.Model:Destroy()
	updateAliveCount(monster.Owner)
end

-- A monster driven away without eating raises the server Hunger Meter (section 11)
local function drivenAway(monster: any, night: Night?)
	if night then
		night.Repelled += 1
	end
	if not monster.Ate then
		S.HungerService.Add(Config.Hunger.DrivenAway, monster.Owner)
	end
end

local function dropCarried(monster: any, attacker: Player?)
	if monster.Carrying and monster.Owner then
		local creatureId = monster.Carrying
		monster.Carrying = nil
		local bundle = monster.Model:FindFirstChild("Carry")
		if bundle then
			bundle:Destroy()
		end
		S.KidnapService.OnDropped(monster.Owner, creatureId, attacker)
	end
end

local function rewardNightKill(monster: any, attacker: Player?)
	local owner = monster.Owner :: Player
	local def = monster.Def
	local data = S.DataService.GetData(owner)
	local xp = if monster.Elder then Monsters.Elder.XP else def.XP
	local essence = if monster.Elder then Monsters.Elder.Essence else def.Essence
	local hunger = hungerFor(owner)
	essence *= if hunger then hunger.Essence else 1

	S.ProgressionService.AddXP(owner, xp, "Defeat")
	S.EconomyService.AddEssence(owner, essence)
	if attacker and attacker ~= owner then
		S.ProgressionService.AddXP(attacker, xp, "Help defend")
		S.SocialService.OnHelpedDefend(attacker, owner)
	end
	local killer = attacker or owner
	local killerData = S.DataService.GetData(killer)
	if killerData then
		killerData.Stats.MonstersDefeated = (killerData.Stats.MonstersDefeated or 0) + 1
	end
	S.ObjectiveService.Progress(killer, "Kill:" .. def.Id)
	S.SeasonService.AddXP(killer, Config.Season.XP.Defeat)

	if data and S.CreatureService.CountAll(data) < Config.MaxCreatures then
		if def.Id == "brute" and not monster.Elder and data.Unlocks.Eggs and Util.Chance(Creatures.BruteEggDropChance) then
			S.CreatureService.GiveEgg(owner, Creatures.MysteryEgg.Pool[1], Shop.EggHatchSeconds)
			notify(owner, "The Brute dropped a creature egg!")
		elseif monster.Elder and Util.Chance(Monsters.Nests.RareEggChance) then
			S.CreatureService.GiveEgg(owner, "fox", Shop.EggHatchSeconds)
			notify(owner, "The Elder left a rare egg!")
		end
	end
end

local function kill(monster: any, attacker: Player?)
	if not allMonsters[monster.Id] then
		return
	end
	dropCarried(monster, attacker)
	if monster.Kind == "Night" and monster.Owner then
		local garden = gardens[monster.Owner]
		local night = garden and garden.Night
		if night then
			night.Killed += 1
		end
		drivenAway(monster, night)
		rewardNightKill(monster, attacker)
	elseif monster.Kind == "Guard" and attacker then
		S.ProgressionService.AddXP(attacker, monster.Def.XP, "Defeat")
		S.ObjectiveService.Progress(attacker, "Kill:" .. monster.Def.Id)
	end
	despawn(monster)
	if monster.OnKilled then
		task.spawn(monster.OnKilled, monster, attacker)
	end
end

-- Returns true when the hit defeated the monster
function MonsterService.DamageMonster(monsterId: string, amount: number, attacker: Player?): boolean
	local monster = allMonsters[monsterId]
	if not monster then
		return false
	end
	if monster.Ability == "Armored" then
		amount *= Monsters.Elder.Abilities.Armored.DamageTakenMult
	end
	monster.Health -= amount
	monster.DamageTaken += amount
	if attacker then
		monster.Contrib[attacker] = (monster.Contrib[attacker] or 0) + amount
	end
	monster.HealthFill.Size = UDim2.fromScale(math.max(0, monster.Health / monster.MaxHealth), 1)
	monster.Body.Color = Color3.new(1, 1, 1)
	task.delay(0.1, function()
		if monster.Body.Parent then
			monster.Body.Color = monster.BodyColor
		end
	end)
	if monster.Def.Id == "swarmer" and monster.Kind == "Night" then
		monster.Position -= monster.Facing * Monsters.SwarmerKnockback
	end
	-- Section 14.1: 120 damage makes a Stalker drop the creature it carries
	if monster.Carrying and monster.DamageTaken >= Config.Kidnap.DropDamage then
		dropCarried(monster, attacker)
		monster.State = "Retreat"
	end
	if monster.Health <= 0 then
		kill(monster, attacker)
		return true
	end
	return false
end

local function onPlayerAttack(player: Player, _data: any, targetId: any)
	if not S.AntiExploit.TryCooldown(player, "Attack", Config.PlayerAttack.CooldownSeconds) then
		return
	end
	local rootPosition = S.AntiExploit.GetRootPosition(player)
	if not rootPosition then
		return
	end
	local function inRange(monster: any): number?
		local offset = monster.Position - rootPosition
		local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude - monster.Size / 2
		return if distance <= Config.PlayerAttack.Range + Config.Distance.Tolerance then distance else nil
	end

	local target = nil
	if type(targetId) == "string" and allMonsters[targetId] and inRange(allMonsters[targetId]) then
		target = allMonsters[targetId]
	else
		-- No valid target given: hit the nearest monster in range (any garden, so friends can help)
		local best = math.huge
		for _, monster in allMonsters do
			local distance = if monster.State ~= "Retreat" then inRange(monster) else nil
			if distance and distance < best then
				best, target = distance, monster
			end
		end
	end
	if target then
		MonsterService.DamageMonster(target.Id, Config.PlayerAttack.Damage, player)
	else
		S.HeistService.TryTag(player) -- tag a thief carrying your creature
	end
end

-- AI context ------------------------------------------------------------------------------------------------

local ctx = {}

function ctx.Despawn(monster: any)
	despawn(monster)
end

function ctx.DrivenAway(monster: any, night: Night?)
	drivenAway(monster, night)
	updateAliveCount(monster.Owner)
end

function ctx.HowlMult(monster: any): number
	local garden = monster.Owner and gardens[monster.Owner]
	for _, other in garden and garden.Monsters or {} do
		if other.Ability == "Howler" and other ~= monster and (other.Position - monster.Position).Magnitude <= Monsters.Elder.HowlerRadius then
			return Monsters.Elder.Abilities.Howler.NearbyDamageMult
		end
	end
	return 1
end

function ctx.AreaDamage(owner: Player, position: Vector3, radius: number, damage: number)
	local garden = gardens[owner]
	for _, other in garden and garden.Monsters or {} do
		local offset = other.Position - position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius then
			MonsterService.DamageMonster(other.Id, damage, nil)
		end
	end
end

function ctx.Grab(monster: any, creatureId: string)
	if S.KidnapService.OnGrab(monster.Owner, creatureId) then
		monster.Carrying = creatureId
		Models.AddCarry(monster.Model, monster.Size)
		monster.State, monster.EscapeStep = "Escape", 1
	else
		monster.State, monster.Timer = "Seek", 0
	end
end

function ctx.Escaped(monster: any)
	local creatureId = monster.Carrying
	monster.Carrying = nil
	if creatureId and monster.Owner then
		S.KidnapService.OnEscaped(monster.Owner, creatureId)
	end
	despawn(monster)
end

function ctx.EatCreature(monster: any, night: Night, creatureId: string)
	local owner = monster.Owner
	local data = S.DataService.GetData(owner)
	local creature = data and data.Creatures[creatureId]
	if not monster.CanEat or not creature or night.CreaturesLost >= Config.Night.MaxCreaturesLostPerNight or not S.CreatureService.CanBeEaten(owner, creature) then
		return
	end
	night.CreaturesLost += 1
	monster.Ate = true
	S.CreatureService.RemoveCreature(owner, creatureId)
	S.HungerService.Add(Config.Hunger.CreatureEaten, owner)
	Remotes.Get("UnlockBanner"):FireClient(owner, { Title = `{GameMath.CreatureName(creature)} was taken by a monster`, Text = "Shelters and Guardians keep creatures safe. At most one creature can be lost per night.", Kind = "Warning" })
end

function ctx.AlphaTick(monster: any)
	S.FeastService.OnAlphaTick(monster)
end

-- Public API ---------------------------------------------------------------------------------------------------

-- Picks the first wave's gate in advance so Scouts and watchtowers can warn about it
function MonsterService.PlanFirstGate(player: Player): string
	local gate = GATES[Util.RandomInt(1, #GATES)]
	plannedGates[player] = gate
	return gate
end

function MonsterService.StartNight(player: Player, nightNumber: number, nightSeconds: number)
	local data = S.DataService.GetData(player)
	if not data then
		return
	end
	local garden = getGarden(player)
	local waves = math.max(1, math.floor(nightSeconds / Config.Night.WaveIntervalSeconds))
	garden.Night = {
		Number = nightNumber,
		WaveBudget = nightBudget(data) / waves,
		Bank = 0,
		WavesLeft = waves,
		WaveTimer = 0,
		Spawned = 0,
		Repelled = 0,
		Killed = 0,
		Ate = 0,
		CreaturesLost = 0,
		Alerted = false,
	}
end

-- Ends the night: leftover monsters retreat. Returns the night stats.
function MonsterService.EndNight(player: Player): Night?
	local garden = gardens[player]
	local night = garden and garden.Night
	if not garden or not night then
		return nil
	end
	garden.Night = nil
	for _, monster in garden.Monsters do
		if monster.State ~= "Escape" then
			monster.State = "Retreat"
		end
	end
	updateAliveCount(player)
	return night
end

function MonsterService.IsNight(player: Player): boolean
	local garden = gardens[player]
	return garden ~= nil and garden.Night ~= nil
end

-- Nearest active monster in a player's garden (for Guardian and Hunter creatures)
function MonsterService.FindNearest(player: Player, position: Vector3, radius: number): (string?, Vector3?)
	local garden = gardens[player]
	local bestId, bestPosition, best = nil, nil, radius
	for id, monster in garden and garden.Monsters or {} do
		if monster.State ~= "Retreat" then
			local distance = (monster.Position - position).Magnitude
			if distance < best then
				bestId, bestPosition, best = id, monster.Position, distance
			end
		end
	end
	return bestId, bestPosition
end

-- Nest guards (rescue nests and forest nests) and the Feast Night Alpha
function MonsterService.SpawnGuard(typeId: string, position: Vector3, folder: Instance, options: SpawnOptions?): any
	local opts: SpawnOptions = options or {}
	opts.Kind = "Guard"
	opts.Position = position
	opts.Folder = folder
	local monster = create(nil, typeId, opts)
	monster.State = "Guard"
	return monster
end

function MonsterService.SpawnAlpha(position: Vector3, health: number, onKilled: (any, Player?) -> ()): any
	local monster = create(nil, "alpha", { Kind = "Alpha", Position = position, Health = health, Folder = workspace, OnKilled = onKilled })
	monster.State = "Alpha"
	return monster
end

function MonsterService.Remove(monsterId: string)
	local monster = allMonsters[monsterId]
	if monster then
		despawn(monster)
	end
end

function MonsterService.Get(monsterId: string): any
	return allMonsters[monsterId]
end

function MonsterService.ClearGarden(player: Player)
	local garden = gardens[player]
	if garden then
		for _, monster in garden.Monsters do
			allMonsters[monster.Id] = nil
			monster.Model:Destroy()
		end
	end
	gardens[player] = nil
	plannedGates[player] = nil
end

function MonsterService.Init() end

function MonsterService.Start()
	S.AntiExploit.Bind("PlayerAttack", onPlayerAttack)
	Players.PlayerRemoving:Connect(MonsterService.ClearGarden)

	RunService.Heartbeat:Connect(function(dt)
		local clock = os.clock()
		for player, garden in gardens do
			local night = garden.Night
			if night and night.WavesLeft > 0 then
				night.WaveTimer -= dt
				if night.WaveTimer <= 0 then
					night.WaveTimer = Config.Night.WaveIntervalSeconds
					night.WavesLeft -= 1
					local data = S.DataService.GetData(player)
					if data then
						spawnWave(player, garden, data)
						updateAliveCount(player)
					end
				end
			end
		end
		for _, monster in allMonsters do
			local garden = monster.Owner and gardens[monster.Owner]
			local ok, err = pcall(AI.Update, monster, garden and garden.Night, dt, clock, ctx)
			if not ok then
				warn(`[MonsterService] {err}`)
				despawn(monster)
			end
		end
	end)
end

return MonsterService
