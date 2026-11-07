--!strict
-- Pure game formulas shared by server and client (so HUD timers match server decisions).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Crops = require(ConfigFolder:WaitForChild("Crops"))
local Creatures = require(ConfigFolder:WaitForChild("Creatures"))
local Explore = require(ConfigFolder:WaitForChild("Explore"))
local Mutations = require(ConfigFolder:WaitForChild("Mutations"))

local GameMath = {}

local MOONLIT_SUFFIX = "#Moonlit"

-- XP needed to go from level L to L + 1 (section 3)
function GameMath.XPToNext(level: number): number
	return math.floor(Config.Level.XPMultiplier * level ^ Config.Level.XPExponent + 0.5)
end

-- Crops -----------------------------------------------------------------------------

function GameMath.IsCropAvailable(crop: Crops.Crop, stage: number, level: number): boolean
	return stage >= crop.Stage and level >= (crop.MinLevel or 1) and crop.Stage <= Config.MaxStageEnabled
end

-- Seconds a planted record needs in total (regrow time after the first harvest)
function GameMath.GrowSeconds(record: any, soilLevel: number): number
	local crop = Crops.ById[record.Type]
	if crop == nil then
		return math.huge
	end
	local base = crop.GrowSeconds
	if record.HarvestsLeft < crop.Harvests and crop.RegrowSeconds then
		base = crop.RegrowSeconds
	end
	return base * (Crops.SoilMultiplier[soilLevel] or 1)
end

function GameMath.CropProgress(record: any, soilLevel: number, now: number): number
	local total = GameMath.GrowSeconds(record, soilLevel)
	return math.clamp((now - record.PlantedAt) / total, 0, 1)
end

function GameMath.CropSecondsLeft(record: any, soilLevel: number, now: number): number
	return math.max(0, record.PlantedAt + GameMath.GrowSeconds(record, soilLevel) - now)
end

-- Goods keys -------------------------------------------------------------------------
-- Inventory.Goods keys: crop id ("carrot"), Moonlit crop ("carrot#Moonlit"),
-- creature goods id ("egg") or exploration goods id ("crystal")

function GameMath.CropGoodsKey(cropId: string, moonlit: boolean): string
	return if moonlit then cropId .. MOONLIT_SUFFIX else cropId
end

function GameMath.ParseGoodsKey(key: string): (string, boolean)
	local base = string.gsub(key, MOONLIT_SUFFIX .. "$", "")
	return base, base ~= key
end

local goodsById: { [string]: { Name: string, Sell: number } } = {}
for _, species in Creatures.List do
	if species.Goods then
		goodsById[species.Goods.Id] = species.Goods
	end
end
for id, goods in Explore.Goods do
	goodsById[id] = goods
end

function GameMath.IsKnownGoods(key: string): boolean
	local base = GameMath.ParseGoodsKey(key)
	return Crops.ById[base] ~= nil or goodsById[base] ~= nil
end

function GameMath.GoodsName(key: string): string
	local base, moonlit = GameMath.ParseGoodsKey(key)
	local crop = Crops.ById[base]
	local name = if crop then crop.Name elseif goodsById[base] then goodsById[base].Name else base
	return if moonlit then "Moonlit " .. name else name
end

-- Merchant price for one unit
function GameMath.SellValue(key: string): number
	local base, moonlit = GameMath.ParseGoodsKey(key)
	local crop = Crops.ById[base]
	if crop then
		return math.floor(crop.Sell * (if moonlit then Mutations.ById.Moonlit.SellMult or 1 else 1))
	end
	local goods = goodsById[base]
	return if goods then goods.Sell else 0
end

function GameMath.IsCropGoods(key: string): boolean
	local base = GameMath.ParseGoodsKey(key)
	return Crops.ById[base] ~= nil
end

-- Bag capacity (total goods items)
function GameMath.InventoryCapacity(data: any): number
	local passes = data.Purchases.PassesOwned
	local inv = Config.Inventory
	return inv.BaseCapacity
		+ (if passes.pass_inventory then inv.InventoryPassBonus else 0)
		+ (if passes.pass_founder then inv.FounderBonus else 0)
		+ (if passes.club then inv.ClubBonus else 0)
end

function GameMath.GoodsCount(data: any): number
	local count = 0
	for _, amount in data.Inventory.Goods do
		count += amount
	end
	return count
end

-- Creatures ----------------------------------------------------------------------------

function GameMath.CreatureMaxHealth(creature: any): number
	local effects = Creatures.TraitEffects
	local health = effects.HealthBase + creature.Traits.End * effects.HealthPerEnd
	local intAbove = math.max(0, creature.Traits.Int - effects.HealthPenaltyIntAbove)
	health *= 1 - 0.01 * math.floor(intAbove / 10)
	if table.find(creature.Powers or {}, "GiantSize") then
		health *= 1 + Config.Breeding.GiantSizeHealth
	end
	if table.find(creature.Mutations or {}, "HungerBlessed") then
		health *= 1 + (Mutations.ById.HungerBlessed.HealthBonus or 0)
	end
	return health
