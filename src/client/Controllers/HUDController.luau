--!strict
-- HUD that grows with stages (Build Spec section 18). Layout follows what players know from top
-- Roblox simulators and keeps clear of the Roblox chat window (top left):
--   top center   goal, day/night timer and a short "what to do" hint
--   top right    coins, Essence, level with XP bar, monster count, Hunger Meter
--   bottom left  big square menu buttons with icons (red bubble when something waits there)
--   bottom center seed hotbar (keys 1-9 on PC)
--   bottom right Attack button and context actions
-- Banners and toasts appear in the middle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Crops = require(ConfigFolder:WaitForChild("Crops"))
local Objectives = require(ConfigFolder:WaitForChild("Objectives"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("UI"):WaitForChild("Kit"))
local DataController = require(script.Parent:WaitForChild("DataController"))
local CombatController = require(script.Parent:WaitForChild("CombatController"))

local player = Players.LocalPlayer
local C = Kit.Colors

local HUDController = {}

local gui: ScreenGui
local coinsLabel: TextLabel
local essencePill: Frame
local essenceLabel: TextLabel
local levelLabel: TextLabel
local xpLabel: TextLabel
local xpFill: Frame
local objectiveLabel: TextLabel
local objectiveBar: Frame
local objectiveFill: Frame
local timerLabel: TextLabel
local hintLabel: TextLabel
local threatLabel: TextLabel
local hungerFrame: Frame
local hungerLabel: TextLabel
local hungerFill: Frame
local feastLabel: TextLabel
local seedBar: Frame
local attackButton: TextButton
local actionColumn: Frame
local menuButtons: { [string]: TextButton } = {}
local menuBadges: { [string]: TextLabel } = {}
local actionButtons: { [string]: TextButton } = {}
local toastHolder: Frame
local bannerFrame: Frame
local bannerScale: UIScale
local bannerTitle: TextLabel
local bannerText: TextLabel

local data: any = nil
local hunger = { Value = 0, Level = "Calm", Active = false }
local feast: any = { Phase = "None" }
local alertOwner: { UserId: number, Name: string, Until: number }? = nil
local selectedSeed: string? = nil
local ownedSeeds: { any } = {}
local seedKey = ""
local bannerQueue: { { Title: string, Text: string } } = {}
local bannerBusy = false

local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine }

local function panels(name: string): any
	return require(Client:WaitForChild("Panels"):WaitForChild(name))
end

local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Banners and toasts --------------------------------------------------------------------------

