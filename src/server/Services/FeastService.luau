--!strict
-- FeastService: Feast Night (Build Spec section 11). When the Hunger Meter hits 100 and enough
-- players reached stage 9, a 5-minute warning starts, then the Alpha roams between those players'
-- gardens. Everyone can fight it, defend allied gardens or supply crops. Rewards recognize
-- participation; the top 3 damage dealers always get Hunger-Blessed. Hunger resets to 30 after.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Monsters = require(ConfigFolder:WaitForChild("Monsters"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local S = require(script.Parent.Parent.Registry)

type Participant = { Damage: number, DefendSeconds: number, Supplied: number }
type State = {
	Phase: string, -- "Warning" or "Active"
	EndsAt: number,
	Alpha: any?,
	GardenTimer: number,
	Participants: { [Player]: Participant },
}

local FeastService = {}

local FEAST = Config.Feast
local state: State? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function eligible(player: Player): boolean
	local data = S.DataService.GetData(player)
	return data ~= nil and data.Unlocks.Feast == true
end

local function participant(player: Player): Participant
	local current = state :: State
	local entry = current.Participants[player]
	if entry == nil then
		entry = { Damage = 0, DefendSeconds = 0, Supplied = 0 }
		current.Participants[player] = entry
	end
	return entry
end

local function broadcast()
	local payload: any = { Phase = "None" }
	if state then
		payload = { Phase = state.Phase, EndsAt = state.EndsAt }
		local alpha = state.Alpha
		if alpha then
			payload.Health = math.max(0, alpha.Health)
			payload.MaxHealth = alpha.MaxHealth
			payload.Garden = if alpha.TargetPlot and alpha.TargetPlot.Owner then alpha.TargetPlot.Owner.DisplayName else nil
		end
	end
	for _, player in Players:GetPlayers() do
		if eligible(player) then
			Remotes.Get("FeastUpdate"):FireClient(player, payload)
		end
	end
end

local function feastGardens(): { any }
	local list = {}
	for _, player in Players:GetPlayers() do
		local plot = S.PlotService.GetPlot(player)
		if plot and eligible(player) then
			table.insert(list, plot)
		end
	end
	return list
end

local function finish(defeated: boolean)
	local current = state
	if not current then
		return
	end
	state = nil
	S.HungerService.Set(Config.Hunger.ResetAfterFeast)
	if current.Alpha and not defeated then
		S.MonsterService.Remove(current.Alpha.Id)
	end
	broadcast()
	if not defeated then
		for _, player in Players:GetPlayers() do
			if eligible(player) then
				Remotes.Get("UnlockBanner"):FireClient(player, { Title = "The Alpha wandered off", Text = "Feast Night is over. The monsters calm down for now.", Kind = "Warning" })
			end
		end
		return
	end

	-- Contributions: damage dealt is tracked on the Alpha
	local alpha = current.Alpha
	for attacker, damage in alpha and alpha.Contrib or {} do
		if attacker.Parent then
			participant(attacker).Damage += damage
		end
	end
	local ranked = {}
	for player, entry in current.Participants do
		table.insert(ranked, { Player = player, Entry = entry })
	end
	table.sort(ranked, function(a, b)
		return a.Entry.Damage > b.Entry.Damage
	end)
	local topShareCount = math.max(1, math.ceil(#ranked * FEAST.LegendaryEggTopShare))

	for rank, item in ranked do
		local player, entry = item.Player, item.Entry
		local data = S.DataService.GetData(player)
		if data and player.Parent then
			-- Damage threshold scales with level so new players can take part
			local threshold = FEAST.ParticipationDamage * math.clamp(data.GardenLevel / 40, 0.25, 1)
			local took = entry.Damage >= threshold or entry.DefendSeconds >= FEAST.ParticipationDefendSeconds or entry.Supplied >= FEAST.ParticipationItemsSupplied
			if took then
				local coins = math.floor(FEAST.RewardCoinsBase * (1 + data.GardenLevel / 10))
				data.Coins += coins
				S.EconomyService.AddEssence(player, FEAST.RewardEssence)
				local seed = if Util.Chance(0.5) then "starfruit" else "moonmelon"
				data.Inventory.Seeds[seed] = (data.Inventory.Seeds[seed] or 0) + 1
				data.Trophies.FeastNight = true
				data.Titles["Feast Hero"] = true
				local blessedChance = if rank <= FEAST.HungerBlessedTopCount then 1 else FEAST.HungerBlessedChance
				local ids = {}
				for id, creature in data.Creatures do
					if not creature.CaptiveAt then
						table.insert(ids, id)
					end
				end
				if #ids > 0 and Util.Chance(blessedChance) then
					S.MutationService.Grant(player, ids[Util.RandomInt(1, #ids)], "HungerBlessed")
				end
				if rank <= topShareCount and S.CreatureService.CountAll(data) < Config.MaxCreatures then
					S.CreatureService.GiveEgg(player, if Util.Chance(0.5) then "moth" else "fox", 60)
				end
				S.ProgressionService.AddXP(player, Monsters.Alpha.XP, "Feast")
				S.ObjectiveService.Progress(player, "Feast")
				Remotes.Get("UnlockBanner"):FireClient(player, { Title = "Feast Night won!", Text = `+{coins} coins, +{FEAST.RewardEssence} Essence, a rare seed and the Feast Hero title.`, Kind = "Stage" })
				S.DataService.MarkChanged(player)
			else
				Remotes.Get("UnlockBanner"):FireClient(player, { Title = "Feast Night won!", Text = "Help fight, defend a friend's garden or supply crops next time to earn rewards.", Kind = "Stage" })
			end
		end
	end
end

local function onAlphaKilled(_monster: any, _attacker: Player?)
	finish(true)
end

local function startAlpha()
	local current = state :: State
	local gardens = feastGardens()
	if #gardens == 0 then
		finish(false)
		return
	end
	local count = 0
	for _, player in Players:GetPlayers() do
		if eligible(player) then
			count += 1
		end
	end
	local plot = gardens[Util.RandomInt(1, #gardens)]
	local health = Monsters.Alpha.HealthBase + Monsters.Alpha.HealthPerParticipant * count
	local alpha = S.MonsterService.SpawnAlpha(plot.Center + Vector3.new(0, 0, -Config.World.PlotHalfSize - 20), health, onAlphaKilled)
	alpha.TargetPlot = plot
	current.Alpha = alpha
	current.Phase = "Active"
	current.EndsAt = now() + Monsters.Alpha.MaxSeconds
	current.GardenTimer = Monsters.Alpha.GardenStaySeconds
	for _, player in Players:GetPlayers() do
		if eligible(player) then
			Remotes.Get("UnlockBanner"):FireClient(player, { Title = "The Alpha is here!", Text = `It is attacking {if plot.Owner then plot.Owner.DisplayName else "a garden"}'s garden. Everyone, fight!`, Kind = "Warning" })
		end
	end
	broadcast()
end

-- Hunger reached 100
function FeastService.OnHungerFull()
	if state or S.HungerService.CountAtStage(9) < S.HungerService.MinPlayers(FEAST.MinPlayersAtStage) then
		return
	end
	state = { Phase = "Warning", EndsAt = now() + FEAST.WarningSeconds, Alpha = nil, GardenTimer = 0, Participants = {} }
	for _, player in Players:GetPlayers() do
		if eligible(player) then
			Remotes.Get("UnlockBanner"):FireClient(player, { Title = "Feast Night is coming!", Text = "The monsters are starving. Repair defenses and get ready: the Alpha arrives in 5 minutes.", Kind = "Warning" })
		end
	end
	broadcast()
end

function FeastService.OnAlphaTick(_monster: any) end

function FeastService.IsActive(): boolean
	return state ~= nil
end

-- Studio testing
function FeastService.ForceStart()
	S.HungerService.Set(Config.Hunger.Max)
	FeastService.OnHungerFull()
	if state then
		state.EndsAt = now()
	end
end

local function onSupply(player: Player, data: any)
	if not state or not eligible(player) then
		return
	end
	local needed = FEAST.ParticipationItemsSupplied
	local given = 0
	for key, count in data.Inventory.Goods do
		if GameMath.IsCropGoods(key) and given < needed then
			local take = math.min(count, needed - given)
			data.Inventory.Goods[key] = if count - take > 0 then count - take else nil
			given += take
		end
	end
	if given < needed then
		Remotes.Get("Notify"):FireClient(player, { Text = `You need {needed} crops to supply the defense.` })
		return
	end
	participant(player).Supplied += given
	Remotes.Get("Notify"):FireClient(player, { Text = "Supplies delivered! You count as a Feast Night helper." })
	S.DataService.MarkChanged(player)
end

function FeastService.Init() end

function FeastService.Start()
	S.AntiExploit.Bind("FeastSupply", onSupply)
	S.DataService.ProfileLoaded:Connect(function()
		task.delay(3, broadcast)
	end)

	task.spawn(function()
		while true do
			local dt = task.wait(1)
			local current = state
			if current then
				if current.Phase == "Warning" and now() >= current.EndsAt then
					startAlpha()
				elseif current.Phase == "Active" then
					local alpha = current.Alpha
					if not alpha or now() >= current.EndsAt then
						finish(false)
					else
						-- Defending an ally's garden counts while the Alpha is there
						local plot = alpha.TargetPlot
						for _, player in Players:GetPlayers() do
							local root = S.AntiExploit.GetRootPosition(player)
							if plot and root and plot.Owner ~= player and eligible(player) and S.PlotService.IsInside(plot, root, 10) then
								participant(player).DefendSeconds += dt
							end
						end
						current.GardenTimer -= dt
						if current.GardenTimer <= 0 then
							current.GardenTimer = Monsters.Alpha.GardenStaySeconds
							local gardens = feastGardens()
							if #gardens > 0 then
								alpha.TargetPlot = gardens[Util.RandomInt(1, #gardens)]
							end
						end
						broadcast()
					end
				end
			end
		end
	end)
end

return FeastService
