--!strict
-- Modal panels: merchant cart, night report and the Help menu with a "Coming up" list
-- (Build Spec sections 18, 22.3). One panel is open at a time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Stages = require(ConfigFolder:WaitForChild("Stages"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))
local DataController = require(script.Parent:WaitForChild("DataController"))

local player = Players.LocalPlayer
local C = Kit.Colors

local PanelController = {}

local gui: ScreenGui
local current: Frame? = nil
local currentKind: string? = nil

local function close()
	if current then
		current:Destroy()
	end
	current, currentKind = nil, nil
end

local function open(kind: string, title: string): ScrollingFrame
	-- Animate only a fresh open, not a live refresh of the same panel
	local animate = currentKind ~= kind
	close()
	local panel, list = Kit.Panel(gui, title, close, animate)
	current, currentKind = panel, kind
	return list
end

-- Shared host for every panel module (client/Panels)
PanelController.Open = open
PanelController.Close = close

function PanelController.IsOpen(kind: string): boolean
	return currentKind == kind and current ~= nil
end

-- Re-open a panel keeping its scroll position (for live refreshes)
function PanelController.Refresh(kind: string, openFn: () -> ())
	if not PanelController.IsOpen(kind) then
		return
	end
	local scroll = current and current:FindFirstChildOfClass("ScrollingFrame")
	local position = scroll and scroll.CanvasPosition
	openFn()
	local newScroll = current and current:FindFirstChildOfClass("ScrollingFrame")
	if position and newScroll then
		newScroll.CanvasPosition = position
	end
end

local function textRow(list: Instance, text: string, order: number, color: Color3?, size: number?)
	local label = Kit.Label({ Text = text, TextSize = size or 17, TextColor3 = color or C.Text, TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, ZIndex = 22, Parent = list })
	return label
end

-- Merchant ------------------------------------------------------------------------------------------

