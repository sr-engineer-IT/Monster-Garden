--!strict
-- HeistService: opt-in Heist Night (Build Spec section 14.2, stage 9, weekend event first).
-- Flagged players put up to 3 creatures in their Heist Pen. During the victim's night a flagged
-- thief holds Steal for 3 s, then carries the creature home within 60 s (slower, glowing).
-- The owner or their friends can tag the thief (Attack near them) to stun and drop it.
-- Stolen creatures are Hot for 180 s: the owner can Steal Back and they cannot be sold.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local S = require(script.Parent.Parent.Registry)
local Build = require(script.Parent.Parent.Build)

type Carry = { Thief: Player, Victim: Player, CreatureId: string, Record: any, StartedAt: number, Glow: Instance? }
type Pen = { Folder: Folder, Spots: { BasePart }, Prompts: { ProximityPrompt } }

local HeistService = {}

local HEIST = Config.Heist
local pens: { [Player]: Pen } = {}
local carries: { [Player]: Carry } = {} -- by thief
local lostThisNight: { [Player]: number } = {}
local cooldowns: { [string]: number } = {} -- "thief:victim" -> os.clock() ready
local penLockedUntil: { [Player]: number } = {}
local lockCooldown: { [Player]: number } = {}
local stunnedUntil: { [Player]: number } = {}

local function notify(player: Player, text: string)
	Remotes.Get("Notify"):FireClient(player, { Text = text })
end

-- Heist Night is a weekend event first; always on in Studio for testing
function HeistService.IsActive(): boolean
	if Config.KillSwitches.Heist then
		return false
	end
	if RunService:IsStudio() or not HEIST.WeekendOnly then
		return true
	end
	local weekday = os.date("!*t").wday -- 1 = Sunday, 7 = Saturday
	return weekday == 1 or weekday == 7
end

local function penCreatures(data: any): { string }
	local ids = {}
	for id, creature in data.Creatures do
		if creature.InPen and not creature.CaptiveAt then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

function HeistService.GetPenPosition(player: Player, creatureId: string): Vector3?
	local pen = pens[player]
	local data = S.DataService.GetData(player)
	if not pen or not data then
		return nil
	end
	local index = table.find(penCreatures(data), creatureId)
	local spot = index and pen.Spots[index]
	return if spot then spot.Position else nil
end

