--!strict
-- Trading panel (stage 9): incoming request popup, both offers side by side, an offer editor,
-- Accept/Cancel, and the safety countdown before the swap.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("UI"):WaitForChild("Kit"))
local DataController = require(Client:WaitForChild("Controllers"):WaitForChild("DataController"))
local PanelController = require(Client:WaitForChild("Controllers"):WaitForChild("PanelController"))

local player = Players.LocalPlayer
local C = Kit.Colors

local TradePanel = {}

local session: any = nil
local draft = { Coins = 0, Goods = {} :: { [string]: number }, Creatures = {} :: { string } }

local function sendDraft()
	Remotes.Get("TradeOffer"):FireServer(draft)
end

local function describeOffer(list: Instance, offer: any, order: number): number
	order += 1
	Kit.Label({ Text = `Coins: {offer.Coins}`, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, ZIndex = 22, Parent = list })
	for _, goods in offer.Goods do
		order += 1
		Kit.Label({ Text = `{goods.Name} x{goods.Qty}`, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, ZIndex = 22, Parent = list })
	end
	for _, creature in offer.Creatures do
		order += 1
		Kit.Label({ Text = `{creature.Name} ({creature.Info})`, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, ZIndex = 22, Parent = list })
	end
	return order
end

local function render()
	if not session then
		return
	end
	local data = DataController.Get()
	local list = PanelController.Open("Trade", `Trade with {session.Partner}`)
	local order = 0
	Kit.Heading(list, `They offer {if session.AcceptedTheirs then "(accepted)" else ""}`, order)
	order = describeOffer(list, session.Theirs, order)
	order += 1
	Kit.Heading(list, `You offer {if session.AcceptedMine then "(accepted)" else ""}`, order)
	order = describeOffer(list, session.Mine, order)

	if session.ConfirmAt then
		order += 1
		local left = math.max(0, math.ceil(session.ConfirmAt - Workspace:GetServerTimeNow()))
		Kit.Label({ Text = `Both accepted. Trading in {left}s... (Cancel to stop)`, TextSize = 16, TextColor3 = C.Coins, LayoutOrder = order, ZIndex = 22, Parent = list })
	end

	order += 1
	local actions = Kit.Row(list, order, 56)
	Kit.Button({ Text = "Accept", Size = UDim2.new(0.5, -4, 0, 40), BackgroundColor3 = C.Good, ZIndex = 23, Parent = actions }, function()
		Remotes.Get("TradeAccept"):FireServer()
	end)
	Kit.Button({ Text = "Cancel", Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -4, 0, 40), BackgroundColor3 = C.Bad, ZIndex = 23, Parent = actions }, function()
		Remotes.Get("TradeCancel"):FireServer()
	end)

	if not data then
		return
	end
	order += 1
	Kit.Heading(list, "Edit your offer", order)
	order += 1
	local coinRow = Kit.Row(list, order, 56)
	Kit.Label({ Text = "Coins", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -170, 1, 0), ZIndex = 23, Parent = coinRow })
	local coinInput = Kit.Input({ Text = tostring(draft.Coins), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -84, 0.5, 0), Size = UDim2.fromOffset(78, 40), Parent = coinRow })
	Kit.RowButton(coinRow, 1, "Set", C.Accent, function()
		draft.Coins = math.clamp(math.floor(tonumber(coinInput.Text) or 0), 0, data.Coins)
		sendDraft()
	end)
	for key, count in data.Inventory.Goods do
		order += 1
		local row = Kit.Row(list, order, 52)
		local offered = draft.Goods[key] or 0
		Kit.Label({ Text = `{GameMath.GoodsName(key)}: {offered}/{count}`, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -110, 1, 0), ZIndex = 23, Parent = row })
		Kit.RowButton(row, 1, "+", C.Good, function()
			draft.Goods[key] = math.min(count, (draft.Goods[key] or 0) + 1)
			sendDraft()
		end, 44)
		Kit.RowButton(row, 2, "-", C.Bad, function()
			local value = (draft.Goods[key] or 0) - 1
			draft.Goods[key] = if value > 0 then value else nil
			sendDraft()
		end, 44)
	end
	for id, creature in data.Creatures do
		if not GameMath.IsProtected(creature) then
			order += 1
			local row = Kit.Row(list, order, 52)
			local index = table.find(draft.Creatures, id)
			Kit.Label({ Text = GameMath.CreatureName(creature), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -100, 1, 0), ZIndex = 23, Parent = row })
			Kit.RowButton(row, 1, if index then "Remove" else "Offer", if index then C.Bad else C.Good, function()
				if index then
					table.remove(draft.Creatures, index)
				else
					table.insert(draft.Creatures, id)
				end
				sendDraft()
			end, 90)
		end
	end
end

local function showRequest(from: string)
	local gui = Kit.New("ScreenGui", { Name = "TradeRequest", ResetOnSpawn = false, DisplayOrder = 8, Parent = player:WaitForChild("PlayerGui") })
	local frame = Kit.New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.3, 0), Size = UDim2.fromOffset(320, 130), BackgroundColor3 = C.Panel, Parent = gui }, { Kit.Corner(14), Kit.Padding(10) })
	Kit.Label({ Text = `{from} wants to trade`, TextSize = 20, Size = UDim2.new(1, 0, 0, 30), Parent = frame })
	local function respond(accept: boolean)
		Remotes.Get("TradeRespond"):FireServer(accept)
		gui:Destroy()
	end
	Kit.Button({ Text = "Accept", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(0.5, -4, 0, 44), BackgroundColor3 = C.Good, Parent = frame }, function()
		respond(true)
	end)
	Kit.Button({ Text = "Decline", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.new(0.5, -4, 0, 44), BackgroundColor3 = C.Bad, Parent = frame }, function()
		respond(false)
	end)
	task.delay(30, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

function TradePanel.Start()
	Remotes.Get("TradeUpdate").OnClientEvent:Connect(function(payload)
		if payload.Kind == "Request" then
			showRequest(payload.From)
		elseif payload.Kind == "Session" then
			if session == nil then
				draft = { Coins = 0, Goods = {}, Creatures = {} }
			end
			session = payload
			render()
		elseif payload.Kind == "Closed" then
			session = nil
			if PanelController.IsOpen("Trade") then
				PanelController.Close()
			end
			if payload.Reason then
				require(Client.Controllers.HUDController).Toast(payload.Reason)
			end
		end
	end)
	-- Keep the countdown ticking
	task.spawn(function()
		while true do
			task.wait(1)
			if session and session.ConfirmAt and PanelController.IsOpen("Trade") then
				PanelController.Refresh("Trade", render)
			end
		end
	end)
end

return TradePanel
