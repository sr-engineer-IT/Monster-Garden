--!strict
-- Unit tests for core formulas (Build Spec sections 20 and 23.2): XP curve, growth timestamps,
-- offline cap, breeding trait rolls, mutation chance, wave budget, stage unlock triggers,
-- life stages and sell values. Run in Studio by typing /test in chat (see Dev/DevCommands).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Stages = require(ConfigFolder:WaitForChild("Stages"))
local GameMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameMath"))

type Result = { Passed: number, Failed: { string } }

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

local tests: { { Name: string, Run: (check: (boolean, string) -> ()) -> () } } = {}

local function test(name: string, run: (check: (boolean, string) -> ()) -> ())
	table.insert(tests, { Name = name, Run = run })
end

test("XP curve: early levels at 150, 487, 971, 1583", function(check)
	check(GameMath.XPToNext(1) == 150, `L1 = {GameMath.XPToNext(1)}`)
	check(GameMath.XPToNext(2) == 487, `L2 = {GameMath.XPToNext(2)}`)
	check(GameMath.XPToNext(3) == 971, `L3 = {GameMath.XPToNext(3)}`)
	check(GameMath.XPToNext(4) == 1583, `L4 = {GameMath.XPToNext(4)}`)
end)

test("Coin packs: minutes x (30 + 25 x level)", function(check)
	check(GameMath.CoinPackAmount(12, 1) == 660, `small at L1 = {GameMath.CoinPackAmount(12, 1)}`)
	check(GameMath.CoinPackAmount(30, 5) == 4650, `medium at L5 = {GameMath.CoinPackAmount(30, 5)}`)
	check(GameMath.CoinPackAmount(60, 20) == 31800, `large at L20 = {GameMath.CoinPackAmount(60, 20)}`)
end)

test("Rebirth bonuses and quest sizes", function(check)
	check(GameMath.RebirthCoinMult(0) == 1, "no rebirth = no bonus")
	check(math.abs(GameMath.RebirthCoinMult(2) - 1.3) < 1e-9, `2 rebirths = +30% coins ({GameMath.RebirthCoinMult(2)})`)
	check(math.abs(GameMath.RebirthXPMult(1) - 1.1) < 1e-9, `1 rebirth = +10% XP ({GameMath.RebirthXPMult(1)})`)
	check(GameMath.RebirthCoinMult(500) == GameMath.RebirthCoinMult(20), "bonus stops growing after 20 rebirths")
	check(math.abs(GameMath.RebirthDifficulty(2) - 1.5) < 1e-9, `2 rebirths = nights 50% harder ({GameMath.RebirthDifficulty(2)})`)
	check(GameMath.RebirthDifficulty(nil) == 1, "no rebirth = normal nights")
	local harvest = { Base = 15, PerLevel = 0.8 }
	check(GameMath.QuestCount(harvest, 1) == 15, `harvest quest at L1 = {GameMath.QuestCount(harvest, 1)}`)
	check(GameMath.QuestCount(harvest, 40) == 47, `harvest quest at L40 = {GameMath.QuestCount(harvest, 40)}`)
end)

test("Growth uses timestamps and soil level", function(check)
	local now = 1000000
	local carrot = { Type = "carrot", PlantedAt = now - 20, HarvestsLeft = 1, WaterTaps = 0, Mutations = {} }
	check(GameMath.CropProgress(carrot, 1, now) >= 1, "carrot ready after 20 s on soil 1")
	carrot.PlantedAt = now - 10
	check(near(GameMath.CropProgress(carrot, 1, now), 0.5), "carrot half grown after 10 s")
	check(near(GameMath.GrowSeconds(carrot, 2), 18), "soil 2 = 0.9x grow time")
	check(near(GameMath.GrowSeconds(carrot, 3), 16), "soil 3 = 0.8x grow time")
	local tomato = { Type = "tomato", PlantedAt = now, HarvestsLeft = 2, WaterTaps = 0, Mutations = {} }
	check(near(GameMath.GrowSeconds(tomato, 1), 40), "tomato regrows in 40 s after the first harvest")
end)

