--!strict
-- Global tunable numbers (Build Spec section 3, plus shared rules from sections 6-14 and 22).
-- Never hard-code numbers in logic: add them here or in the matching Config module.

local Config = {}

-- Server and saving -----------------------------------------------------------
Config.MaxPlayersPerServer = 8 -- one garden each; also set Max Players = 8 in Game Settings > Places
Config.DataStoreName = "MoonlitGrove_Profiles"
Config.ProfileKeyPrefix = "Player_"
Config.SchemaVersion = 2
Config.AutosaveSeconds = 60
Config.UseMockDataStoreInStudio = false -- true: Studio never touches real saved data
Config.StudioIgnoreOwnedPasses = true -- Studio: ignore passes the creator owns automatically (test like a new player)
Config.OfflineProductionCapHours = 8
Config.TickRateSeconds = 1
Config.MaxStoredPurchaseIds = 500 -- oldest receipt ids are trimmed past this

-- Day and night (full-length values; per-stage values live in Stages) ---------
Config.DayLengthFullSeconds = 360
Config.NightLengthFullSeconds = 180
Config.NewPlayerShieldNights = 3

-- Economy ---------------------------------------------------------------------
Config.StarterCoins = 20
Config.MerchantRestockSeconds = 300
Config.RareRestockChance = 0.05
Config.MaxDailyLoginGiftCoins = 100
Config.DailyLoginGift = {
	BaseCoins = 50,
	LevelDivisor = 10, -- gift = BaseCoins * (1 + GardenLevel / LevelDivisor)
}
Config.EssenceRerollCost = 50 -- guaranteed mutation re-roll, once per creature per day
Config.NightIncomeShare = 0.30 -- surviving a night pays ~30% of average day income

-- Garden Level ----------------------------------------------------------------
Config.Level = {
	XPMultiplier = 150, -- XP to go from L to L+1 = round(XPMultiplier * L ^ XPExponent)
	XPExponent = 1.7, -- tuned 2026-11: Level 15 in about 1 hour was far too fast
	MaxLevel = 60,
}

Config.XPSources = {
	SurviveNightBase = 25,
	SurviveNightPerMonster = 5,
	BabyBorn = 30,
	RescueCreature = 40,
	CoinsPerSellXP = 25, -- 1 XP per 25 coins earned from selling goods (was 10: selling gave too much XP)
	ObjectiveMin = 20,
	ObjectiveMax = 100,
}

Config.FriendInviteBonus = {
	XPMult = 0.25, -- +25% Garden XP
	Days = 7,
}

-- Plot ------------------------------------------------------------------------
-- Expansion is offered when the level is reached and bought with Coins.
Config.PlotSizes = {
	{ Level = 1, Width = 4, Depth = 4, Cost = 0 },
	{ Level = 2, Width = 4, Depth = 5, Cost = 100 },
	{ Level = 3, Width = 5, Depth = 5, Cost = 250 },
	{ Level = 4, Width = 5, Depth = 6, Cost = 500 },
	{ Level = 5, Width = 6, Depth = 6, Cost = 1000 },
	{ Level = 10, Width = 7, Depth = 7, Cost = 4000 },
	{ Level = 15, Width = 8, Depth = 8, Cost = 12000 },
	{ Level = 20, Width = 9, Depth = 9, Cost = 30000 },
	{ Level = 30, Width = 10, Depth = 10, Cost = 100000 },
}
Config.ExtraPlotPassTiles = 16
Config.TileSizeStuds = 8

Config.DefenseSlots = {
	Base = 4, -- slots = Base + floor(GardenLevel / PerLevels)
	PerLevels = 2,
}

-- Night and waves (section 10) ------------------------------------------------
Config.Night = {
	WarningSeconds = 20,
	WaveIntervalSeconds = 20,
	MaxGates = 4,
	FirstNightSwarmers = 3, -- night 1 is fixed, no budget
	BudgetBase = 15, -- budget = (BudgetBase + BudgetPerLevel * L) * Stage * Hunger * Shield * Ease
	BudgetPerLevel = 4,
	StageDifficulty = { 0.6, 0.6, 0.8, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 }, -- index = stage
	HungerDivisor = 150, -- HungerMult = 1 + Hunger / HungerDivisor
	ShieldMult = 0.4,
	EaseAfterTwoFails = 0.85,
	EaseAfterThreeFails = 0.7,
	MaxMonstersAlivePerGarden = 25,
	MaxCreaturesLostPerNight = 1,
	CreatureEatMinStage = 5, -- before this stage creatures can only be Injured
}

-- Targeting weights (section 10.3)
Config.TargetWeights = {
	CropTile = 1,
	GlowingCropMult = 2,
	Creature = 2,
	DefenseInWay = 0.5,
	StarvingRareMult = 2,
}