local function setWalkSpeed(player: Player, mult: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16 * mult
	end
end

local function endCarry(thief: Player, success: boolean)
	local carry = carries[thief]
	if not carry then
		return
	end
	carries[thief] = nil
	if carry.Glow then
		carry.Glow:Destroy()
	end
	setWalkSpeed(thief, 1)
	local victimData = S.DataService.GetData(carry.Victim)
	if not success then
		-- The creature never left the victim's profile; just bring it back
		if victimData then
			S.CreatureService.SetCaptive(carry.Victim, carry.CreatureId, false)
		end
		return
	end
	local record = S.CreatureService.RemoveCreature(carry.Victim, carry.CreatureId)
	local thiefData = S.DataService.GetData(thief)
	if not record or not thiefData then
		return
	end
	record.CaptiveAt = nil
	record.Stolen = true
	record.HotUntil = os.time() + HEIST.HotItemSeconds
	record.OriginalOwner = carry.Victim.UserId
	S.CreatureService.AddCreature(thief, record)
	thiefData.Stats.Steals = (thiefData.Stats.Steals or 0) + 1
	thiefData.Trophies.FirstHeist = true
	thiefData.Titles["Master Thief"] = true
	lostThisNight[carry.Victim] = (lostThisNight[carry.Victim] or 0) + 1
	-- The victim's HUD shows a Steal Back button while the creature is Hot
	carry.Victim:SetAttribute("StolenId", record.Id)
	carry.Victim:SetAttribute("StolenUntil", record.HotUntil)
	carry.Victim:SetAttribute("StolenFrom", thief.UserId)
	notify(thief, `You stole {GameMath.CreatureName(record)}! It is Hot for {HEIST.HotItemSeconds}s.`)
	Remotes.Get("UnlockBanner"):FireClient(carry.Victim, { Title = `{GameMath.CreatureName(record)} was stolen!`, Text = `Go to {thief.DisplayName}'s garden within {HEIST.HotItemSeconds}s and use Steal Back near it.`, Kind = "Warning" })
	S.DataService.MarkChanged(thief)
end

-- Steal (hold 3 s on a pen spot) -----------------------------------------------------------------------

local function trySteal(thief: Player, victim: Player, spotIndex: number)
	local thiefData, victimData = S.DataService.GetData(thief), S.DataService.GetData(victim)
	if thief == victim or not thiefData or not victimData or not HeistService.IsActive() then
		return
	end
	local function fail(text: string)
		notify(thief, text)
	end
	if not thiefData.Unlocks.Heist or not thiefData.HeistFlag then
		return fail("Raise your Heist Flag in the day to take part.")
	elseif not victimData.HeistFlag then
		return fail("This garden is not in Heist Night.")
	elseif S.DayNightService.GetPhase(victim) ~= "Night" then
		return fail("You can only steal during this garden's night.")
	elseif carries[thief] or (stunnedUntil[thief] or 0) > os.clock() then
		return
	elseif victimData.GardenLevel <= thiefData.GardenLevel - HEIST.MinLevelGap then
		return fail("You cannot steal from much weaker players.")
	elseif (lostThisNight[victim] or 0) >= HEIST.MaxItemsLostPerNight then
		return fail("This garden already lost an item tonight.")
	elseif (penLockedUntil[victim] or 0) > os.clock() then
		return fail("The pen is locked!")
	end
	local key = `{thief.UserId}:{victim.UserId}`
	if (cooldowns[key] or 0) > os.clock() then
		return fail("You stole from this garden recently.")
	end
	local creatureId = penCreatures(victimData)[spotIndex]
	local creature = creatureId and victimData.Creatures[creatureId]
	if not creature or GameMath.IsProtected(creature) then
		return
	end
	local pen = pens[victim]
	if not pen or not S.AntiExploit.WithinDistance(thief, pen.Spots[spotIndex].Position, Config.Distance.Interact) then
		return
	end

	cooldowns[key] = os.clock() + HEIST.StealCooldownSameVictimSeconds
	S.CreatureService.SetCaptive(victim, creatureId, true) -- hidden while carried
	local glow = nil
	local root = thief.Character and thief.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 80, 200)
		light.Range = 16
		light.Brightness = 3
		light.Parent = root
		glow = light
	end
	setWalkSpeed(thief, HEIST.CarrySpeedMult)
	carries[thief] = { Thief = thief, Victim = victim, CreatureId = creatureId, Record = creature, StartedAt = os.clock(), Glow = glow }
	notify(thief, `Run home with {GameMath.CreatureName(creature)}! {HEIST.CarryTimeLimitSeconds}s left.`)
	Remotes.Get("UnlockBanner"):FireClient(victim, { Title = "Thief in your Heist Pen!", Text = `{thief.DisplayName} grabbed {GameMath.CreatureName(creature)}. Attack them to make them drop it!`, Kind = "Warning" })
end

-- Owner or a friend uses Attack near a carrying thief (called by MonsterService when no monster was hit)
function HeistService.TryTag(tagger: Player)
	local taggerPos = S.AntiExploit.GetRootPosition(tagger)
	if not taggerPos then
		return
	end
	for thief, carry in carries do
		local thiefPos = S.AntiExploit.GetRootPosition(thief)
		local allowed = tagger == carry.Victim
		if not allowed then
			local ok, friends = pcall(function()
				return tagger:IsFriendsWith(carry.Victim.UserId)
			end)
			allowed = ok and friends == true
		end
		if allowed and thiefPos and (thiefPos - taggerPos).Magnitude <= Config.PlayerAttack.Range + Config.Distance.Tolerance then
			endCarry(thief, false)
			stunnedUntil[thief] = os.clock() + HEIST.TagStunSeconds
			setWalkSpeed(thief, 0)
			task.delay(HEIST.TagStunSeconds, function()
				if thief.Parent and not carries[thief] then
					setWalkSpeed(thief, 1)
				end
			end)
			notify(thief, "You were tagged and dropped the creature!")
			notify(tagger, "Thief tagged!")
		end
	end
