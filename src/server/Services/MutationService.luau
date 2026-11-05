--!strict
-- MutationService: end-of-night mutation rolls, event mutations and the Essence re-roll
-- (Build Spec sections 6 and 12.3).
--   chance = BaseChance * (1 + spiritBonus + hungerBonus + companionBonus)
-- The starter creature's first Moonlit is guaranteed. Mutations never depend on Robux.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Creatures = require(ConfigFolder:WaitForChild("Creatures"))
local Mutations = require(ConfigFolder:WaitForChild("Mutations"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local S = require(script.Parent.Parent.Registry)

local MutationService = {}

-- Granted only by their events (rescue, Heist Pen, Feast Night)
local EVENT_ONLY = { Escaped = true, Shadow = true, HungerBlessed = true }

local function rarityIndex(rarity: string): number
	return table.find(Mutations.RarityOrder, rarity :: any) or 1
end

local function eligible(data: any, creature: any, mutation: Mutations.Mutation, hungerLevel: string?): boolean
	if EVENT_ONLY[mutation.Id] or mutation.Stage > data.Stage or table.find(creature.Mutations, mutation.Id) then
		return false
	end
	if mutation.Id == "Moonlit" and not data.Unlocks.Moonlit then
		return false
	end
	if mutation.MinNightsSurvived and data.NightsSurvived < mutation.MinNightsSurvived then
		return false
	end
	if mutation.RequiresRole and creature.Role ~= mutation.RequiresRole then
		return false
	end
	if mutation.RequiresLifeStage and creature.Stage ~= mutation.RequiresLifeStage then
		return false
	end
	if mutation.MinMonstersRepelled and (creature.Repelled or 0) < mutation.MinMonstersRepelled then
		return false
	end
	if mutation.MinMonstersDefeated and (creature.Kills or 0) < mutation.MinMonstersDefeated then
		return false
	end
	if mutation.RequiresHungerLevel and hungerLevel ~= mutation.RequiresHungerLevel then
		return false
	end
	return true
end

-- Rare Companions add +1% each to the whole garden (cap +5%)
local function companionBonus(data: any): number
	local role = Creatures.Roles.RareCompanion
	local count = 0
	for _, creature in data.Creatures do
		if creature.Role == "RareCompanion" and not creature.CaptiveAt then
			count += 1
		end
	end
	return math.min(role.MutationBonusCap or 0, count * (role.MutationBonusPer or 0))
end

local function chanceFor(data: any, creature: any, mutation: Mutations.Mutation, hungerLevel: string?, companion: number): number
	if mutation.Id == "Moonlit" and creature.Bonded and not data.TutorialDone.FirstMoonlit then
		return Mutations.StarterFirstNightMoonlitChance
	end
	local hunger = if data.Unlocks.Hunger and hungerLevel then (Mutations.HungerBonus :: any)[hungerLevel] or 0 else 0
	local chance = GameMath.MutationChance(mutation.BaseChance, S.LifecycleService.SpiritBonus(data, creature.BloodlineId), hunger, companion)
	if mutation.Id == "Moonlit" and data.HeistFlag and S.HeistService.IsActive() then
		chance += Config.Heist.FlagMoonlitBonus
	end
	return chance
end

-- Adds a mutation (event rewards and rolls). Returns false when it cannot be added.
function MutationService.Grant(player: Player, creatureId: string, mutationId: string, reason: string?): boolean
	local data = S.DataService.GetData(player)
	local creature = data and data.Creatures[creatureId]
	local mutation = Mutations.ById[mutationId]
	if not data or not creature or not mutation or table.find(creature.Mutations, mutationId) then
		return false
	end
	if #creature.Mutations >= Mutations.MaxPerCreature then
		-- Replace the most common mutation so event rewards are never lost
		local lowest, lowestIndex = math.huge, nil
		for index, id in creature.Mutations do
			local existing = Mutations.ById[id]
			local rank = if existing then rarityIndex(existing.Rarity) else 0
			if rank < lowest then
				lowest, lowestIndex = rank, index
			end
		end
		if not lowestIndex or lowest >= rarityIndex(mutation.Rarity) then
			return false
		end
		table.remove(creature.Mutations, lowestIndex)
	end
	table.insert(creature.Mutations, mutationId)
	if mutationId == "Moonlit" and creature.Bonded then
		data.TutorialDone.FirstMoonlit = true
	end
	if mutation.Id == "Escaped" then
		creature.Traits.End = math.min(Creatures.TraitMax, creature.Traits.End + (mutation.EnduranceBonus or 0))
	end
	data.Stats.Mutations = (data.Stats.Mutations or 0) + 1
	local name = GameMath.CreatureName(creature)
	Remotes.Get("MutationEarned"):FireClient(player, { Creature = name, Mutation = mutation.Name, Rarity = mutation.Rarity, Reason = reason or mutation.Reason })
	S.CreatureService.RefreshLook(player, creatureId)
	S.DataService.MarkChanged(player)
	return true
end

-- Returns report lines for every mutation earned
function MutationService.RollNightEnd(player: Player): { string }
	local data = S.DataService.GetData(player)
	local lines = {}
	if not data then
		return lines
	end
	local hungerLevel = if S.HungerService.IsActive() then S.HungerService.GetLevelName() else nil
	local companion = companionBonus(data)
	for id, creature in data.Creatures do
		if not creature.CaptiveAt then
			for _, mutation in Mutations.List do
				if #creature.Mutations >= Mutations.MaxPerCreature then
					break
				end
				if eligible(data, creature, mutation, hungerLevel) and Util.Chance(chanceFor(data, creature, mutation, hungerLevel, companion)) then
					if MutationService.Grant(player, id, mutation.Id) then
						table.insert(lines, `{GameMath.CreatureName(creature)} earned {mutation.Name}! ({mutation.Reason})`)
					end
				end
			end
		end
	end
	return lines
end

-- Section 6: 50 Essence buys a guaranteed roll once per creature per day, never above Rare
local function onReroll(player: Player, data: any, creatureId: any)
	local creature = type(creatureId) == "string" and data.Creatures[creatureId]
	if not creature or not data.Unlocks.Essence then
		return
	end
	local today = Util.DayNumber()
	if creature.RerollDay == today then
		Remotes.Get("Notify"):FireClient(player, { Text = "This creature already re-rolled today." })
		return
	end
	local pool = {}
	local maxRank = rarityIndex(Mutations.RerollMaxRarity)
	for _, mutation in Mutations.List do
		if not EVENT_ONLY[mutation.Id] and mutation.Stage <= data.Stage and rarityIndex(mutation.Rarity) <= maxRank and not table.find(creature.Mutations, mutation.Id) then
			table.insert(pool, mutation.Id)
		end
	end
	if #pool == 0 then
		Remotes.Get("Notify"):FireClient(player, { Text = "No new mutations are available for this creature yet." })
		return
	end
	if not S.EconomyService.Spend(player, { Essence = Config.EssenceRerollCost }) then
		return
	end
	creature.RerollDay = today
	local mutationId = pool[Util.RandomInt(1, #pool)]
	if #creature.Mutations >= Mutations.MaxPerCreature then
		table.remove(creature.Mutations, Util.RandomInt(1, #creature.Mutations))
	end
	MutationService.Grant(player, creatureId, mutationId, "Essence re-roll")
end

function MutationService.Init() end

function MutationService.Start()
	S.AntiExploit.Bind("RerollMutation", onReroll)
end

return MutationService
