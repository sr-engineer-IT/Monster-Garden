--!strict
-- Shared data types (Build Spec section 16). Profile tables must stay DataStore-safe:
-- string or array keys only, no Instances, no Vector3/CFrame (serialize them first).

export type Traits = {
	Str: number,
	Int: number,
	End: number,
}

export type Creature = {
	Id: string,
	Species: string,
	Sex: "Boy" | "Girl",
	Traits: Traits,
	Role: string?,
	Stage: "Baby" | "Young" | "Adult" | "Elder",
	AgeMinutes: number, -- play minutes, only counts while the owner is online
	Fed: number,
	Mutations: { string },
	Powers: { string },
	ParentA: string?,
	ParentB: string?,
	BloodlineId: string,
	Generation: number,
	Bonded: boolean,
	RobuxBought: boolean,
	Stolen: boolean,
	HotUntil: number,
	InjuredUntil: number, -- PlaySeconds when the injury ends (0 = healthy)
	CaptiveAt: number?, -- os.time() when kidnapped (nil = home)
	Name: string?,
	LastProducedAt: number?, -- os.time() of last goods; production is timestamp based
	BondXP: number?,
	RoleChangedAt: number?, -- PlaySeconds
	LastBredAt: number?, -- PlaySeconds
	TrainedTotal: number?, -- trait points from training (cap YoungTrainCap)
	TaughtTotal: number?, -- trait points from Elder teaching (cap ElderTeachCap)
	LastTrainedAt: number?, -- PlaySeconds
	ExtendMinutes: number?, -- lifespan added by Moonlit nights
	Kills: number?,
	Repelled: number?,
	InShelter: boolean?,
	InPen: boolean?,
	ColorIndex: number?, -- recolor token
	RerollDay: number?, -- Essence mutation re-roll, once per day
	OriginalOwner: number?, -- UserId of the owner it was stolen from (steal-back)
	Warned: boolean?, -- end-of-life warning shown
}

-- One planted tile. Keyed by tileId in ProfileData.Crops.
export type CropRecord = {
	Type: string,
	PlantedAt: number, -- os.time() when planted or last regrown
	Mutations: { string },
	HarvestsLeft: number, -- multi-harvest crops count down to 0
	WaterTaps: number, -- water taps used this growth
	RipeFor: number?, -- seconds spent ripe (day, owner online); Overripe at GameMath.FreshSeconds
	Overripe: boolean?, -- harvest pays half price in coins (Config.Spoil)
}

export type Spirit = {
	Id: string,
	BloodlineId: string,
	LegacyTrait: "Str" | "Int" | "End",
	Species: string,
	Name: string,
	Mutations: { string },
	Companion: boolean?, -- Bonded/Robux creatures become working companion Spirits
}

export type NestRecord = {
	SlotId: string,
	MotherId: string?, -- nil = empty nest
	FatherId: string?,
	StartedAt: number?, -- PlaySeconds when breeding started
}

export type EggRecord = {
	Species: string,
	HatchAt: number, -- os.time()
	Tamed: boolean?,
}

export type DailyCap = {
	Day: number, -- os.time() // 86400
	Count: number,
}

export type Listing = {
	Id: string,
	Kind: "Goods" | "Creature",
	Key: string, -- goods key or creature id
	Qty: number,
	Price: number,
}

export type ProfileData = {
	SchemaVersion: number,
	Coins: number,
	Essence: number,
	GardenLevel: number,
	GardenXP: number,
	Stage: number,
	NightsSurvived: number,
	FailedNightsInRow: number,
	ShieldNightsLeft: number,
	Unlocks: { [string]: boolean },
	TutorialDone: { [string]: boolean },
	VeteranSkipUsed: boolean,
	Plot: {
		Tiles: { [string]: boolean },
		Buildings: { [string]: any },
		SoilLevel: number,
		SizeIndex: number, -- index into Config.PlotSizes
		Decor: { [string]: string }, -- tileId -> decoration id (that tile grows no crops)
	},
	Crops: { [string]: CropRecord },
	Inventory: {
		Seeds: { [string]: number },
		Items: { [string]: number }, -- tokens: rename, recolor, crate
		Goods: { [string]: number },
		Cosmetics: { [string]: boolean },
		Decor: { [string]: number }, -- decoration id -> count in storage
	},
	Creatures: { [string]: Creature },
	Spirits: { [string]: Spirit },
	Nests: { [string]: NestRecord },
	Defenses: { [string]: any },
	Trophies: { [string]: boolean },
	Titles: { [string]: boolean },
	HeistFlag: boolean,
	Purchases: {
		Ids: { [string]: number }, -- PurchaseId -> os.time() granted
		PassesOwned: { [string]: boolean },
		DailyCaps: { [string]: DailyCap },
	},
	LastLoginDay: number,
	LoginStreak: number,
	LastSeen: number,
	PlaySeconds: number, -- total online play time; aging and gestation use this
	ObjectiveIndex: number,
	ObjectiveProgress: number,
	Eggs: { [string]: EggRecord },
	Stats: { [string]: number }, -- MonstersDefeated, Mutations, Babies, Steals, ...
	ShopListings: { [string]: Listing }, -- items held in the stall (escrow)
	NestPopulation: number,
	Boosts: { GrowthUntil: number },
	Settings: { VisitsOpen: boolean, SoundOn: boolean, GuideArrow: boolean },
	Season: { XP: number, Claimed: { [string]: boolean } },
	CratePity: number,
	Equipped: { Glow: string?, Theme: string?, Title: string? },
	Quests: { Day: number, Daily: { any }, Week: number, Weekly: { any }, BonusClaimed: boolean },
	Rebirths: number,
	Puzzles: { Day: number, Done: { [string]: boolean }, BonusClaimed: boolean },
	Upgrades: { [string]: number }, -- Upgrade Station levels: Grow, Speed, Yield
}

return {}
