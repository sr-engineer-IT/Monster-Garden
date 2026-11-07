--!strict
-- Mutations (Build Spec section 12.3). Rolled at night end for each surviving creature:
--   chance = BaseChance * (1 + spiritBonus + hungerBonus + companionBonus)
-- Mutations never depend on Robux.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Mythic"

export type Mutation = {
	Id: string,
	Name: string,
	Rarity: Rarity,
	Stage: number,
	BaseChance: number,
	Reason: string, -- shown in the "why you earned it" pop-up
	-- Optional conditions
	MinNightsSurvived: number?,
	RequiresRole: string?,
	RequiresLifeStage: string?,
	MinMonstersRepelled: number?,
	MinMonstersDefeated: number?,
	RequiresHungerLevel: string?,
	-- Optional effects
	SellMult: number?,
	DamageBonus: number?,
	HealthBonus: number?,
	DetectionBonus: number?,
	ExtraGoodsChance: number?,
	GrowthSpeedup: number?,
	NearbyDamageReduction: number?,
	TraitEffectBonus: number?,
	EnduranceBonus: number?,
	SuperRare: boolean?, -- big celebration + the whole server hears about it
}

local Mutations = {}

Mutations.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Mythic" } :: { Rarity }

Mutations.List = {
	{ Id = "Moonlit", Name = "Moonlit", Rarity = "Common", Stage = 2, BaseChance = 0.40, Reason = "Survived a night", SellMult = 1.5, DamageBonus = 0.05 },
	{ Id = "NightVision", Name = "Night Vision", Rarity = "Uncommon", Stage = 2, BaseChance = 0.08, Reason = "Survived 3 nights", MinNightsSurvived = 3, DetectionBonus = 0.25 },
	{ Id = "ResourceBonus", Name = "Resource Bonus", Rarity = "Uncommon", Stage = 3, BaseChance = 0.08, Reason = "A Producer that survived the night", RequiresRole = "Producer", ExtraGoodsChance = 0.15 },
	{ Id = "FastGrowth", Name = "Fast Growth", Rarity = "Uncommon", Stage = 4, BaseChance = 0.10, Reason = "Survived a night as a baby", RequiresLifeStage = "Baby", GrowthSpeedup = 0.30 },
	{ Id = "GuardianInstinct", Name = "Guardian Instinct", Rarity = "Rare", Stage = 5, BaseChance = 0.05, Reason = "Helped repel 5 monsters", MinMonstersRepelled = 5, NearbyDamageReduction = 0.15 },
	{ Id = "MonsterHunter", Name = "Monster Hunter", Rarity = "Rare", Stage = 5, BaseChance = 0.04, Reason = "Defeated 30 monsters", MinMonstersDefeated = 30, DamageBonus = 0.20 },
	{ Id = "StarTouched", Name = "Star-Touched", Rarity = "Epic", Stage = 6, BaseChance = 0.02, Reason = "Survived a Starving night", RequiresHungerLevel = "Starving", TraitEffectBonus = 0.10 },
	{ Id = "Escaped", Name = "Escaped", Rarity = "Rare", Stage = 7, BaseChance = 1.0, Reason = "Rescued from a monster nest", EnduranceBonus = 5 },
	{ Id = "Shadow", Name = "Shadow", Rarity = "Rare", Stage = 9, BaseChance = 1.0, Reason = "Stayed in the Heist Pen all night unstolen", SellMult = 1.1 },
	{ Id = "HungerBlessed", Name = "Hunger-Blessed", Rarity = "Mythic", Stage = 9, BaseChance = 0.10, Reason = "Helped defeat Feast Night", HealthBonus = 0.10, DamageBonus = 0.10 },
	-- Super-rare glows to chase for months (any surviving creature, every night)
	{ Id = "Celestial", Name = "Celestial", Rarity = "Mythic", Stage = 2, BaseChance = 1 / 5000, Reason = "Touched by a falling star (1 in 5,000!)", SellMult = 3, HealthBonus = 0.15, DamageBonus = 0.15, SuperRare = true },
	{ Id = "Eclipse", Name = "Eclipse", Rarity = "Mythic", Stage = 4, BaseChance = 1 / 50000, Reason = "Born under a moon eclipse (1 in 50,000!!)", SellMult = 5, HealthBonus = 0.25, DamageBonus = 0.25, SuperRare = true },
} :: { Mutation }

Mutations.ById = {} :: { [string]: Mutation }
for _, mutation in Mutations.List do
	Mutations.ById[mutation.Id] = mutation
end

Mutations.MaxPerCreature = 3
Mutations.StarterFirstNightMoonlitChance = 1.0 -- guaranteed first glow
Mutations.HungerBonus = { Calm = 0, Hungry = 0.10, Starving = 0.25, Feast = 0.25 }
Mutations.RerollMaxRarity = "Rare" :: Rarity -- Essence re-roll never gives Epic or Mythic
Mutations.HungerBlessedTopChance = 1.0

return Mutations
