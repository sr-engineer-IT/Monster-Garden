--!strict
-- SocialService: garden visits (friends from stage 2, everyone from stage 5), visit privacy,
-- neighbor attack alerts, cross-server leaderboards (MemoryStore) and overhead titles
-- (Build Spec sections 4.5, 15, 17).

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local S = require(script.Parent.Parent.Registry)
local Build = require(script.Parent.Parent.Build)

local SocialService = {}

local LB = Config.Leaderboard
local boards: { [string]: { { Name: string, Value: number } } } = {}
local friendCache: { [string]: boolean } = {}

local function notify(player: Player, text: string)
	Remotes.Get("Notify"):FireClient(player, { Text = text })
end

local function isFriend(a: Player, b: Player): boolean
	local key = if a.UserId < b.UserId then `{a.UserId}:{b.UserId}` else `{b.UserId}:{a.UserId}`
	if friendCache[key] == nil then
		local ok, result = pcall(function()
			return a:IsFriendsWith(b.UserId)
		end)
		friendCache[key] = ok and result == true
	end
	return friendCache[key]
end

-- Visits ----------------------------------------------------------------------------------------------

function SocialService.CanVisit(visitor: Player, owner: Player): boolean
	local visitorData = S.DataService.GetData(visitor)
	local ownerData = S.DataService.GetData(owner)
	if not visitorData or not ownerData or not ownerData.Settings.VisitsOpen then
		return false
	end
	if visitorData.Unlocks.Visit then
		return true
	end
	return visitorData.Unlocks.FriendVisit == true and isFriend(visitor, owner)
end

local function teleport(player: Player, plot: any)
	local character = player.Character
	if character and plot then
		local spawnAt = plot.Center + Config.World.SpawnOffset + Vector3.new(0, 4, 0)
		character:PivotTo(CFrame.lookAt(spawnAt, plot.Center + Vector3.new(0, 4, 0)))
	end
end

local function onVisit(player: Player, data: any, userId: any)
	if not S.AntiExploit.TryCooldown(player, "Visit", Config.VisitCooldownSeconds) then
		return
	end
	if userId == 0 or userId == player.UserId then
		teleport(player, S.PlotService.GetPlot(player))
		return
	end
	local owner = type(userId) == "number" and Players:GetPlayerByUserId(userId)
	if not owner then
		return
	end
	if not SocialService.CanVisit(player, owner) then
		notify(player, "You can't visit that garden (friends only before stage 5, or visits are closed).")
		return
	end
	teleport(player, S.PlotService.GetPlot(owner))
	notify(owner, `{player.DisplayName} is visiting your garden!`)
	S.ObjectiveService.Progress(player, "Visit")
end

local function onSetVisitsOpen(player: Player, data: any, open: any)
	if type(open) == "boolean" then
		data.Settings.VisitsOpen = open
		S.DataService.MarkChanged(player)
		SocialService.BroadcastPlayers()
	end
end

function SocialService.BroadcastPlayers()
	local list = {}
	for _, player in Players:GetPlayers() do
		local data = S.DataService.GetData(player)
		if data then
			table.insert(list, { UserId = player.UserId, Name = player.DisplayName, Level = data.GardenLevel, Stage = data.Stage, VisitsOpen = data.Settings.VisitsOpen, Trading = data.Unlocks.Trading == true })
		end
	end
	Remotes.Get("PlayersUpdate"):FireAllClients(list)
end

-- Big attack nearby: tell players who could come and help (section 15)
function SocialService.NeighborAlert(owner: Player)
	for _, player in Players:GetPlayers() do
		if player ~= owner and S.DayNightService.GetPhase(player) == "Day" and SocialService.CanVisit(player, owner) then
			Remotes.Get("NeighborAlert"):FireClient(player, { OwnerUserId = owner.UserId, Name = owner.DisplayName })
		end
	end
end

function SocialService.OnHelpedDefend(helper: Player, owner: Player)
	local data = S.DataService.GetData(helper)
	if data then
		data.Stats.Helped = (data.Stats.Helped or 0) + 1
	end
end

-- Overhead title ---------------------------------------------------------------------------------------

function SocialService.RefreshTitle(player: Player)
	local data = S.DataService.GetData(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not data or not head then
		return
	end
	local old = head:FindFirstChild("TitleGui")
	if old then
		old:Destroy()
	end
	local gui = Build.Billboard(head, 200, 40, 2.6)
	gui.Name = "TitleGui"
	gui.MaxDistance = 60
	local title = data.Equipped.Title
	local text = `Lv {data.GardenLevel}` .. (if title and data.Titles[title] then `  {title}` else "")
	Build.Label(gui, text, { TextColor3 = if title then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(230, 230, 240) })
end

-- Leaderboards -----------------------------------------------------------------------------------------

local function statValue(data: any, category: string): number
	if category == "GardenLevel" then
		return data.GardenLevel
	elseif category == "NightsSurvived" then
		return data.NightsSurvived
	end
	return data.Stats[category] or 0
end

local function refreshBoards()
	for _, category in LB.Categories do
		local ok = pcall(function()
			local map = MemoryStoreService:GetSortedMap(LB.MapName .. "_" .. category.Id)
			for _, player in Players:GetPlayers() do
				local data = S.DataService.GetData(player)
				if data then
					local value = statValue(data, category.Id)
					map:SetAsync(tostring(player.UserId), { Name = player.DisplayName, Value = value }, LB.ExpirationSeconds, value)
				end
			end
			local entries = map:GetRangeAsync(Enum.SortDirection.Descending, LB.TopCount)
			local list = {}
			for _, entry in entries do
				table.insert(list, { Name = entry.value.Name, Value = entry.value.Value })
			end
			boards[category.Id] = list
		end)
		if not ok then
			-- No MemoryStore (e.g. Studio without API access): rank this server only
			local list = {}
			for _, player in Players:GetPlayers() do
				local data = S.DataService.GetData(player)
				if data then
					table.insert(list, { Name = player.DisplayName, Value = statValue(data, category.Id) })
				end
			end
			table.sort(list, function(a, b)
				return a.Value > b.Value
			end)
			boards[category.Id] = list
		end
	end
end

local function sendBoards(player: Player)
	local payload = {}
	for _, category in LB.Categories do
		table.insert(payload, { Id = category.Id, Name = category.Name, Entries = boards[category.Id] or {} })
	end
	Remotes.Get("LeaderboardUpdate"):FireClient(player, payload)
end

function SocialService.Init() end

function SocialService.Start()
	S.AntiExploit.Bind("VisitGarden", onVisit)
	S.AntiExploit.Bind("SetVisitsOpen", onSetVisitsOpen)
	S.AntiExploit.Bind("RequestLeaderboards", function(player: Player)
		sendBoards(player)
	end)

	S.DataService.ProfileLoaded:Connect(function(player: Player)
		SocialService.BroadcastPlayers()
		SocialService.RefreshTitle(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			SocialService.RefreshTitle(player)
		end)
		player:GetAttributeChangedSignal("GardenLevel"):Connect(function()
			SocialService.RefreshTitle(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(SocialService.BroadcastPlayers)
	end)

	task.spawn(function()
		while true do
			refreshBoards()
			task.wait(LB.RefreshSeconds)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(10)
			SocialService.BroadcastPlayers()
		end
	end)
end

return SocialService
