--!strict
-- Social menu: players in the server with Visit, Shop and Trade buttons, Go Home, and the
-- "Allow visitors" privacy switch (Build Spec sections 15, 23.5). Also the leaderboards view.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("UI"):WaitForChild("Kit"))
local DataController = require(Client:WaitForChild("Controllers"):WaitForChild("DataController"))
local PanelController = require(Client:WaitForChild("Controllers"):WaitForChild("PanelController"))

local player = Players.LocalPlayer
local C = Kit.Colors

local SocialPanel = {}

local playerList: { any } = {}
local boards: { any } = {}

function SocialPanel.Open()
	local data = DataController.Get()
	if not data then
		return
	end
	local list = PanelController.Open("Social", "Friends & Visits")
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local top = Kit.Row(list, nextOrder(), 56)
	Kit.Button({ Text = "Go Home", TextSize = 15, Size = UDim2.new(0.5, -4, 0, 40), BackgroundColor3 = C.Good, ZIndex = 23, Parent = top }, function()
		Remotes.Get("VisitGarden"):FireServer(0)
	end)
	local open = data.Settings.VisitsOpen
	Kit.Button({ Text = if open then "Visitors: ON" else "Visitors: OFF", TextSize = 15, Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -4, 0, 40), BackgroundColor3 = if open then C.Accent else C.Locked, ZIndex = 23, Parent = top }, function()
		Remotes.Get("SetVisitsOpen"):FireServer(not open)
	end)

	if not data.Unlocks.FriendVisit then
		Kit.Label({ Text = "Visiting friends unlocks after your first night.", TextSize = 15, TextColor3 = C.Muted, LayoutOrder = nextOrder(), ZIndex = 22, Parent = list })
	elseif not data.Unlocks.Visit then
		Kit.Label({ Text = "You can visit friends now. Everyone else unlocks at stage 5 (Level 13).", TextSize = 14, TextColor3 = C.Muted, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), ZIndex = 22, Parent = list })
	end

	Kit.Heading(list, "Players in this server", nextOrder())
	for _, entry in playerList do
		if entry.UserId ~= player.UserId then
			local row = Kit.Row(list, nextOrder(), 56)
			Kit.Label({ Text = `{entry.Name}  (Lv {entry.Level})`, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -250, 1, 0), ZIndex = 23, Parent = row })
			if entry.VisitsOpen and data.Unlocks.FriendVisit then
				Kit.RowButton(row, 1, "Visit", C.Good, function()
					Remotes.Get("VisitGarden"):FireServer(entry.UserId)
					PanelController.Close()
				end)
			end
			if data.Unlocks.PlayerShop then
				Kit.RowButton(row, 2, "Shop", C.Accent, function()
					Remotes.Get("OpenStall"):FireServer(entry.UserId)
				end)
			end
			if data.Unlocks.Trading and entry.Trading then
				Kit.RowButton(row, 3, "Trade", C.Coins, function()
					Remotes.Get("TradeRequest"):FireServer(entry.UserId)
				end)
			end
		end
	end
	if #playerList <= 1 then
		Kit.Label({ Text = "Nobody else is here yet. Invite a friend!", TextSize = 15, TextColor3 = C.Muted, LayoutOrder = nextOrder(), ZIndex = 22, Parent = list })
	end
end

local function renderBoards()
	local list = PanelController.Open("Leaderboards", "Leaderboards")
	local order = 0
	if #boards == 0 then
		Kit.Label({ Text = "Loading...", TextSize = 16, TextColor3 = C.Muted, LayoutOrder = 1, ZIndex = 22, Parent = list })
	end
	for _, board in boards do
		order += 1
		Kit.Heading(list, board.Name, order)
		for rank, entry in board.Entries do
			order += 1
			Kit.Label({ Text = `{rank}. {entry.Name} - {entry.Value}`, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, ZIndex = 22, Parent = list })
		end
	end
end

function SocialPanel.OpenLeaderboards()
	Remotes.Get("RequestLeaderboards"):FireServer()
	renderBoards()
end

function SocialPanel.Start()
	Remotes.Get("PlayersUpdate").OnClientEvent:Connect(function(list)
		playerList = list
		PanelController.Refresh("Social", SocialPanel.Open)
	end)
	Remotes.Get("LeaderboardUpdate").OnClientEvent:Connect(function(payload)
		boards = payload
		PanelController.Refresh("Leaderboards", renderBoards)
	end)
	local last = 0
	DataController.Changed:Connect(function()
		if os.clock() - last > 2 then
			last = os.clock()
			PanelController.Refresh("Social", SocialPanel.Open)
		end
	end)
end

return SocialPanel
