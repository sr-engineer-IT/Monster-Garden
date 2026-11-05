--!strict
-- DataService: session-locked player profiles through ProfileStore (Build Spec sections 16, 23.3).
-- Autosave every Config.AutosaveSeconds, save on leave and on shutdown (ProfileStore binds to close).
-- Other services read and change profile data through GetData(), then call MarkChanged().

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Types"))
local Util = require(Shared:WaitForChild("Util"))

local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore)
local DefaultProfile = require(script.DefaultProfile)
local Migrations = require(script.Migrations)

type ProfileData = Types.ProfileData

local SYNC_INTERVAL_SECONDS = 0.25 -- batches many changes into one client update

local DataService = {}

DataService.ProfileLoaded = Signal.new() :: Signal.Signal<Player, ProfileData>
DataService.ProfileReleasing = Signal.new() :: Signal.Signal<Player, ProfileData>

local store: any
local profiles: { [Player]: any } = {}
local dirty: { [Player]: boolean } = {}

-- Values every client can read from player attributes (HUD, other players' cards)
local REPLICATED_ATTRIBUTES = { "Coins", "Essence", "GardenLevel", "GardenXP", "Stage", "NightsSurvived" }

local function replicateAttributes(player: Player, data: ProfileData)
	for _, key in REPLICATED_ATTRIBUTES do
		player:SetAttribute(key, (data :: any)[key])
	end
end

-- Client view of the profile: drop purchase receipts
local function clientSnapshot(data: ProfileData): any
	local snapshot = Util.DeepCopy(data) :: any
	snapshot.Purchases = { PassesOwned = snapshot.Purchases.PassesOwned }
	return snapshot
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(Config.ProfileKeyPrefix .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Load failed or player left while waiting
		if player.Parent == Players then
			player:Kick("Your garden could not be loaded. Please rejoin in a moment.")
		end
		return
	end

	profile:AddUserId(player.UserId) -- GDPR

	local ok, reason = Migrations.Migrate(profile.Data, Config.SchemaVersion)
	if not ok then
		warn(`[DataService] {player.Name}: {reason}`)
		profile:EndSession()
		player:Kick("The game is updating. Please rejoin in a moment.")
		return
	end
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		dirty[player] = nil
		-- Fires on leave too; kicking a player who already left does nothing
		player:Kick("Your garden was opened on another server. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	local data = profile.Data :: ProfileData
	replicateAttributes(player, data)
	player:SetAttribute("DataLoaded", true)
	Remotes.Get("DataSync"):FireClient(player, clientSnapshot(data))

	print(`[DataService] Loaded {player.Name} (session #{profile.SessionLoadCount}, Coins {data.Coins})`)
	DataService.ProfileLoaded:Fire(player, data)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile == nil then
		return
	end
	local data = profile.Data :: ProfileData
	DataService.ProfileReleasing:Fire(player, data)
	data.LastSeen = os.time()
	profile:EndSession() -- saves and releases the session lock
end

function DataService.Init()
	ProfileStore.SetConstant("AUTO_SAVE_PERIOD", Config.AutosaveSeconds)

	store = ProfileStore.New(Config.DataStoreName, DefaultProfile)
	if RunService:IsStudio() and Config.UseMockDataStoreInStudio then
		store = store.Mock
		print("[DataService] Using mock DataStore in Studio")
	end

	ProfileStore.OnError:Connect(function(message, storeName, profileKey)
		warn(`[DataService] ProfileStore error ({storeName} / {profileKey}): {message}`)
	end)
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Remotes.Get("RequestSync").OnServerEvent:Connect(function(player)
		if profiles[player] then
			dirty[player] = true
		end
	end)

	-- Count online play time (aging, breeding and gestation use play time, never real time)
	task.spawn(function()
		while true do
			local elapsed = task.wait(Config.TickRateSeconds)
			for _, profile in profiles do
				profile.Data.PlaySeconds += elapsed
			end
		end
	end)

	-- Flush changed profiles to their owners in small batches
	task.spawn(function()
		while true do
			task.wait(SYNC_INTERVAL_SECONDS)
			for player in dirty do
				dirty[player] = nil
				local profile = profiles[player]
				if profile then
					replicateAttributes(player, profile.Data)
					Remotes.Get("DataSync"):FireClient(player, clientSnapshot(profile.Data))
				end
			end
		end
	end)
end

-- Returns the live profile data table, or nil while loading / after leaving.
-- Do not keep this reference across yields without checking IsLoaded again.
function DataService.GetData(player: Player): ProfileData?
	local profile = profiles[player]
	return if profile then profile.Data :: ProfileData else nil
end

-- Raw ProfileStore profile (for receipts that need Profile:Save / LastSavedData)
function DataService.GetProfile(player: Player): any
	return profiles[player]
end

function DataService.IsLoaded(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile:IsActive()
end

-- Yields until the profile is loaded or the player leaves / times out
function DataService.WaitForData(player: Player, timeoutSeconds: number?): ProfileData?
	local deadline = os.clock() + (timeoutSeconds or 30)
	while player.Parent == Players and os.clock() < deadline do
		local data = DataService.GetData(player)
		if data then
			return data
		end
		task.wait(0.1)
	end
	return nil
end

-- Call after changing a player's data so the HUD and client view update
function DataService.MarkChanged(player: Player)
	if profiles[player] then
		dirty[player] = true
	end
end

-- Studio/dev only: replace the profile with a fresh default. The player should rejoin after.
function DataService.ResetData(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Data = Util.DeepCopy(DefaultProfile)
		DataService.MarkChanged(player)
	end
end

return DataService