local function runBanners()
	if bannerBusy then
		return
	end
	bannerBusy = true
	while #bannerQueue > 0 do
		local entry = table.remove(bannerQueue, 1) :: { Title: string, Text: string }
		bannerTitle.Text = entry.Title
		bannerText.Text = entry.Text
		bannerText.Visible = entry.Text ~= ""
		bannerFrame.Visible = true
		bannerScale.Scale = 0.5
		TweenService:Create(bannerScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.wait(3.8)
		TweenService:Create(bannerScale, TweenInfo.new(0.15), { Scale = 0.7 }):Play()
		task.wait(0.15)
		bannerFrame.Visible = false
		task.wait(0.2)
	end
	bannerBusy = false
end

function HUDController.ShowBanner(title: string, text: string?)
	table.insert(bannerQueue, { Title = title, Text = text or "" })
	task.spawn(runBanners)
end

-- Big celebration (first Moonlit glow and other special moments): title, confetti, fanfare.
-- Shows above every panel; tap anywhere or wait 6 seconds to close.
function HUDController.Celebrate(title: string, line1: string, line2: string?)
	local screen = Kit.New("ScreenGui", { Name = "Celebration", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30, Parent = player:WaitForChild("PlayerGui") })
	local backdrop = Kit.New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(10, 14, 40), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = screen })
	TweenService:Create(backdrop, TweenInfo.new(0.3), { BackgroundTransparency = 0.45 }):Play()

	local card = Kit.New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(620, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 5, Parent = screen }, {
		Kit.New("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local scale = Kit.New("UIScale", { Scale = 0.3, Parent = card })
	Kit.Label({ Text = title, TextSize = 72, TextColor3 = C.Coins, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 80), LayoutOrder = 1, ZIndex = 6, Parent = card })
	Kit.Label({ Text = line1, TextSize = 34, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 2, ZIndex = 6, Parent = card })
	if line2 then
		Kit.Label({ Text = line2, TextSize = 20, TextColor3 = C.Muted, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 3, ZIndex = 6, Parent = card })
	end
	Kit.Label({ Text = "Tap to continue", TextSize = 16, TextColor3 = C.Muted, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 4, ZIndex = 6, Parent = card })
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local target = math.clamp(math.min(viewport.Y / 760, viewport.X / 1100), 0.55, 1)
	TweenService:Create(scale, TweenInfo.new(0.55, Enum.EasingStyle.Back), { Scale = target }):Play()

	-- confetti
	local colors = { C.Coins, C.Good, C.Bad, C.Premium, Color3.fromRGB(110, 200, 255), Color3.fromRGB(255, 140, 200) }
	for i = 1, 90 do
		local piece = Kit.New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(math.random(), 0, -0.05 - math.random() * 0.3, 0),
			Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22)),
			Rotation = math.random(0, 360),
			BackgroundColor3 = colors[(i % #colors) + 1],
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = screen,
		})
		local fall = TweenInfo.new(2.2 + math.random() * 1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(piece, fall, { Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.25, 0, 1.1, 0), Rotation = piece.Rotation + math.random(-540, 540) }):Play()
	end

	pcall(function()
		require(script.Parent:WaitForChild("SoundController")).Play("LevelUp")
	end)
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0 }):Play()
		TweenService:Create(backdrop, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		task.delay(0.3, function()
			screen:Destroy()
		end)
	end
	backdrop.Activated:Connect(close)
	task.delay(6, close)
end

function HUDController.Toast(text: string, color: Color3?)
	local pill = Kit.Pill({ Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Parent = toastHolder }, {
		Kit.New("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }),
		Kit.New("UISizeConstraint", { MaxSize = Vector2.new(520, 40) }),
	})
	local label = Kit.Label({ Text = text, TextSize = 19, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextColor3 = color or C.Text, Parent = pill })
	local scale = Kit.New("UIScale", { Scale = 0.6, Parent = pill })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local pills = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(pills, child)
		end
	end
	if #pills > 3 then
		pills[1]:Destroy()
	end
	task.delay(2.8, function()
		if pill.Parent then
			TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0 }):Play()
			task.wait(0.22)
			pill:Destroy()
		end
	end)
	return label
end

-- Layout -----------------------------------------------------------------------------------------

-- HUD groups shrink on small screens (phones) so they never cover the play area
local scales: { UIScale } = {}
local function fit(frame: GuiObject)
	table.insert(scales, Kit.New("UIScale", { Parent = frame }))
end
local function updateScale()
	local camera = Workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local value = math.clamp(math.min(size.Y / 760, size.X / 1100), 0.58, 1)
	for _, scale in scales do
		scale.Scale = value
	end
end

local function vlist(parent: Instance, padding: number?, align: Enum.HorizontalAlignment?)
	Kit.New("UIListLayout", { Padding = UDim.new(0, padding or 4), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = align or Enum.HorizontalAlignment.Left, Parent = parent })
end

-- Square menu button: big icon on top, name underneath
local function menuButton(parent: Instance, name: string, color: Color3, order: number, onClick: () -> ()): TextButton
	local button = Kit.Button({ Text = "", Size = UDim2.fromOffset(76, 76), BackgroundColor3 = color, LayoutOrder = order, Parent = parent }, onClick)
	Kit.Label({ Text = (Kit.Icons :: any)[name] or "", TextSize = 32, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 38), Parent = button })
	Kit.Label({ Text = name, TextSize = 16, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -5), Size = UDim2.new(1, 0, 0, 20), Parent = button })
	menuBadges[name] = Kit.Badge(button)
	return button
