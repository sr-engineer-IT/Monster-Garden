--!strict
-- HungerService: the shared server Hunger Meter (Build Spec section 11). Active only when enough
-- players in the server reached stage 6; only those players see and feel it.
-- Rises when monsters are driven away without eating, falls when monsters eat, Lure Berries are
-- thrown, and slowly every in-game day. Rise is capped per night window. At 100: Feast Night.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Config"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local S = require(script.Parent.Parent.Registry)

local HungerService = {}

local HUNGER = Config.Hunger
local NIGHT_WINDOW_SECONDS = Config.DayLengthFullSeconds + Config.NightLengthFullSeconds

local value = 0
local risenThisWindow = 0
local windowTimer = 0
local dayTimer = 0
local dirty = true

local function minPlayers(required: number): number
	return if RunService:IsStudio() then math.min(required, Config.StudioMinPlayersOverride) else required
end

-- Players at or above a stage in this server
function HungerService.CountAtStage(stage: number): number
	local count = 0
	for _, player in Players:GetPlayers() do
		local data = S.DataService.GetData(player)
		if data and data.Stage >= stage then
			count += 1
		end
	end
	return count
end

function HungerService.MinPlayers(required: number): number
	return minPlayers(required)
end

function HungerService.IsActive(): boolean
	return HungerService.CountAtStage(6) >= minPlayers(HUNGER.MinPlayersAtStage)
end

function HungerService.GetValue(): number
	return value
end

function HungerService.GetLevelName(): string
	if not HungerService.IsActive() then
		return "Calm"
	end
	return GameMath.HungerLevel(value).Name
end

function HungerService.Set(newValue: number)
	value = math.clamp(newValue, HUNGER.Min, HUNGER.Max)
	dirty = true
end

function HungerService.Add(delta: number, _source: Player?)
	if not HungerService.IsActive() or delta == 0 then
		return
	end
	if delta > 0 then
		delta = math.min(delta, HUNGER.MaxRisePerNight - risenThisWindow)
		if delta <= 0 then
			return
		end
		risenThisWindow += delta
	end
	local before = value
	HungerService.Set(value + delta)
	if before < HUNGER.Max and value >= HUNGER.Max then
		S.FeastService.OnHungerFull()
	end
end

local function onThrowLureBerry(player: Player, data: any)
	if not data.Unlocks.LureBerry then
		return
	end
	if (data.Inventory.Goods.lureberry or 0) <= 0 and (data.Inventory.Goods["lureberry#Moonlit"] or 0) <= 0 then
		Remotes.Get("Notify"):FireClient(player, { Text = "Grow Lure Berries first (merchant, stage 6)." })
		return
	end
	local key = if (data.Inventory.Goods.lureberry or 0) > 0 then "lureberry" else "lureberry#Moonlit"
	data.Inventory.Goods[key] -= 1
	if data.Inventory.Goods[key] <= 0 then
		data.Inventory.Goods[key] = nil
	end
	HungerService.Add(HUNGER.LureBerry, player)
	Remotes.Get("Notify"):FireClient(player, { Text = `You fed the monsters. Hunger {math.floor(value)}` })
	S.ObjectiveService.Progress(player, "LureBerry")
	S.DataService.MarkChanged(player)
end

function HungerService.Init() end

function HungerService.Start()
	S.AntiExploit.Bind("ThrowLureBerry", onThrowLureBerry)
	Players.PlayerAdded:Connect(function()
		dirty = true
	end)
	Players.PlayerRemoving:Connect(function()
		dirty = true
	end)

	task.spawn(function()
		while true do
			local dt = task.wait(1)
			windowTimer += dt
			if windowTimer >= NIGHT_WINDOW_SECONDS then
				windowTimer = 0
				risenThisWindow = 0
			end
			dayTimer += dt
			if dayTimer >= Config.DayLengthFullSeconds then
				dayTimer = 0
				if HungerService.IsActive() then
					HungerService.Set(value + HUNGER.PerDayCooldown)
				end
			end
			if dirty then
				dirty = false
				local active = HungerService.IsActive()
				local level = GameMath.HungerLevel(value)
				Remotes.Get("HungerUpdate"):FireAllClients({ Value = value, Level = level.Name, Active = active })
			end
		end
	end)
end

return HungerService