test("Offline production is capped", function(check)
	local cap = Config.OfflineProductionCapHours * 3600
	check(GameMath.ProductionCount(600, cap, 120) == 5, "10 min of eggs = 5")
	check(GameMath.ProductionCount(cap * 3, cap, 120) == cap // 120, "a long absence stops at the cap")
	check(GameMath.ProductionCount(-50, cap, 120) == 0, "clock going back gives nothing")
end)

test("Breeding traits stay within parents +-5 plus legacy, clamped 0-100", function(check)
	local rng = Random.new(7)
	local mother = { Str = 30, Int = 98, End = 2 }
	local father = { Str = 60, Int = 99, End = 4 }
	local variation = Config.Breeding.TraitVariation
	for _ = 1, 500 do
		local child = GameMath.BreedTraits(mother, father, { Str = 2, Int = 0, End = 0 }, rng)
		local strOk = (child.Str >= 30 - variation + 2 and child.Str <= 30 + variation + 2) or (child.Str >= 60 - variation + 2 and child.Str <= 60 + variation + 2)
		if not strOk or child.Int > 100 or child.End < 0 then
			check(false, `bad child Str {child.Str} Int {child.Int} End {child.End}`)
			return
		end
	end
	check(true, "")
end)

test("Mutation chance formula", function(check)
	check(near(GameMath.MutationChance(0.4, 0, 0, 0), 0.4), "no bonus")
	check(near(GameMath.MutationChance(0.08, 0.04, 0.25, 0.02), 0.08 * 1.31), "spirit + Starving + companions")
end)

test("Wave budget formula", function(check)
	local data = { GardenLevel = 2, Stage = 2, ShieldNightsLeft = 3, FailedNightsInRow = 0, Unlocks = {}, NestPopulation = 3 }
	check(near(GameMath.WaveBudget(data, nil), (15 + 4 * 2) * 0.6 * 0.4), "shielded stage 2 night")
	data.ShieldNightsLeft = 0
	data.FailedNightsInRow = 3
	check(near(GameMath.WaveBudget(data, nil), (15 + 4 * 2) * 0.6 * 0.7), "ease after 3 failed nights")
	data.FailedNightsInRow = 0
	data.Stage = 6
	check(near(GameMath.WaveBudget(data, 75), (15 + 4 * 2) * 1.0 * 1.5), "hunger 75 = x1.5")
	data.Unlocks = { Explore = true }
	check(near(GameMath.WaveBudget(data, nil), 23 + 3 * Config.NestPopulation.BudgetPerMonster), "forest nests add to the budget")
end)

test("Stage unlock triggers", function(check)
	local stage2 = Stages.Get(2).Trigger
	local stage4 = Stages.Get(4).Trigger
	check(not GameMath.StageTriggerMet(stage2, 1, 0, 0), "stage 2 needs a night")
	check(GameMath.StageTriggerMet(stage2, 1, 1, 0), "stage 2 after night 1")
	check(not GameMath.StageTriggerMet(stage4, 10, 5, 1), "stage 4 needs 2 adults")
	check(GameMath.StageTriggerMet(stage4, 10, 5, 2), "stage 4 at level 10 with 2 adults")
end)

test("Life stages follow play-time age", function(check)
	local creature = { Traits = { Str = 20, Int = 20, End = 25 }, Mutations = {}, AgeMinutes = 0 }
	check(near(GameMath.Lifespan(creature), 675), "lifespan = 600 + End x 3")
	check(GameMath.LifeStageFor(creature, true) == "Baby", "age 0 is a Baby")
	creature.AgeMinutes = 60
	check(GameMath.LifeStageFor(creature, true) == "Young", "60 min is Young")
	creature.AgeMinutes = 200
	check(GameMath.LifeStageFor(creature, true) == "Adult", "200 min is Adult")
	creature.AgeMinutes = 600
	check(GameMath.LifeStageFor(creature, true) == "Elder", "600 min is Elder after stage 7")
	check(GameMath.LifeStageFor(creature, false) == "Adult", "aging stops at Adult before stage 7")
	creature.Mutations = { "FastGrowth" }
	creature.AgeMinutes = 90
	check(GameMath.LifeStageFor(creature, true) == "Adult", "Fast Growth reaches Adult sooner")
end)

test("Sell values", function(check)
	check(GameMath.SellValue("carrot") == 16, "carrot sells 16")
	check(GameMath.SellValue("carrot#Moonlit") == 24, "Moonlit sells x1.5")
	check(GameMath.SellValue("egg") == 25, "chicken egg sells 25")
	check(GameMath.SellValue("unknown") == 0, "unknown goods are worth nothing")
end)

test("Bag space: base plus pass, Founder, Club and Premium bonuses", function(check)
	local inv = Config.Inventory
	local function capacity(passes: { [string]: boolean }): number
		return GameMath.InventoryCapacity({ Purchases = { PassesOwned = passes } })
	end
	check(capacity({}) == inv.BaseCapacity, `no passes = {capacity({})}`)
	check(capacity({ premium = true }) == inv.BaseCapacity + inv.PremiumBonus, `premium = {capacity({ premium = true })}`)
	local all = capacity({ pass_inventory = true, pass_founder = true, club = true, premium = true })
	check(all == inv.BaseCapacity + inv.InventoryPassBonus + inv.FounderBonus + inv.ClubBonus + inv.PremiumBonus, `all = {all}`)
end)

return function(): Result
	local result: Result = { Passed = 0, Failed = {} }
	for _, entry in tests do
		local ok, err = pcall(entry.Run, function(condition: boolean, message: string)
			if not condition then
				error(message, 0)
			end
		end)
		if ok then
			result.Passed += 1
		else
			table.insert(result.Failed, `{entry.Name}: {err}`)
		end
	end
	print(`[Tests] {result.Passed} passed, {#result.Failed} failed`)
	for _, failure in result.Failed do
		warn(`[Tests] FAILED {failure}`)
	end
	return result
end