end

local function buildMenu()
	local menu = Kit.New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14), Size = UDim2.fromOffset(160, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = gui }, {
		Kit.New("UIGridLayout", { CellSize = UDim2.fromOffset(76, 76), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom }),
	})
	fit(menu)
	local entries = {
		{ "Store", Color3.fromRGB(72, 206, 88), function()
			panels("StorePanel").Open()
		end },
		{ "Season", Color3.fromRGB(178, 92, 255), function()
			panels("StorePanel").OpenSeason()
		end },
		{ "Quests", Color3.fromRGB(255, 196, 40), function()
			panels("QuestsPanel").Open()
		end },
		{ "Pets", Color3.fromRGB(255, 150, 40), function()
			panels("CreaturesPanel").Open()
		end },
		{ "Style", Color3.fromRGB(255, 92, 168), function()
			panels("StorePanel").OpenStyle()
		end },
		{ "Friends", Color3.fromRGB(40, 196, 200), function()
			panels("SocialPanel").Open()
		end },
		{ "Ranks", Color3.fromRGB(240, 186, 30), function()
			panels("SocialPanel").OpenLeaderboards()
		end },
		{ "Help", Color3.fromRGB(70, 140, 255), function()
			require(script.Parent:WaitForChild("PanelController")).OpenHelp()
		end },
	}
	for index, entry in entries do
		menuButtons[entry[1]] = menuButton(menu, entry[1], entry[2], index, entry[3])
	end
end

