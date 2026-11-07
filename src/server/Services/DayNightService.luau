--!strict
-- DayNightService: per-garden day / warning / night schedule and the end-of-night report
-- (Build Spec sections 4.2, 10.1). Night length and frequency come from the player's stage.
-- "A night every 2 days" is a day phase of DaySeconds * NightEveryDays. Gardens pause offline.
-- Client lighting follows the player attributes Phase and PhaseEndsAt (server time).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Humor = require(ConfigFolder:WaitForChild("Humor"))
local Creatures = require(ConfigFolder:WaitForChild("Creatures"))
local Stages = require(ConfigFolder:WaitForChild("Stages"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local GameMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameMath"))

local S = require(script.Parent.Parent.Registry)

type State = { Phase: string, EndsAt: number }

local DayNightService = {}

local GATE_NAMES = { N = "north", E = "east", S = "south", W = "west" }

local states: { [Player]: State } = {}

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function setPhase(player: Player, phase: string, seconds: number)
	local state = states[player]
	if state == nil then
		state = { Phase = phase, EndsAt = 0 }
		states[player] = state
	end
	state.Phase = phase
	state.EndsAt = serverNow() + seconds
	player:SetAttribute("Phase", phase)
	player:SetAttribute("PhaseEndsAt", state.EndsAt)
end

local function dayLength(data: any, firstDay: boolean): number
	if firstDay and data.NightsSurvived == 0 then
		return Stages.FirstNightAfterSpawnSeconds - Config.Night.WarningSeconds
	end
	local stage = Stages.Get(data.Stage)
	return stage.DaySeconds * stage.NightEveryDays
end

local function resolveNight(player: Player, data: any)
	local stats = S.MonsterService.EndNight(player) or { Number = data.NightsSurvived + 1, Spawned = 0, Repelled = 0, Killed = 0, Ate = 0, CreaturesLost = 0 }
	S.DefenseService.SetLights(player, false)

	data.NightsSurvived += 1
	S.QuestService.Progress(player, "Night")
	if data.ShieldNightsLeft > 0 then
		data.ShieldNightsLeft -= 1
	end
	local failed = stats.Spawned > 0 and stats.Repelled < stats.Spawned * Config.NightReward.FailRepelledShare
	data.FailedNightsInRow = if failed then data.FailedNightsInRow + 1 else 0

	-- Nights pay more than harvests (section 22.2)
	local xp = Config.XPSources.SurviveNightBase + Config.XPSources.SurviveNightPerMonster * stats.Repelled
	local coins = math.floor((Config.NightReward.CoinsBase + Config.NightReward.CoinsPerLevel * data.GardenLevel) * GameMath.RebirthNightRewardMult(data.Rebirths))
	data.Coins += coins

	-- Unlock stage 2 before mutation rolls so night 1 gives the guaranteed first Moonlit glow
	S.ProgressionService.CheckStage(player)
	S.ProgressionService.AddXP(player, xp, "Night")
	local mutations = S.MutationService.RollNightEnd(player)
	local moonlitCrops = S.CropService.RollMoonlit(player)

	local tips = {}
	local lines = {
		`Monsters repelled: {stats.Repelled} of {stats.Spawned}`,
		`+{xp} Garden XP, +{coins} coins`,
	}
	if stats.Ate > 0 then
		table.insert(lines, `Crops eaten: {stats.Ate}`)
	end
	for _, text in mutations do
		table.insert(lines, text)
	end
	if moonlitCrops > 0 then
		table.insert(lines, `{moonlitCrops} crop(s) turned Moonlit (they sell for more)!`)
	end

	if stats.CreaturesLost and stats.CreaturesLost > 0 then
		table.insert(lines, "A creature was taken tonight. Shelters keep creatures safe.")
	end
	-- a funny line to end the report (config/Humor.luau)
	table.insert(lines, "😄 " .. Humor.NightQuips[math.random(1, #Humor.NightQuips)])

	-- Later-stage systems
	S.LifecycleService.OnNightSurvived(player)
	S.HeistService.OnNightEnd(player)
	S.SeasonService.AddXP(player, Config.Season.XP.Night)
	if data.Unlocks.Explore then
		local nests = Config.NestPopulation
		data.NestPopulation = math.min(nests.Max, data.NestPopulation + nests.GrowPerNight)
		if data.NestPopulation >= nests.Max then
			table.insert(tips, "Forest nests are full. Destroy nests in the forest to shrink the waves.")
		end
	end

	local gift = Creatures.SecondCreatureGift
	if data.NightsSurvived >= gift.AfterNight and not data.TutorialDone.SecondCreature then
		data.TutorialDone.SecondCreature = true
		S.CreatureService.GiveEgg(player, gift.Species, gift.HatchSeconds)
		table.insert(lines, `Gift: a {Creatures.ById[gift.Species].Name} egg! It hatches in {gift.HatchSeconds // 60} minutes.`)
	end

	if stats.Ate > 0 then
		table.insert(tips, "Build fences at your gates and lanterns nearby to slow monsters down.")
	end
	if stats.Repelled < stats.Spawned then
		table.insert(tips, "Stand near monsters and tap Attack (or press F) to fight them.")
	end
	if data.FailedNightsInRow >= 2 then
		table.insert(tips, "Tonight's monsters will be a bit gentler.")
	end

	Remotes.Get("NightReport"):FireClient(player, {
		Night = data.NightsSurvived,
		Lines = lines,
		Tips = tips,
		InviteFriends = data.NightsSurvived == 1,
	})
	S.ObjectiveService.Refresh(player)
	S.DataService.MarkChanged(player)
end

local function advance(player: Player, state: State)
	local data = S.DataService.GetData(player)
	if not data then
		return
	end
	if state.Phase == "Day" then
		-- Scouts and a watchtower warn earlier and tell where the first wave comes from
		local early = S.DefenseService.HasBuilding(player, "watchtower")
		for _, creature in data.Creatures do
			if creature.Role == "Scout" and creature.InjuredUntil == 0 and not creature.CaptiveAt then
				early = true
			end
		end
		local seconds = Config.Night.WarningSeconds + (if early then Config.EarlyWarningSeconds else 0)
		local direction = if early then GATE_NAMES[S.MonsterService.PlanFirstGate(player)] else nil
		setPhase(player, "Warning", seconds)
		S.DefenseService.SetLights(player, true)
		Remotes.Get("NightWarning"):FireClient(player, { Seconds = seconds, Direction = direction })
	elseif state.Phase == "Warning" then
		local stage = Stages.Get(data.Stage)
		setPhase(player, "Night", stage.NightSeconds)
		S.CreatureService.OnNightStart(player)
		S.MonsterService.StartNight(player, data.NightsSurvived + 1, stage.NightSeconds)
	else
		resolveNight(player, data)
		setPhase(player, "Day", dayLength(data, false))
	end
end

-- Studio testing: skip straight to the warning
function DayNightService.ForceNight(player: Player)
	local state = states[player]
	if state and state.Phase == "Day" then
		state.EndsAt = serverNow()
	end
end

function DayNightService.GetPhase(player: Player): string?
	local state = states[player]
	return if state then state.Phase else nil
end

function DayNightService.Init() end

function DayNightService.Start()
	S.DataService.ProfileLoaded:Connect(function(player: Player, data: any)
		setPhase(player, "Day", dayLength(data, true))
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = serverNow()
			for player, state in states do
				if now >= state.EndsAt then
					local ok, err = pcall(advance, player, state)
					if not ok then
						-- Never let one error freeze a garden's clock
						warn(`[DayNightService] {player.Name}: {err}`)
						setPhase(player, "Day", 60)
					end
				end
			end
		end
	end)
end

return DayNightService