end

function GameMath.CreatureAttack(creature: any): number
	local effects = Creatures.TraitEffects
	local damage = effects.AttackBase + creature.Traits.Str * effects.AttackPerStr
	for _, mutationId in creature.Mutations or {} do
		local mutation = Mutations.ById[mutationId]
		if mutation and mutation.DamageBonus then
			damage *= 1 + mutation.DamageBonus
		end
	end
	if creature.Role == "MonsterHunter" then
		damage *= 1 + (Creatures.Roles.MonsterHunter.DamageBonus or 0)
	end
	return damage
end

-- Lifespan in play minutes (section 12.1)
function GameMath.Lifespan(creature: any): number
	local life = Config.Lifecycle
	return life.BaseLifespanMinutes + creature.Traits.End * life.LifespanPerEndurance + (creature.ExtendMinutes or 0)
end

-- Age (play minutes) when a life stage starts. Fast Growth shortens Baby and Young by 30%.
function GameMath.StageStartMinutes(creature: any, stage: string): number
	local life = Config.Lifecycle
	local lifespan = GameMath.Lifespan(creature)
	local fast = if table.find(creature.Mutations or {}, "FastGrowth") then 1 - life.FastGrowthReduction else 1
	local babyEnd = lifespan * life.BabyEnd * fast
	local youngEnd = babyEnd + lifespan * (life.YoungEnd - life.BabyEnd) * fast
	if stage == "Baby" then
		return 0
	elseif stage == "Young" then
		return babyEnd
	elseif stage == "Adult" then
		return youngEnd
	end
	return lifespan * life.AdultEnd
end

-- Life stage for an age. Before stage 7 (Elder feature) aging stops at Adult.
function GameMath.LifeStageFor(creature: any, elderEnabled: boolean): string
	local age = creature.AgeMinutes or 0
	if age < GameMath.StageStartMinutes(creature, "Young") then
		return "Baby"
	elseif age < GameMath.StageStartMinutes(creature, "Adult") then
		return "Young"
	elseif not elderEnabled or age < GameMath.StageStartMinutes(creature, "Elder") then
		return "Adult"
	end
	return "Elder"
end

-- Never lost, stolen or killed (section 16)
function GameMath.IsProtected(creature: any): boolean
	return creature.Bonded == true or creature.RobuxBought == true
end