local function buildActions()
	actionColumn = Kit.New("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -150), Size = UDim2.fromOffset(180, 340), BackgroundTransparency = 1, Parent = gui }, {
		Kit.New("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	fit(actionColumn)
	local function add(id: string, text: string, color: Color3, order: number, onClick: () -> ())
		actionButtons[id] = Kit.Button({ Text = text, TextSize = 18, Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = color, LayoutOrder = order, Visible = false, Parent = actionColumn }, onClick)
	end
	add("Alert", "Help neighbor", C.Accent, 1, function()
		if alertOwner then
			Remotes.Get("VisitGarden"):FireServer(alertOwner.UserId)
			alertOwner = nil
		end
	end)
	add("StealBack", "Steal Back", C.Bad, 2, function()
		Remotes.Get("StealBack"):FireServer(player:GetAttribute("StolenId"))
	end)
	add("Supply", "Supply crops", C.Accent, 3, function()
		Remotes.Get("FeastSupply"):FireServer()
	end)
	add("Lure", "Lure Berry", Color3.fromRGB(220, 70, 210), 4, function()
		Remotes.Get("ThrowLureBerry"):FireServer()
	end)
	add("LockPen", "Lock Pen", C.Premium, 5, function()
		Remotes.Get("LockPen"):FireServer()
	end)
	add("Flag", "Heist Flag", C.Premium, 6, function()
		Remotes.Get("SetHeistFlag"):FireServer(not (data and data.HeistFlag))
	end)
	add("Veteran", "I know this game", Color3.fromRGB(70, 140, 255), 7, function()
		Remotes.Get("VeteranSkip"):FireServer()
	end)
end

-- Currency pill: icon on the left, big number
local function currencyPill(parent: Instance, icon: string, color: Color3, order: number): (Frame, TextLabel)
	local pill = Kit.Pill({ Size = UDim2.fromOffset(190, 46), LayoutOrder = order, Parent = parent })
	Kit.Label({ Text = icon, TextSize = 28, Position = UDim2.fromOffset(6, 0), Size = UDim2.new(0, 38, 1, 0), Parent = pill })
	local label = Kit.Label({ Text = "0", TextSize = 26, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -56, 1, 0), Parent = pill })
	return pill, label
end

local function buildLayout()
	gui = Kit.New("ScreenGui", { Name = "MoonlitHUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

	-- Top right: coins, Essence, level, threat, Hunger
	local right = Kit.New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 10), Size = UDim2.fromOffset(190, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = gui })
	vlist(right, 8, Enum.HorizontalAlignment.Right)
	fit(right)
	local coinPill, coins = currencyPill(right, Kit.Icons.Coins, C.Coins, 1)
	coinsLabel = coins
	coinsLabel.Size = UDim2.new(1, -96, 1, 0)
	-- "+" opens the store at the coin packs (top of the store)
	local plus = Kit.Button({ Text = "+", TextSize = 26, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = C.Good, ZIndex = 2, Parent = coinPill }, function()
		panels("StorePanel").Open()
	end)
	plus:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	essencePill, essenceLabel = currencyPill(right, Kit.Icons.Essence, C.Essence, 2)
	essencePill.Visible = false

	local levelPill = Kit.Pill({ Size = UDim2.fromOffset(190, 52), LayoutOrder = 3, Parent = right })
	local star = Kit.Label({ Text = "1", TextSize = 20, BackgroundTransparency = 0, BackgroundColor3 = C.Accent, Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(40, 40), Parent = levelPill })
	Kit.Corner(20).Parent = star
	Kit.Stroke(C.Stroke, 2.5).Parent = star
	Kit.Gradient(0.7).Parent = star
	levelLabel = star
	Kit.Label({ Text = "Level", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(54, 5), Size = UDim2.new(0.5, -40, 0, 18), Parent = levelPill })
	xpLabel = Kit.Label({ Text = "", TextSize = 13, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6), Size = UDim2.new(0.6, -10, 0, 16), Parent = levelPill })
	local _, fill = Kit.Bar({ Position = UDim2.fromOffset(54, 27), Size = UDim2.new(1, -64, 0, 14), Parent = levelPill }, C.Good)
	xpFill = fill

	threatLabel = Kit.Chip({ Text = "", TextSize = 20, Size = UDim2.fromOffset(190, 44), BackgroundColor3 = C.Bad, LayoutOrder = 4, Visible = false, Parent = right })
	hungerFrame = Kit.Pill({ Size = UDim2.fromOffset(190, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, Visible = false, Parent = right }, { Kit.Padding(8, 10) })
	vlist(hungerFrame, 6)
	hungerLabel = Kit.Label({ Text = "", TextSize = 15, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = hungerFrame })
	local _, hFill = Kit.Bar({ Size = UDim2.new(1, 0, 0, 12), LayoutOrder = 2, Parent = hungerFrame }, Color3.fromRGB(255, 140, 50))
	hungerFill = hFill

	-- Top center: goal, timer, hint
	local center = Kit.New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(420, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = gui })
	vlist(center, 6, Enum.HorizontalAlignment.Center)
	fit(center)
	local goal = Kit.Pill({ Size = UDim2.fromOffset(420, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = center }, { Kit.Padding(8, 14) })
	vlist(goal, 6, Enum.HorizontalAlignment.Center)
	objectiveLabel = Kit.Label({ Text = "", TextSize = 21, TextColor3 = C.Coins, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = goal })
	objectiveBar, objectiveFill = Kit.Bar({ Size = UDim2.new(0.75, 0, 0, 12), LayoutOrder = 2, Parent = goal }, C.Coins)
	timerLabel = Kit.Chip({ Text = "", TextSize = 18, TextWrapped = false, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34), BackgroundColor3 = C.Panel, LayoutOrder = 2, Parent = center })
	Kit.New("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = timerLabel })
	hintLabel = Kit.Label({ Text = "", TextSize = 16, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 3, Parent = center })

	feastLabel = Kit.Chip({ Text = "", TextSize = 20, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 190), Size = UDim2.fromOffset(420, 44), BackgroundColor3 = Color3.fromRGB(140, 40, 180), Visible = false, Parent = gui })
	fit(feastLabel)

	-- Bottom left: menu
	buildMenu()

	-- Bottom center: seed hotbar
	seedBar = Kit.New("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(560, 86), BackgroundTransparency = 1, Parent = gui }, {
		Kit.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	fit(seedBar)

	-- Bottom right: attack button and context actions above it
	attackButton = Kit.Button({ Text = "", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24), Size = UDim2.fromOffset(112, 112), BackgroundColor3 = C.Bad, Visible = false, Parent = gui }, function()
		CombatController.Attack(nil)
	end)
	attackButton:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	Kit.Label({ Text = Kit.Icons.Attack, TextSize = 40, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 46), Parent = attackButton })
	Kit.Label({ Text = if isTouch() then "ATTACK" else "ATTACK (F)", TextSize = 17, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 22), Parent = attackButton })
	fit(attackButton)
	buildActions()

	toastHolder = Kit.New("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -120), Size = UDim2.new(0.6, 0, 0, 190), BackgroundTransparency = 1, Parent = gui }, {
		Kit.New("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	bannerFrame = Kit.Card({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.36, 0), Size = UDim2.new(0.8, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.Panel, Visible = false, ZIndex = 10, Parent = gui }, {
		Kit.Padding(16, 20),
		Kit.New("UISizeConstraint", { MaxSize = Vector2.new(600, 260) }),
	})
	local bannerStroke = bannerFrame:FindFirstChildOfClass("UIStroke") :: UIStroke
	bannerStroke.Thickness = 4
	bannerScale = Kit.New("UIScale", { Parent = bannerFrame })
	vlist(bannerFrame, 6, Enum.HorizontalAlignment.Center)
	bannerTitle = Kit.Label({ Text = "", TextSize = 34, TextColor3 = C.Coins, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 38), ZIndex = 11, LayoutOrder = 1, Parent = bannerFrame })
	bannerText = Kit.Label({ Text = "", TextSize = 20, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 22), ZIndex = 11, LayoutOrder = 2, Parent = bannerFrame })

	updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