-- Player combat (section 9) ---------------------------------------------------
Config.PlayerAttack = {
	Range = 8,
	Damage = 10,
	CooldownSeconds = 0.5,
}

-- Interaction distances (studs) -----------------------------------------------
Config.Distance = {
	Harvest = 12,
	Plant = 12,
	Merchant = 15,
	Interact = 12,
	Tolerance = 4, -- extra slack for network lag
}

-- Creature care and combat (section 7) ----------------------------------------
Config.Fed = {
	Start = 100,
	Max = 100,
	DrainIntervalSeconds = 60, -- -1 Fed per 60 s of owner play time
	DrainAmount = 1,
	StrDrainPer10 = 0.01, -- +1% drain per 10 Strength
	FeedAmount = 30,
	StopWorkBelow = 25,
	NightBonusAtOrAbove = 50,
	NightHealthBonus = 0.10,
}
Config.RoleChangeCooldownSeconds = 60
Config.InjuredSeconds = 180
Config.CreatureAutoAttack = {
	Range = 8,
	IntervalSeconds = 1,
}

-- Lifecycle (section 12.1) ----------------------------------------------------
Config.Lifecycle = {
	BaseLifespanMinutes = 600,
	LifespanPerEndurance = 3,
	AgeTickSeconds = 60,
	-- Share of lifespan where each stage ends
	BabyEnd = 0.03,
	YoungEnd = 0.18,
	AdultEnd = 0.73,
	FastGrowthReduction = 0.30,
	YoungTrainEveryMinutes = 30,
	YoungTrainCap = 5,
	ElderProductionMult = 0.5,
	ElderDefenseMult = 0.75,
	ElderTeachPerHour = 1,
	ElderTeachCap = 5,
	WarnAtShare = 0.90,
	FarewellAtShare = 0.98,
	MoonlitNightExtendMinutes = 10,
	MoonlitExtendCapShare = 0.20,
	SpiritMutationBonus = 0.02,
	SpiritMutationBonusCap = 0.20,
	LegacyTraitPerSpirit = 2,
	LegacyTraitCap = 10,
}

-- Breeding (section 12.2) -----------------------------------------------------
Config.Breeding = {
	CooldownPlaySeconds = 3600,
	GestationPlaySeconds = 900,
	TraitVariation = 5,
	RarePowerChance = 0.03,
	FirstBabyRarePower = true, -- section 22.3: first baby always gets one
	BaseNestSlots = 2,
	NestSlotsPerLevels = 10, -- +1 slot per 10 Garden Levels
	GiantSizeScale = 0.20,
	GiantSizeHealth = 0.15,
}

-- Hunger Meter and Feast Night (section 11) -----------------------------------
Config.Hunger = {
	Min = 0,
	Max = 100,
	MinPlayersAtStage = 3, -- needs 3+ players at stage 6 in the server
	DrivenAway = 0.3,
	CreatureEaten = -5,
	LureBerry = -5,
	DecoyCreature = -8,
	PerDayCooldown = -2,
	MaxRisePerNight = 25,
	ResetAfterFeast = 30,
	Levels = {
		{ Name = "Calm", Min = 0, Budget = 1.0, Speed = 1.0, Essence = 1.0 },
		{ Name = "Hungry", Min = 30, Budget = 1.15, Speed = 1.1, Essence = 1.25 },
		{ Name = "Starving", Min = 60, Budget = 1.3, Speed = 1.2, Essence = 1.5 },
		{ Name = "Feast", Min = 100, Budget = 1.3, Speed = 1.2, Essence = 1.5 },
	},
	StarvingStalkerMult = 2,
}

Config.Feast = {
	MinPlayersAtStage = 3, -- needs 3+ players at stage 9
	WarningSeconds = 300,
	ParticipationDamage = 100,
	ParticipationDefendSeconds = 30,
	ParticipationItemsSupplied = 5,
	RewardCoinsBase = 200, -- times level scale
	RewardEssence = 100,
	HungerBlessedChance = 0.10,
	HungerBlessedTopCount = 3,
	LegendaryEggTopShare = 0.10,
}

-- Stealing (section 14) -------------------------------------------------------
Config.Heist = {
	WeekendOnly = true, -- section 14.2: ship as a weekend event first (always on in Studio)
	MaxItemsLostPerNight = 1,
	HotItemSeconds = 180,
	StealCooldownSameVictimSeconds = 600,
	MinLevelGap = 10, -- no stealing from players 10+ levels below you
	PenSlots = 3,
	GrabHoldSeconds = 3,
	CarryTimeLimitSeconds = 60,
	CarrySpeedMult = 0.7,
	TagStunSeconds = 3,
	LockPenSeconds = 30,
	LockPenCooldownSeconds = 120,
	FlagMoonlitBonus = 0.10,
	FlagGoodsCoinBonus = 0.20,
}

