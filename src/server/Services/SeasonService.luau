--!strict
-- SeasonService: the Moon Season pass (Build Spec section 13.3). Tiers are earned by playing.
-- Free track: coins and Essence, cosmetics at milestones. Premium track (pass_season): cosmetic
-- crates and titles only. Nothing on either track gives combat power.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Config"))
local GameMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameMath"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local S = require(script.Parent.Parent.Registry)

local SeasonService = {}

local SEASON = Config.Season

function SeasonService.Reward(tier: number, premium: boolean): any
	return GameMath.SeasonReward(tier, premium)
end

function SeasonService.AddXP(player: Player, amount: number)
	local data = S.DataService.GetData(player)
	if not data or amount <= 0 then
		return
	end
	data.Season.XP = math.min(SEASON.Tiers * SEASON.XPPerTier, data.Season.XP + amount)
	S.DataService.MarkChanged(player)
end

-- Gives one reward if it is earned and unclaimed. Returns the reward or nil.
local function grant(data: any, tier: number, premium: boolean): any
	if data.Season.XP // SEASON.XPPerTier < tier then
		return nil
	end
	if premium and not data.Purchases.PassesOwned.pass_season then
		return nil
	end
	local key = `{tier}:{if premium then "p" else "f"}`
	if data.Season.Claimed[key] then
		return nil
	end
	data.Season.Claimed[key] = true
	local reward = SeasonService.Reward(tier, premium)
	if reward.Kind == "Coins" then
		data.Coins += reward.Count
	elseif reward.Kind == "Essence" then
		data.Essence += reward.Count
	elseif reward.Kind == "Cosmetic" then
		data.Inventory.Cosmetics[reward.Id] = true
	elseif reward.Kind == "Title" then
		data.Titles[reward.Id] = true
	elseif reward.Kind == "Crate" then
		data.Inventory.Items.crate = (data.Inventory.Items.crate or 0) + reward.Count
	end
	return reward
end

-- tier 0 = claim every earned reward on both tracks ("Claim all")
local function onClaim(player: Player, data: any, tier: any, premium: any)
	if tier == 0 then
		local count = 0
		for t = 1, SEASON.Tiers do
			for _, isPremium in { false, true } do
				if grant(data, t, isPremium) then
					count += 1
				end
			end
		end
		if count > 0 then
			Remotes.Get("Notify"):FireClient(player, { Text = `Claimed {count} Season reward(s)!` })
			S.DataService.MarkChanged(player)
		end
		return
	end
	if not S.AntiExploit.IsInteger(tier, 1, SEASON.Tiers) or type(premium) ~= "boolean" then
		return
	end
	if premium and not data.Purchases.PassesOwned.pass_season then
		Remotes.Get("Notify"):FireClient(player, { Text = "The premium track needs the Moon Season pass." })
		return
	end
	local reward = grant(data, tier, premium)
	if reward then
		Remotes.Get("Notify"):FireClient(player, { Text = `Season reward: {reward.Text}` })
		S.DataService.MarkChanged(player)
	end
end

function SeasonService.Init() end

function SeasonService.Start()
	S.AntiExploit.Bind("SeasonClaim", onClaim)
end

return SeasonService