-- Data-driven updates --------------------------------------------------------------------------------

local function selectSeed(id: string)
	selectedSeed = id
	Remotes.Get("SelectSeed"):FireServer(id)
	seedKey = ""
	HUDController.RebuildSeeds()
end

-- Hotbar slot: colored seed ball, name, count, key number
function HUDController.RebuildSeeds()
	for _, child in seedBar:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	ownedSeeds = {}
	for _, crop in Crops.List do
		local count = data.Inventory.Seeds[crop.Id]
		if count and count > 0 then
			table.insert(ownedSeeds, crop)
		end
	end
	if selectedSeed == nil or (data.Inventory.Seeds[selectedSeed] or 0) <= 0 then
		selectedSeed = if ownedSeeds[1] then ownedSeeds[1].Id else nil
	end
	for index, crop in ownedSeeds do
		local isSelected = crop.Id == selectedSeed
		local slot = Kit.Button({ Text = "", Size = UDim2.fromOffset(78, 78), LayoutOrder = index, BackgroundColor3 = if isSelected then C.Good else C.Hud, Parent = seedBar }, function()
			selectSeed(crop.Id)
		end)
		slot.BackgroundTransparency = if isSelected then 0 else 0.15
		local ball = Kit.New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = crop.Color, Parent = slot }, { Kit.Corner(16), Kit.Stroke(C.Stroke, 2.5), Kit.Gradient(0.6) })
		ball.ZIndex = 2
		Kit.Label({ Text = crop.Name, TextSize = 15, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -5), Size = UDim2.new(1, 0, 0, 18), Parent = slot })
		Kit.Label({ Text = `x{data.Inventory.Seeds[crop.Id]}`, TextSize = 14, TextColor3 = C.Coins, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0, 0, 0, 3), Size = UDim2.new(1, -6, 0, 16), Parent = slot })
		if not isTouch() and index <= #KEYS then
			Kit.Label({ Text = tostring(index), TextSize = 14, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 6, 0, 3), Size = UDim2.new(0, 20, 0, 16), Parent = slot })
		end
		if isSelected then
			local stroke = slot:FindFirstChildOfClass("UIStroke")
			for _, child in slot:GetChildren() do
				if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
					stroke = child
				end
			end
			if stroke then
				stroke.Color = C.Coins
				stroke.Thickness = 4
			end
		end
	end