Config.Kidnap = {
	DropDamage = 120,
	RescueEssence = 8,
	RescueXP = 12,
	RescueNestMaxDistance = 150,
	NestGuardsMin = 3,
	NestGuardsMax = 5,
}

-- Things to do while waiting (section 22.1) -----------------------------------
Config.Engagement = {
	WaterTapSeconds = 3,
	WaterTapMaxPerGrowth = 3,
	PetFedGain = 5,
	PetBondXP = 1,
	PetCooldownSeconds = 30,
	MoonPetalIntervalSeconds = 90,
	MoonPetalMaxActive = 5,
	MoonPetalEssence = 1,
	MoonPetalCoins = 10, -- before Essence unlocks
	TrainingSeconds = 10,
	TrainingCooldownSeconds = 300,
	ObjectivesShown = 3,
	MaxIdleSeconds = 30,
}

-- Anti-exploit (section 17, 23.3) ---------------------------------------------
Config.AntiExploit = {
	DefaultCallsPerSecond = 10,
	-- Lower limits for expensive remotes
	CallsPerSecond = {
		SellItems = 3,
		BuyItem = 4,
		PlaceBuilding = 4,
		StartBreeding = 2,
		ListShopItem = 2,
		BuyShopItem = 3,
		SetHeistFlag = 1,
		RequestSync = 1,
		PlayerAttack = 4,
	},
	FlagLogThrottleSeconds = 5,
	MaxHarvestsPerSecond = 6, -- above this is logged as suspicious
}


-- Game flow -------------------------------------------------------------------
Config.MaxStageEnabled = 9 -- stages above this show as "Coming soon"
Config.MaxCreatures = 12
Config.StageGiftCoins = { [2] = 60, [3] = 300, [4] = 600, [5] = 1000, [6] = 1500, [7] = 2500, [8] = 4000, [9] = 6000 }
Config.NightReward = {
	CoinsBase = 20, -- coins = CoinsBase + CoinsPerLevel * GardenLevel (stands in for NightIncomeShare)
	CoinsPerLevel = 10,
	FailRepelledShare = 0.5, -- a night counts as failed (for EaseMult) below this repelled share
}
Config.MonsterEatSeconds = 2 -- time a monster chews on a crop before it is eaten
Config.CreatureMove = {
	Speed = 14,
	FollowRadius = 40, -- follow the owner when they are this close and inside the plot
	FollowStartDistance = 14, -- only walk after the owner when farther than this
	FollowOffset = 7,
	TickSeconds = 0.1,
}

-- Goods bag (total items). Passes add room; selling empties it.
Config.Inventory = {
	BaseCapacity = 150,
	InventoryPassBonus = 100, -- pass_inventory ("+20 slots" in the spec)
	FounderBonus = 50,
	ClubBonus = 30,
	PremiumBonus = 30, -- Roblox Premium members
}

-- Scout role and watchtower warn earlier and show the monsters' direction
Config.EarlyWarningSeconds = 10

-- Monster nests near each garden (stage 8): nests grow each night and add to the wave budget
Config.NestPopulation = {
	Start = 3,
	GrowPerNight = 1,
	Max = 8,
	BudgetPerMonster = 2,
	ClearReduction = 4, -- destroying a forest nest removes this much population
}

-- Shared server systems use fewer players in Studio so they can be tested alone
Config.StudioMinPlayersOverride = 1

-- Coin packs are sized to average earnings at the player's level (section 13.2)
Config.CoinPack = {
	EarningsPerMinuteBase = 30,
	EarningsPerMinutePerLevel = 25,
}

Config.Leaderboard = {
	MapName = "MoonlitGrove_Leaderboards_v1",
	RefreshSeconds = 60,
	TopCount = 10,
	ExpirationSeconds = 7 * 86400,
	Categories = {
		{ Id = "GardenLevel", Name = "Garden Level" },
		{ Id = "NightsSurvived", Name = "Nights Survived" },
		{ Id = "MonstersDefeated", Name = "Monsters Defeated" },
		{ Id = "Mutations", Name = "Rare Discoveries" },
	},
}

Config.Trade = {
	RequestTimeoutSeconds = 30,
	ConfirmSeconds = 3,
	RareConfirmSeconds = 10, -- delay for rare items (section 23.5)
	MaxCreatures = 4,
	MaxGoodsKinds = 8,
	MaxCoins = 1000000,
}

