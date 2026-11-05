--!strict
-- Monsters (Build Spec section 8 and 10.2). Monsters use the same Str/Int/End traits as creatures.

export type Monster = {
	Id: string,
	Name: string,
	Stage: number, -- stage that must be unlocked before it can spawn
	FirstNight: number, -- gentle ramp: earliest night number it appears
	Health: number,
	DamagePerSecond: number,
	Speed: number,
	WaveCost: number,
	XP: number,
	Essence: number,
	SpawnWeight: number,
	-- Optional specials
	GroupMin: number?,
	GroupMax: number?,
	LanternRetreatChance: number?,
	FenceDamageMult: number?,
	CanEat: boolean?,
	TrapAvoidChance: number?,
	PrefersUndefendedSide: boolean?,
	Grabs: boolean?,
	CarrySpeed: number?,
}

local Monsters = {}

Monsters.List = {
	{ Id = "swarmer", Name = "Swarmer", Stage = 1, FirstNight = 1, Health = 20, DamagePerSecond = 3, Speed = 14, WaveCost = 2, XP = 2, Essence = 1, SpawnWeight = 60, GroupMin = 3, GroupMax = 8, LanternRetreatChance = 0.3 },
	{ Id = "brute", Name = "Brute", Stage = 3, FirstNight = 5, Health = 200, DamagePerSecond = 20, Speed = 8, WaveCost = 15, XP = 8, Essence = 5, SpawnWeight = 20, FenceDamageMult = 3, CanEat = true },
	{ Id = "trickster", Name = "Trickster", Stage = 5, FirstNight = 8, Health = 60, DamagePerSecond = 8, Speed = 16, WaveCost = 10, XP = 6, Essence = 4, SpawnWeight = 12, TrapAvoidChance = 0.5, PrefersUndefendedSide = true },
	{ Id = "stalker", Name = "Stalker", Stage = 7, FirstNight = 12, Health = 120, DamagePerSecond = 0, Speed = 18, WaveCost = 20, XP = 12, Essence = 8, SpawnWeight = 8, Grabs = true, CarrySpeed = 12, CanEat = true },
} :: { Monster }

Monsters.ById = {} :: { [string]: Monster }
for _, monster in Monsters.List do
	Monsters.ById[monster.Id] = monster
end

-- Placeholder looks (cute, non-graphic)
Monsters.Looks = {
	swarmer = { Body = Color3.fromRGB(140, 70, 200), Eyes = Color3.fromRGB(255, 255, 120), Size = 2.4 },
	brute = { Body = Color3.fromRGB(150, 60, 50), Eyes = Color3.fromRGB(255, 200, 60), Size = 6 },
	trickster = { Body = Color3.fromRGB(60, 160, 120), Eyes = Color3.fromRGB(255, 255, 255), Size = 3 },
	stalker = { Body = Color3.fromRGB(40, 40, 70), Eyes = Color3.fromRGB(255, 60, 60), Size = 3.6 },
	alpha = { Body = Color3.fromRGB(60, 20, 90), Eyes = Color3.fromRGB(255, 120, 40), Size = 12 },
}
Monsters.ElderScale = 1.4 -- Elders are bigger and darker
Monsters.ElderTint = Color3.fromRGB(40, 30, 40)
Monsters.SwarmerKnockback = 4 -- studs pushed back by a player hit

-- Elder: a long-lived version of a base monster (stage 7, from night 12)
Monsters.Elder = {
	Stage = 7,
	FirstNight = 12,
	HealthMult = 2.5,
	DamageMult = 1.5,
	WaveCost = 40,
	XP = 50,
	Essence = 20,
	SpawnWeight = 5,
	CanEat = true,
	Abilities = {
		Armored = { DamageTakenMult = 0.7 },
		Frenzied = { SpeedMult = 1.25 },
		Howler = { NearbyDamageMult = 1.15 },
		Burrower = { IgnoreFencesOnce = true },
		Shadowed = { InvisibleOutsideLight = true },
	},
	AbilityOrder = { "Armored", "Frenzied", "Howler", "Burrower", "Shadowed" },
	HowlerRadius = 15,
}

-- Alpha: Feast Night boss (stage 9)
Monsters.Alpha = {
	Stage = 9,
	HealthBase = 3000,
	HealthPerParticipant = 500,
	DamagePerSecond = 60,
	Speed = 10,
	XP = 400,
	Essence = 100, -- per participant share
	AttackRadius = 12,
	GardenStaySeconds = 45, -- moves to another garden after this
	MaxSeconds = 360, -- leaves if not defeated by then
}

-- Trait modifiers (section 8)
Monsters.Traits = {
	RandomMin = 20,
	RandomMax = 60,
	HealthBase = 0.75, -- health x (0.75 + End / 200)
	DamageBase = 0.75, -- damage x (0.75 + Str / 200)
	Divisor = 200, -- also trap avoidance = Int / 200
}

-- Monster families and nests (section 8)
Monsters.Nests = {
	GrowPerNight = 1,
	MaxPopulation = 8,
	ElderAfterNights = 12,
	ElderLifespanNights = 15,
	RareEggChance = 0.10,
	EssenceOnOldAge = 10,
}

return Monsters