end

local function seasonClaimable(): number
	local season = Config.Season
	local tier = math.min(data.Season.XP // season.XPPerTier, season.Tiers)
	local premium = data.Purchases.PassesOwned.pass_season == true
	local count = 0
	for t = 1, tier do
		if not data.Season.Claimed[`{t}:f`] then
			count += 1
		end
		if premium and not data.Season.Claimed[`{t}:p`] then
			count += 1
		end
	end
	return count
end

local function setBadge(name: string, count: number)
	local badge = menuBadges[name]
	if badge then
		badge.Visible = count > 0
		badge.Text = if count > 9 then "9+" else tostring(count)
	end
end

local function onData(newData: any)
	data = newData
	coinsLabel.Text = Util.FormatNumber(data.Coins)
	essencePill.Visible = data.Unlocks.Essence == true
	essenceLabel.Text = Util.FormatNumber(data.Essence)
	local need = GameMath.XPToNext(data.GardenLevel)
	levelLabel.Text = tostring(data.GardenLevel)
	xpLabel.Text = `{Util.FormatNumber(data.GardenXP)}/{Util.FormatNumber(need)}`
	Kit.SetBar(xpFill, data.GardenXP / need)

	local objective = Objectives.List[data.ObjectiveIndex]
	if objective then
		local done = math.min(data.ObjectiveProgress, objective.Count)
		objectiveLabel.Text = `{Kit.Icons.Goal} {objective.Text}` .. (if objective.Count > 1 then `  {done}/{objective.Count}` else "")
		objectiveBar.Visible = objective.Count > 1
		Kit.SetBar(objectiveFill, done / objective.Count)
	else
		objectiveLabel.Text = `{Kit.Icons.Goal} {Objectives.DoneText}`
		objectiveBar.Visible = false
	end

	menuButtons.Friends.Visible = data.Unlocks.FriendVisit == true
	menuButtons.Ranks.Visible = data.Unlocks.Leaderboards == true
	setBadge("Season", seasonClaimable())
	setBadge("Store", panels("StorePanel").Badge(data))
	setBadge("Quests", panels("QuestsPanel").Claimable(data) + panels("PuzzlePanel").Remaining(data))

	local parts = {}
	for _, crop in Crops.List do
		table.insert(parts, tostring(data.Inventory.Seeds[crop.Id] or 0))
	end
	local key = table.concat(parts, ",")
	if key ~= seedKey then
		seedKey = key
		HUDController.RebuildSeeds()
	end
end

local function hint(now: number): string
	if not data then
		return ""
	end
	local ready, overripe, planted, soonest, soonestName = 0, 0, 0, math.huge, nil
	for _, record in data.Crops do
		planted += 1
		local left = GameMath.CropSecondsLeft(record, data.Plot.SoilLevel, now)
		local crop = Crops.ById[record.Type]
		if record.Overripe then
			overripe += 1
		end
		if left <= 0 then
			ready += 1
		elseif left < soonest and crop then
			soonest, soonestName = left, crop.Name
		end
	end
	local seeds = 0
	for _, count in data.Inventory.Seeds do
		seeds += count
	end
	local size = Config.PlotSizes[data.Plot.SizeIndex] or Config.PlotSizes[1]
	local hasGoods = next(data.Inventory.Goods) ~= nil
	local bagFull = GameMath.GoodsCount(data) >= GameMath.InventoryCapacity(data)
	local use = if isTouch() then "tap" else "press E"

	if bagFull then
		return "Bag full! Sell at the merchant cart."
	elseif overripe > 0 then
		return `{overripe} crop(s) overripe (half price). Walk up and {use} to harvest them now!`
	elseif ready > 0 then
		return `{ready} crop(s) ready! Walk up and {use} to harvest before they get overripe.`
	elseif seeds > 0 and planted < size.Width * size.Depth then
		return `Stand on brown soil and {use} to plant.`
	elseif hasGoods and seeds == 0 then
		return "Sell your harvest at the merchant cart, then buy seeds."
	elseif soonestName then
		return `{soonestName} ready in {math.ceil(soonest)}s. Pet your creature while you wait!`
	elseif hasGoods then
		return "Sell your harvest at the merchant cart."
	end
	return "Buy seeds at the merchant cart."
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function tick()
	local now = Workspace:GetServerTimeNow()
	local phase = player:GetAttribute("Phase")
	local endsAt = player:GetAttribute("PhaseEndsAt")
	local left = if type(endsAt) == "number" then endsAt - now else 0
	if phase == "Night" then
		timerLabel.Text = `{Kit.Icons.Night} Night Â· dawn in {formatTime(left)}`
		timerLabel.BackgroundColor3 = Color3.fromRGB(60, 50, 160)
	elseif phase == "Warning" then
		timerLabel.Text = `{Kit.Icons.Warning} Monsters coming! {formatTime(left)}`
		timerLabel.BackgroundColor3 = C.Bad
	elseif phase == "Day" then
		timerLabel.Text = `{Kit.Icons.Day} Night in {formatTime(left + Config.Night.WarningSeconds)}`
		timerLabel.BackgroundColor3 = Color3.fromRGB(255, 160, 40)
	else
		timerLabel.Text = "Loading your garden..."
		timerLabel.BackgroundColor3 = C.Panel
	end
	local danger = phase == "Night" or phase == "Warning"
	attackButton.Visible = danger or feast.Phase == "Active"
	threatLabel.Visible = danger
	threatLabel.Text = `{Kit.Icons.Monster} Monsters: {player:GetAttribute("MonstersAlive") or 0}`
	hintLabel.Text = hint(now)

	if data then
		-- Hunger Meter: live from stage 6, greyed teaser from stage 3
		if data.Unlocks.Hunger then
			hungerFrame.Visible = true
			hungerLabel.Text = if hunger.Active then `{Kit.Icons.Hunger} Hunger {math.floor(hunger.Value)} Â· {hunger.Level}` else `{Kit.Icons.Hunger} Hunger: needs 3 players`
			Kit.SetBar(hungerFill, hunger.Value / Config.Hunger.Max)
		elseif data.Stage >= 3 then
			hungerFrame.Visible = not danger
			hungerLabel.Text = `{Kit.Icons.Lock} Hunger Meter Â· Level 17`
			Kit.SetBar(hungerFill, 0)
		else
			hungerFrame.Visible = false
		end

		local lure = (data.Inventory.Goods.lureberry or 0) + (data.Inventory.Goods["lureberry#Moonlit"] or 0)
		actionButtons.Lure.Visible = data.Unlocks.LureBerry == true and lure > 0
		actionButtons.Lure.Text = `Lure Berry ({lure})`
		actionButtons.Flag.Visible = data.Unlocks.Heist == true and phase == "Day"
		actionButtons.Flag.Text = if data.HeistFlag then "Lower Flag" else "Raise Heist Flag"
		actionButtons.LockPen.Visible = data.HeistFlag == true
		local lockedUntil = player:GetAttribute("PenLockedUntil")
		actionButtons.LockPen.Text = if type(lockedUntil) == "number" and lockedUntil > now then `Locked {math.ceil(lockedUntil - now)}s` else "Lock Pen"
		local stolenUntil = player:GetAttribute("StolenUntil")
		actionButtons.StealBack.Visible = type(stolenUntil) == "number" and stolenUntil > now
		actionButtons.Supply.Visible = feast.Phase ~= "None" and data.Unlocks.Feast == true
		actionButtons.Veteran.Visible = not data.VeteranSkipUsed and data.NightsSurvived == 0 and data.GardenLevel <= 2 and data.Stage == 1
	end
	actionButtons.Alert.Visible = alertOwner ~= nil and alertOwner.Until > now
	if alertOwner then
		actionButtons.Alert.Text = `Help {alertOwner.Name}`
	end
	-- Keep the action stack above the Attack button while it shows
	actionColumn.Position = if attackButton.Visible then UDim2.new(1, -16, 1, -150) else UDim2.new(1, -16, 1, -24)

	if feast.Phase == "Warning" then
		feastLabel.Visible = true
		feastLabel.Text = `FEAST NIGHT in {formatTime((feast.EndsAt or now) - now)}`
	elseif feast.Phase == "Active" then
		feastLabel.Visible = true
		local where = if feast.Garden then ` at {feast.Garden}'s garden` else ""
		feastLabel.Text = `ALPHA {math.floor(feast.Health or 0)}/{math.floor(feast.MaxHealth or 0)}{where}`
	else
		feastLabel.Visible = false
	end
end

function HUDController.Start()
	buildLayout()
	DataController.Changed:Connect(onData)
	if DataController.Get() then
		onData(DataController.Get())
	end

	-- Keys 1-9 pick a seed from the hotbar
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local index = table.find(KEYS, input.KeyCode)
		if index and ownedSeeds[index] then
			selectSeed(ownedSeeds[index].Id)
		end
	end)

	Remotes.Get("Notify").OnClientEvent:Connect(function(payload)
		HUDController.Toast(payload.Text, if payload.Kind == "Goal" then C.Coins else nil)
	end)
	Remotes.Get("UnlockBanner").OnClientEvent:Connect(function(payload)
		HUDController.ShowBanner(payload.Title, payload.Text)
	end)
	Remotes.Get("NightWarning").OnClientEvent:Connect(function(payload)
		local direction = if payload and payload.Direction then `Your scout spotted them coming from the {payload.Direction}!` else "Stay near your garden. Tap monsters or press Attack to fight!"
		HUDController.ShowBanner(`{Kit.Icons.Warning} Monsters approaching!`, direction)
	end)
	Remotes.Get("MutationEarned").OnClientEvent:Connect(function(payload)
		if payload.Special then
			-- first Moonlit glow: the big "wow" moment after the first night
			task.delay(1.2, function()
				if payload.Rarity == "Mythic" then
					-- super-rare glow (Celestial 1 in 5,000, Eclipse 1 in 50,000)
					HUDController.Celebrate(`🌟 INCREDIBLE! 🌟`, `{payload.Creature} is now {string.upper(payload.Mutation)}!`, `{payload.Reason}. Almost nobody has this. The whole server just heard about it!`)
				else
					HUDController.Celebrate(`✨ LUCKY! ✨`, `{payload.Creature} is now {string.upper(payload.Mutation)}!`, `A {payload.Rarity} glow from the moon. Glowing creatures and crops are worth more. Defend every night to find rarer glows!`)
				end
			end)
		else
			HUDController.ShowBanner(`{payload.Creature} earned {payload.Mutation}!`, `{payload.Rarity} mutation - {payload.Reason}`)
		end
	end)
	Remotes.Get("CrateOpened").OnClientEvent:Connect(function(payload)
		HUDController.ShowBanner(`Crate: {payload.Name}!`, if payload.Duplicate then "Duplicate - you got a Recolor token instead." else `{payload.Rarity} cosmetic. Equip it in Style.`)
	end)
	Remotes.Get("HungerUpdate").OnClientEvent:Connect(function(payload)
		hunger = payload
	end)
	Remotes.Get("FeastUpdate").OnClientEvent:Connect(function(payload)
		feast = payload
	end)
	Remotes.Get("NeighborAlert").OnClientEvent:Connect(function(payload)
		alertOwner = { UserId = payload.OwnerUserId, Name = payload.Name, Until = Workspace:GetServerTimeNow() + 20 }
		HUDController.Toast(`Big attack at {payload.Name}'s garden! Tap "Help neighbor".`, C.Coins)
	end)

	task.spawn(function()
		while true do
			tick()
			task.wait(0.2)
		end
	end)
end

return HUDController
