--!strict
-- Default saved profile (Build Spec section 16). ProfileStore uses this as the template:
-- new players get a copy, and Reconcile() fills in keys added by later updates.
-- Bump Config.SchemaVersion and add a step in Migrations when a field is renamed or reshaped.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Crops = require(ConfigFolder:WaitForChild("Crops"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local DefaultProfile: Types.ProfileData = {
	SchemaVersion = Config.SchemaVersion,
	Coins = Config.StarterCoins,
	Essence = 0,
	GardenLevel = 1,
	GardenXP = 0,
	Stage = 1,
	NightsSurvived = 0,
	FailedNightsInRow = 0,
	ShieldNightsLeft = Config.NewPlayerShieldNights,
	Unlocks = {}, -- feature key -> true
	TutorialDone = {}, -- tip id -> true
	VeteranSkipUsed = false,
	Plot = { Tiles = {}, Buildings = {}, SoilLevel = 1, SizeIndex = 1 },
	Crops = {}, -- tileId -> CropRecord
	Inventory = {
		Seeds = table.clone(Crops.StarterSeeds),
		Items = {},
		Goods = {},
		Cosmetics = {},
	},
	Creatures = {}, -- creature id -> Creature
	Spirits = {}, -- spirit id -> Spirit
	Nests = {}, -- slot id -> NestRecord
	Defenses = {},
	Trophies = {},
	Titles = {},
	HeistFlag = false,
	Purchases = { Ids = {}, PassesOwned = {}, DailyCaps = {} },
	LastLoginDay = 0,
	LastSeen = 0,
	PlaySeconds = 0,
	ObjectiveIndex = 1,
	ObjectiveProgress = 0,
	Eggs = {}, -- egg id -> EggRecord
	Stats = { MonstersDefeated = 0, Mutations = 0, Babies = 0, Steals = 0, NestsCleared = 0 },
	ShopListings = {}, -- listing id -> Listing (items held in escrow)
	NestPopulation = Config.NestPopulation.Start,
	Boosts = { GrowthUntil = 0 },
	Settings = { VisitsOpen = true, SoundOn = true, GuideArrow = true },
	Season = { XP = 0, Claimed = {} },
	CratePity = 0,
	Equipped = {},
}

return DefaultProfile