-- Moon Season (section 13.3): tiers earned by playing
Config.Season = {
	Name = "Season 1: First Moon",
	Tiers = 50,
	XPPerTier = 100,
	XP = { Night = 20, Harvest = 1, Defeat = 2, Baby = 15, Goal = 10 },
}

Config.VisitCooldownSeconds = 5

-- Gardens sit on a 3 x 3 grid. The middle cell is the Town Square; the 8 outer cells
-- are gardens, so every garden is next to town.
local GRID_SIZE = 3
local PLOT_SPACING = 220
local function plotCenters(): { Vector3 }
	local list = {}
	local half = (GRID_SIZE - 1) / 2
	for row = 0, GRID_SIZE - 1 do
		for col = 0, GRID_SIZE - 1 do
			local inner = row >= 1 and row <= GRID_SIZE - 2 and col >= 1 and col <= GRID_SIZE - 2
			if not inner then
				table.insert(list, Vector3.new((col - half) * PLOT_SPACING, 0, (row - half) * PLOT_SPACING))
			end
		end
	end
	return list
end
local PLOT_CENTERS = plotCenters()

-- World layout (studs). Offsets are relative to each plot center at ground level.
-- Garden: 140 x 140 inside the hedge. Farm grows from 4x4 to 10x10 tiles of 8 studs (32 to 80 wide)
-- around the center; buildings sit in the ring between the farm and the hedge.
Config.World = {
	GridSize = GRID_SIZE,
	PlotCenters = PLOT_CENTERS,
	PlotCount = #PLOT_CENTERS,
	GridHalf = GRID_SIZE / 2 * PLOT_SPACING, -- outer ring road line (330)
	PlotSpacing = PLOT_SPACING,
	PlotHalfSize = 70,
	GroundY = 0, -- top of the baseplate
	WorldHalfSize = 700, -- playable world; mountains rise beyond it
	GateWidth = 18,
	HedgeHeight = 4,
	MonsterSpawnOutside = 30,
	Gates = {
		N = Vector3.new(0, 0, -70),
		E = Vector3.new(70, 0, 0),
		S = Vector3.new(0, 0, 70),
		W = Vector3.new(-70, 0, 0),
	},
	LanternPosts = {
		Vector3.new(-41, 0, -61),
		Vector3.new(58, 0, -18),
		Vector3.new(18, 0, 61),
		Vector3.new(-58, 0, 18),
	},
	TrapSpots = {
		Vector3.new(0, 0, -64),
		Vector3.new(64, 0, 0),
		Vector3.new(0, 0, 64),
		Vector3.new(-64, 0, 0),
	},
	TowerSpot = Vector3.new(55, 0, -55),
	ShelterSpot = Vector3.new(-58, 0, 56),
	NestSpots = { Vector3.new(-58, 0, 30), Vector3.new(-58, 0, 41), Vector3.new(-47, 0, 50), Vector3.new(-35, 0, 56), Vector3.new(-58, 0, 6) },
	MerchantOffset = Vector3.new(52, 0, 52),
	StallOffset = Vector3.new(54, 0, 30),
	PenOffset = Vector3.new(56, 0, -36), -- Heist Pen center (3 spots along Z)
	SpawnOffset = Vector3.new(-12, 0, 56),
	CreatureHome = Vector3.new(-46, 0, 34),
	SpiritGateOffset = Vector3.new(-55, 0, -55),
	ExtraPlotOrigin = Vector3.new(-28, 0, -48), -- pass_plot: 8x2 tiles along the north edge
	ExtraPlotColumns = 8,
	ExtraPlotRows = 2,
	PetalRingMin = 46,
	PetalRingMax = 60,
	RescueNestOutside = 40, -- rescue nest distance outside the west gate
	-- Town Square shops (offsets from the world center). Each opens the merchant.
	TownShops = {
		{ Id = "Shop_Seeds", Name = "Seed Shop", Offset = Vector3.new(-70, 0, -70), Color = Color3.fromRGB(90, 190, 90) },
		{ Id = "Shop_Sell", Name = "Sell Stand", Offset = Vector3.new(70, 0, -70), Color = Color3.fromRGB(255, 190, 60) },
		{ Id = "Shop_Eggs", Name = "Egg Hatchery", Offset = Vector3.new(70, 0, 70), Color = Color3.fromRGB(150, 110, 230) },
	},
	TownPlazaRadius = 44,
	TownBoardOffset = Vector3.new(-70, 0, 70), -- notice board corner
}

-- Kill switches (section 23.3). Flip to true to disable a feature without a new version.
Config.KillSwitches = {
	PlayerShop = false,
	Trading = false,
	Heist = false,
	Purchases = false,
}

return Config