-- Base value for player shop price bands and trades
function GameMath.CreatureValue(creature: any): number
	local species = Creatures.ById[creature.Species]
	local base = if species then species.Value else 100
	return math.floor(base * (1 + 0.25 * #(creature.Mutations or {}) + 0.25 * #(creature.Powers or {})))
end

function GameMath.CreatureName(creature: any): string
	local species = Creatures.ById[creature.Species]
	return creature.Name or (if species then species.Name else creature.Species)
end

-- Hunger level entry for a value (section 11)
function GameMath.HungerLevel(value: number): any
	local result = Config.Hunger.Levels[1]
	for _, level in Config.Hunger.Levels do
		if value >= level.Min then
			result = level
		end
	end
	return result
end

-- Moon Season reward for a tier on a track. Free: coins, Essence, milestone cosmetics.
-- Premium (pass_season): cosmetic crates and titles only.
function GameMath.SeasonReward(tier: number, premium: boolean): any
	if premium then
		if tier == 25 then
			return { Kind = "Title", Id = "Moon Walker", Text = "Title: Moon Walker" }
		elseif tier == Config.Season.Tiers then
			return { Kind = "Title", Id = "Season Legend", Text = "Title: Season Legend" }
		end
		return { Kind = "Crate", Count = 1, Text = "Cosmetic crate" }
	end
	if tier % 10 == 0 then
		local cosmetics = { "glow_pink", "glow_mint", "glow_gold", "theme_autumn", "theme_frost" }
		local id = cosmetics[tier // 10] or "glow_gold"
		return { Kind = "Cosmetic", Id = id, Text = "Cosmetic" }
	elseif tier % 5 == 0 then
		return { Kind = "Essence", Count = 20, Text = "20 Essence" }
	end
	return { Kind = "Coins", Count = 100 * tier, Text = `{100 * tier} coins` }
end

-- Formulas used by services (kept here so the unit tests in server/Tests can check them) -----

-- Section 4.1: has a player met a stage trigger?
function GameMath.StageTriggerMet(trigger: any, level: number, nights: number, adults: number): boolean
	return (trigger.Level == nil or level >= trigger.Level)
		and (trigger.NightsSurvived == nil or nights >= trigger.NightsSurvived)
		and (trigger.AdultCreatures == nil or adults >= trigger.AdultCreatures)
end

-- Section 10.2: budget = (15 + 4 x Level) x StageDifficulty x HungerMult x ShieldMult x EaseMult
-- (+ forest nest population from stage 8)
function GameMath.WaveBudget(data: any, hungerValue: number?): number
	local night = Config.Night
	local stageDifficulty = night.StageDifficulty[data.Stage] or 1
	local shield = if data.ShieldNightsLeft > 0 then night.ShieldMult else 1
	local ease = 1
	if data.FailedNightsInRow >= 3 then
		ease = night.EaseAfterThreeFails
	elseif data.FailedNightsInRow >= 2 then
		ease = night.EaseAfterTwoFails
	end
	local hungerMult = if hungerValue then 1 + hungerValue / night.HungerDivisor else 1
	local budget = (night.BudgetBase + night.BudgetPerLevel * data.GardenLevel) * stageDifficulty * hungerMult * shield * ease
	if data.Unlocks and data.Unlocks.Explore then
		budget += (data.NestPopulation or 0) * Config.NestPopulation.BudgetPerMonster
	end
	return budget
end

-- Section 12.2: each trait comes from a random parent, +-variation, + Legacy bonus, clamped 0-100
function GameMath.BreedTraits(mother: any, father: any, legacy: { [string]: number }?, rng: Random?): any
	local random = rng or Random.new()
	local variation = Config.Breeding.TraitVariation
	local traits = {}
	for _, trait in Creatures.TraitKeys do
		local parent = if random:NextNumber() < 0.5 then mother else father
		local value = parent[trait] + random:NextInteger(-variation, variation) + (if legacy then legacy[trait] or 0 else 0)
		traits[trait] = math.clamp(value, Creatures.TraitMin, Creatures.TraitMax)
	end
	return traits
end

-- Section 12.3: chance = base x (1 + spiritBonus + hungerBonus + companionBonus)
function GameMath.MutationChance(base: number, spiritBonus: number, hungerBonus: number, companionBonus: number): number
	return base * (1 + spiritBonus + hungerBonus + companionBonus)
end

-- Timestamp production with the offline cap (section 3): whole items made in the elapsed time
function GameMath.ProductionCount(elapsedSeconds: number, capSeconds: number, everySeconds: number): number
	return math.max(0, math.min(elapsedSeconds, capSeconds) // everySeconds)
end

-- Defense slots ---------------------------------------------------------------------------

function GameMath.DefenseSlots(level: number): number
	return Config.DefenseSlots.Base + math.floor(level / Config.DefenseSlots.PerLevels)
end

function GameMath.NestSlots(data: any): number
	local breeding = Config.Breeding
	return breeding.BaseNestSlots + math.floor(data.GardenLevel / breeding.NestSlotsPerLevels) + (if data.Purchases.PassesOwned.pass_nest then 1 else 0)
end

-- Coins a coin pack gives: minutes of average earnings at the player's Garden Level.
-- Used by the server (grant) and the store (shown amount), so they always match.
function GameMath.CoinPackAmount(minutes: number, level: number): number
	return math.floor(minutes * (Config.CoinPack.EarningsPerMinuteBase + Config.CoinPack.EarningsPerMinutePerLevel * level))
end

-- Rebirth bonuses (see config/Quests.luau). Used by the server and shown in the Rebirth panel.
local QuestsConfig = require(ConfigFolder:WaitForChild("Quests"))

function GameMath.RebirthCoinMult(rebirths: number?): number
	local n = math.min(rebirths or 0, QuestsConfig.Rebirth.MaxBonusRebirths)
	return 1 + n * QuestsConfig.Rebirth.CoinBonus
end

function GameMath.RebirthXPMult(rebirths: number?): number
	local n = math.min(rebirths or 0, QuestsConfig.Rebirth.MaxBonusRebirths)
	return 1 + n * QuestsConfig.Rebirth.XPBonus
end

-- Daily Puzzles: which puzzle a player gets today (same on server and client).
-- Riddle / OddOneOut: an index into the list. Memory: a seed for shuffling the cards.
local PuzzlesConfig = require(ConfigFolder:WaitForChild("Puzzles"))

function GameMath.DailyPuzzle(kind: string, day: number, userId: number): number
	local salt = if kind == "Riddle" then 11 elseif kind == "OddOneOut" then 23 else 37
	local rng = Random.new(day * 1009 + userId % 100003 * 7 + salt)
	if kind == "Riddle" then
		return rng:NextInteger(1, #PuzzlesConfig.Riddles)
	elseif kind == "OddOneOut" then
		return rng:NextInteger(1, #PuzzlesConfig.OddOneOut)
	end
	return rng:NextInteger(1, 1000000)
end

-- Quest goal size for a player's level
function GameMath.QuestCount(quest: any, level: number): number
	return math.max(1, math.floor(quest.Base + level * quest.PerLevel))
end

return GameMath