local function offerRow(list: Instance, offer: any, order: number, quantities: { number })
	local row = Kit.New("Frame", { Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = C.PanelLight, LayoutOrder = order, ZIndex = 22, Parent = list }, { Kit.Corner(10), Kit.Padding(8) })
	local owned = if offer.Owned and offer.Owned > 0 then `  (have {offer.Owned})` else ""
	Kit.Label({ Text = offer.Name .. owned, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -150, 0, 24), ZIndex = 23, Parent = row })
	Kit.Label({ Text = offer.Info or "", TextSize = 13, Font = Enum.Font.Gotham, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -150, 0, 22), ZIndex = 23, Parent = row })

	if offer.Locked then
		Kit.Label({ Text = `Locked: {offer.Locked}`, TextSize = 14, TextColor3 = C.Muted, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(140, 44), ZIndex = 23, Parent = row })
		row.BackgroundColor3 = C.Locked
		return
	end
	for index, qty in quantities do
		local width = 68
		Kit.Button({
			Text = if qty == 1 then `{offer.Price}` else `x{qty}`,
			TextSize = 16,
			TextColor3 = if qty == 1 then C.Coins else C.Text,
			BackgroundColor3 = C.Panel,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -(#quantities - index) * (width + 6), 0.5, 0),
			Size = UDim2.fromOffset(width, 44),
			ZIndex = 23,
			Parent = row,
		}, function()
			Remotes.Get("BuyItem"):FireServer(offer.Id, qty)
		end)
	end
end

function PanelController.OpenMerchant(offers: any)
	local list = open("Merchant", "Merchant Cart")
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local sellText = if offers.SellCount > 0 then `Sell all ({offers.SellCount} items) for {offers.SellTotal} coins` else "Nothing to sell yet"
	textRow(list, `Bag: {offers.BagCount or 0}/{offers.Capacity or 0}`, nextOrder(), C.Muted, 15)
	Kit.Button({ Text = sellText, Size = UDim2.new(1, -8, 0, 52), BackgroundColor3 = if offers.SellCount > 0 then C.Good else C.Locked, LayoutOrder = nextOrder(), ZIndex = 22, Parent = list }, function()
		Remotes.Get("SellItems"):FireServer()
	end)

	Kit.Heading(list, "Seeds", nextOrder())
	for _, offer in offers.Seeds do
		offerRow(list, offer, nextOrder(), { 1, 5 })
	end
	if offers.Rare and #offers.Rare > 0 then
		Kit.Heading(list, "Rare restock!", nextOrder())
		for _, offer in offers.Rare do
			offerRow(list, offer, nextOrder(), { 1 })
		end
	elseif offers.RestockAt then
		textRow(list, `No rare items right now. Next restock in {math.max(0, math.floor(offers.RestockAt - workspace:GetServerTimeNow()))}s.`, nextOrder(), C.Muted, 14)
	end
	if #offers.Eggs > 0 then
		Kit.Heading(list, "Creature eggs", nextOrder())
		for _, offer in offers.Eggs do
			offerRow(list, offer, nextOrder(), { 1 })
		end
	end
	if #offers.Upgrades > 0 then
		Kit.Heading(list, "Upgrades", nextOrder())
		for _, offer in offers.Upgrades do
			offerRow(list, offer, nextOrder(), { 1 })
		end
	end
end

-- Night report -------------------------------------------------------------------------------------------

function PanelController.OpenReport(report: any)
	local list = open("Report", `Night {report.Night} survived!`)
	local order = 0
	for _, line in report.Lines do
		order += 1
		textRow(list, line, order)
	end
	for _, tip in report.Tips do
		order += 1
		textRow(list, "Tip: " .. tip, order, C.Muted, 15)
	end
	if report.InviteFriends then
		order += 1
		textRow(list, "Invite a friend to help defend your garden!", order, C.Coins)
		order += 1
		Kit.Button({ Text = "Invite friends", Size = UDim2.new(1, -8, 0, 48), BackgroundColor3 = C.Accent, LayoutOrder = order, ZIndex = 22, Parent = list }, function()
			pcall(function()
				SocialService:PromptGameInvite(player)
			end)
		end)
	end
	order += 1
	Kit.Button({ Text = "OK", Size = UDim2.new(1, -8, 0, 48), BackgroundColor3 = C.Good, LayoutOrder = order, ZIndex = 22, Parent = list }, close)
end

-- Help -------------------------------------------------------------------------------------------------------

local function requirementText(stage: Stages.Stage): string
	local trigger = stage.Trigger
	local parts = {}
	if trigger.Level then
		table.insert(parts, `Garden Level {trigger.Level}`)
	end
	if trigger.NightsSurvived then
		table.insert(parts, `survive {trigger.NightsSurvived} night(s)`)
	end
	if trigger.AdultCreatures then
		table.insert(parts, `{trigger.AdultCreatures} adult creatures`)
	end
	return table.concat(parts, " and ")
end

function PanelController.OpenHelp()
	local data = DataController.Get()
	local list = open("Help", "Help")
	local order = 0
	local function add(text: string, color: Color3?, size: number?)
		order += 1
		textRow(list, text, order, color, size)
	end

	-- Full guide and settings
	local top = Kit.Row(list, -3, 56)
	Kit.Button({ Text = "Full guide", TextSize = 15, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.Good, ZIndex = 23, Parent = top }, function()
		require(script.Parent.Parent:WaitForChild("Panels"):WaitForChild("GuidePanel")).Open()
	end)
	local settings = Kit.Row(list, -2, 56)
	local soundOn = not (data and data.Settings and data.Settings.SoundOn == false)
	local arrowOn = not (data and data.Settings and data.Settings.GuideArrow == false)
	Kit.Button({ Text = if soundOn then "Sound: ON" else "Sound: OFF", TextSize = 15, Size = UDim2.new(0.5, -4, 0, 40), BackgroundColor3 = if soundOn then C.Accent else C.Locked, ZIndex = 23, Parent = settings }, function()
		Remotes.Get("SetSetting"):FireServer("SoundOn", not soundOn)
		task.delay(0.5, PanelController.OpenHelp)
	end)
	Kit.Button({ Text = if arrowOn then "Goal arrow: ON" else "Goal arrow: OFF", TextSize = 15, Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -4, 0, 40), BackgroundColor3 = if arrowOn then C.Accent else C.Locked, ZIndex = 23, Parent = settings }, function()
		Remotes.Get("SetSetting"):FireServer("GuideArrow", not arrowOn)
		task.delay(0.5, PanelController.OpenHelp)
	end)

	Kit.Heading(list, "How to play", 0)
	add("Walk to soil and press E (or tap) to plant, water and harvest.", nil, 15)
	add("Sell crops at the merchant cart and buy more seeds.", nil, 15)
	add("Decor menu: stand on a soil tile and place a decoration (that tile grows no crops). Hold E on it to pick it up.", nil, 15)
	add("Upgrade Station (workbench in your garden): faster growing, faster walking and bigger harvests.", nil, 15)
	add("At night monsters come through the gates. Tap them or press Attack (F).", nil, 15)
	add("Creatures that survive the night can earn glowing mutations.", nil, 15)

	if data then
		order += 1
		Kit.Heading(list, "Unlocked", order)
		for _, stage in Stages.List do
			if stage.Id <= data.Stage then
				add(`{stage.Name}: {stage.Tip}`, nil, 15)
			end
		end

		order += 1
		Kit.Heading(list, "Coming up", order)
		local shown = 0
		for _, stage in Stages.List do
			if stage.Id > data.Stage and shown < 3 then
				shown += 1
				if stage.Id > Config.MaxStageEnabled then
					add(`{stage.Name}: coming soon in an update!`, C.Muted, 15)
				else
					add(`{stage.Name}: unlocks at {requirementText(stage)}`, C.Accent, 15)
					if stage.Trigger.Level then
						order += 1
						local back = Kit.New("Frame", { Size = UDim2.new(1, -8, 0, 10), BackgroundColor3 = C.PanelLight, LayoutOrder = order, ZIndex = 22, Parent = list }, { Kit.Corner(5) })
						Kit.New("Frame", { Size = UDim2.fromScale(math.clamp(data.GardenLevel / stage.Trigger.Level, 0, 1), 1), BackgroundColor3 = C.Good, ZIndex = 23, Parent = back }, { Kit.Corner(5) })
					end
				end
			end
		end
	end
end

function PanelController.Start()
	gui = Kit.New("ScreenGui", { Name = "MoonlitPanels", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

	Remotes.Get("MerchantOpen").OnClientEvent:Connect(function(offers)
		-- Refreshes after purchases only update an already open merchant panel or open a new one
		local scroll = if current and currentKind == "Merchant" then current:FindFirstChildOfClass("ScrollingFrame") else nil
		local position = if scroll then scroll.CanvasPosition else nil
		PanelController.OpenMerchant(offers)
		local newScroll = current and current:FindFirstChildOfClass("ScrollingFrame")
		if position and newScroll then
			newScroll.CanvasPosition = position
		end
	end)
	Remotes.Get("NightReport").OnClientEvent:Connect(PanelController.OpenReport)
end

return PanelController