end

-- Remotes ---------------------------------------------------------------------------------------------

local function onSetFlag(player: Player, data: any, on: any)
	if type(on) ~= "boolean" or not data.Unlocks.Heist or not HeistService.IsActive() then
		return
	end
	if S.DayNightService.GetPhase(player) ~= "Day" then
		notify(player, "You can only change your Heist Flag during the day.")
		return
	end
	data.HeistFlag = on
	player:SetAttribute("HeistFlag", on)
	if not on then
		for _, creature in data.Creatures do
			creature.InPen = nil
		end
	end
	notify(player, if on then "Heist Flag raised! Put up to 3 creatures in your Heist Pen." else "Heist Flag lowered. Your garden is safe from thieves.")
	S.DataService.MarkChanged(player)
end

local function onSetPen(player: Player, data: any, creatureId: any, inPen: any)
	local creature = type(creatureId) == "string" and data.Creatures[creatureId]
	if not creature or type(inPen) ~= "boolean" or not data.Unlocks.Heist then
		return
	end
	if inPen then
		if not data.HeistFlag then
			notify(player, "Raise your Heist Flag first.")
			return
		elseif GameMath.IsProtected(creature) then
			notify(player, "Starter, Bonded and Robux creatures can never be stolen, so they stay out of the pen.")
			return
		elseif #penCreatures(data) >= HEIST.PenSlots then
			notify(player, `The Heist Pen holds {HEIST.PenSlots} creatures.`)
			return
		elseif S.DayNightService.GetPhase(player) == "Night" then
			notify(player, "Set up your pen during the day.")
			return
		end
		creature.InShelter = nil
	end
	creature.InPen = inPen or nil
	S.DataService.MarkChanged(player)
end

local function onLockPen(player: Player, data: any)
	if not data.HeistFlag then
		return
	end
	if (lockCooldown[player] or 0) > os.clock() then
		notify(player, `Lock is recharging ({math.ceil(lockCooldown[player] - os.clock())}s).`)
		return
	end
	penLockedUntil[player] = os.clock() + HEIST.LockPenSeconds
	lockCooldown[player] = os.clock() + HEIST.LockPenSeconds + HEIST.LockPenCooldownSeconds
	player:SetAttribute("PenLockedUntil", os.time() + HEIST.LockPenSeconds)
	notify(player, `Heist Pen locked for {HEIST.LockPenSeconds}s.`)
end

local function onStealBack(player: Player, data: any, creatureId: any)
	if type(creatureId) ~= "string" then
		return
	end
	for _, thief in Players:GetPlayers() do
		local thiefData = S.DataService.GetData(thief)
		local creature = thiefData and thiefData.Creatures[creatureId]
		if thiefData and creature and creature.OriginalOwner == player.UserId then
			if creature.HotUntil <= os.time() then
				notify(player, "Too late: it is no longer Hot.")
				return
			end
			local position = S.CreatureService.GetPosition(thief, creatureId)
			if not position or not S.AntiExploit.WithinDistance(player, position, Config.Distance.Interact) then
				notify(player, `Get close to {GameMath.CreatureName(creature)} in {thief.DisplayName}'s garden first.`)
				return
			end
			local record = S.CreatureService.RemoveCreature(thief, creatureId)
			if record then
				record.Stolen, record.HotUntil, record.OriginalOwner = false, 0, nil
				S.CreatureService.AddCreature(player, record)
				notify(player, `You took back {GameMath.CreatureName(record)}!`)
				notify(thief, `{player.DisplayName} stole {GameMath.CreatureName(record)} back!`)
			end
			return
		end
	end
end

