--!strict
-- Daily and weekly quests, and Rebirth. All numbers here; QuestService and RebirthService use them.
--
-- Quests: each day (UTC) every player gets DailyCount quests picked from the Daily pool (different
-- players get different picks), plus one Weekly quest each week. Count = Base + Level * PerLevel,
-- so goals grow with the player. Coin rewards are "minutes of earnings" at the player's level
-- (same formula as coin packs), so they stay worth it at every level.
--
-- Events come from the same game events as the goal chain: Plant, Harvest, Sell (per item),
-- Kill (any monster), Night (survived), Care (pet or feed), Petal, Visit.

local Quests = {}

export type Quest = {
	Id: string,
	Text: string, -- {n} is replaced by the count
	Event: string,
	Base: number,
	PerLevel: number,
	MinStage: number,
}

Quests.DailyCount = 3

Quests.Daily = {
	{ Id = "harvest", Text = "Harvest {n} crops", Event = "Harvest", Base = 15, PerLevel = 0.8, MinStage = 1 },
	{ Id = "plant", Text = "Plant {n} seeds", Event = "Plant", Base = 15, PerLevel = 0.8, MinStage = 1 },
	{ Id = "sell", Text = "Sell {n} goods", Event = "Sell", Base = 20, PerLevel = 1.2, MinStage = 1 },
	{ Id = "defeat", Text = "Defeat {n} monsters", Event = "Kill", Base = 8, PerLevel = 0.3, MinStage = 1 },
	{ Id = "nights", Text = "Survive {n} nights", Event = "Night", Base = 2, PerLevel = 0.03, MinStage = 1 },
	{ Id = "care", Text = "Pet or feed creatures {n} times", Event = "Care", Base = 6, PerLevel = 0.1, MinStage = 1 },
	{ Id = "petals", Text = "Collect {n} Moon Petals", Event = "Petal", Base = 3, PerLevel = 0.05, MinStage = 2 },
	{ Id = "visit", Text = "Visit {n} friend gardens", Event = "Visit", Base = 1, PerLevel = 0, MinStage = 5 },
} :: { Quest }

Quests.Weekly = {
	{ Id = "w_harvest", Text = "Harvest {n} crops this week", Event = "Harvest", Base = 250, PerLevel = 8, MinStage = 1 },
	{ Id = "w_defeat", Text = "Defeat {n} monsters this week", Event = "Kill", Base = 80, PerLevel = 3, MinStage = 1 },
	{ Id = "w_nights", Text = "Survive {n} nights this week", Event = "Night", Base = 20, PerLevel = 0.2, MinStage = 1 },
	{ Id = "w_sell", Text = "Sell {n} goods this week", Event = "Sell", Base = 300, PerLevel = 10, MinStage = 1 },
} :: { Quest }

-- Rewards (coins = minutes of earnings at your level, see GameMath.CoinPackAmount)
Quests.DailyReward = { CoinMinutes = 6, SeasonXP = 40, Essence = 5 }
Quests.WeeklyReward = { CoinMinutes = 45, SeasonXP = 250, Essence = 40, Crates = 1 }
-- Bonus for finishing all daily quests of the day
Quests.AllDailyBonus = { CoinMinutes = 6, SeasonXP = 60 }

-- Rebirth -----------------------------------------------------------------------------------------------
-- At MinLevel a player can rebirth: Garden Level, coins, plot size, soil and crops reset. Creatures,
-- Essence, stages and features, buildings, cosmetics, passes and Season progress are kept.
-- Each rebirth gives a permanent bonus to coins from selling (and quests) and to Garden XP.
Quests.Rebirth = {
	MinLevel = 40,
	CoinBonus = 0.15, -- +15% coins per rebirth
	XPBonus = 0.10, -- +10% Garden XP per rebirth
	MaxBonusRebirths = 20, -- bonuses stop growing after this many (the count keeps going)
}

return Quests