-- Night end: creatures that stayed in the pen all night unstolen earn Shadow (section 12.3)
function HeistService.OnNightEnd(player: Player)
	local data = S.DataService.GetData(player)
	if data and data.HeistFlag and HeistService.IsActive() then
		for _, id in penCreatures(data) do
			S.MutationService.Grant(player, id, "Shadow", "Stayed in the Heist Pen all night")
		end
	end
	lostThisNight[player] = 0
end

local function buildPen(player: Player, data: any)
	local plot = S.PlotService.GetPlot(player)
	if not plot or pens[player] then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "HeistPen"
	folder.Parent = plot.Folders.Buildings
	local pen: Pen = { Folder = folder, Spots = {}, Prompts = {} }
	local center = plot.Center + Config.World.PenOffset
	for index = 1, HEIST.PenSlots do
		local position = center + Vector3.new(0, 0, (index - 2) * 5)
		local pad = Build.Part({ Size = Vector3.new(4, 0.3, 4), Position = position + Vector3.new(0, 0.35, 0), Color = Color3.fromRGB(120, 60, 140), Material = Enum.Material.Neon, Transparency = 0.5, Parent = folder })
		local prompt = Build.Prompt(pad, "Steal", "Heist Pen", { Distance = 8, Hold = HEIST.GrabHoldSeconds })
		prompt:SetAttribute("Public", true)
		prompt.Triggered:Connect(function(thief)
			trySteal(thief, player, index)
		end)
		table.insert(pen.Spots, pad)
		table.insert(pen.Prompts, prompt)
	end
	local sign = Build.Part({ Size = Vector3.new(0.5, 4, 0.5), Position = center + Vector3.new(4, 2, 0), Color = Color3.fromRGB(60, 40, 70), Parent = folder })
	local gui = Build.Billboard(sign, 160, 30, 3)
	Build.Label(gui, "Heist Pen", { TextColor3 = Color3.fromRGB(230, 160, 255) })
	pens[player] = pen
end

function HeistService.Init() end

function HeistService.Start()
	S.AntiExploit.Bind("SetHeistFlag", onSetFlag, { KillSwitch = "Heist" })
	S.AntiExploit.Bind("SetPen", onSetPen, { KillSwitch = "Heist" })
	S.AntiExploit.Bind("LockPen", onLockPen, { KillSwitch = "Heist" })
	S.AntiExploit.Bind("StealBack", onStealBack, { KillSwitch = "Heist" })

	S.DataService.ProfileLoaded:Connect(function(player: Player, data: any)
		player:SetAttribute("HeistFlag", data.HeistFlag)
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- A thief leaving drops the creature; a victim leaving cancels carries from them
		endCarry(player, false)
		for thief, carry in carries do
			if carry.Victim == player then
				carry.Record.CaptiveAt = nil -- saved back home with the victim's profile
				carries[thief] = nil
				if carry.Glow then
					carry.Glow:Destroy()
				end
				setWalkSpeed(thief, 1)
			end
		end
		pens[player] = nil
		lostThisNight[player] = nil
		penLockedUntil[player] = nil
		lockCooldown[player] = nil
		stunnedUntil[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local data = S.DataService.GetData(player)
				if data and data.Unlocks.Heist then
					buildPen(player, data)
					-- Steal prompts only on occupied spots of a flagged garden
					local pen = pens[player]
					local occupied = penCreatures(data)
					for index, prompt in pen and pen.Prompts or {} do
						local creature = occupied[index] and data.Creatures[occupied[index]]
						Build.SetPrompt(prompt, if data.HeistFlag and creature then "Steal" else nil, if creature then GameMath.CreatureName(creature) else nil)
					end
				end
			end
			for thief, carry in carries do
				local plot = S.PlotService.GetPlot(thief)
				local root = S.AntiExploit.GetRootPosition(thief)
				if plot and root and S.PlotService.IsInside(plot, root) then
					endCarry(thief, true)
				elseif os.clock() - carry.StartedAt > HEIST.CarryTimeLimitSeconds then
					notify(thief, "Too slow! The creature ran home.")
					endCarry(thief, false)
				end
			end
		end
	end)
end

return HeistService
