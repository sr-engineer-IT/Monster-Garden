--!strict
-- Decor panel (menu button "Decor"): lay out your farm and garden. Soil tiles and decorations sit
-- on the build grid, so the farm can be any shape, anywhere. Every button opens build mode
-- (Controllers/BuildController); the server checks everything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Decor = require(ConfigFolder:WaitForChild("Decor"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenGrid = require(Shared:WaitForChild("GardenGrid"))
local Util = require(Shared:WaitForChild("Util"))

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("UI"):WaitForChild("Kit"))
local DataController = require(Client:WaitForChild("Controllers"):WaitForChild("DataController"))
local PanelController = require(Client:WaitForChild("Controllers"):WaitForChild("PanelController"))

local C = Kit.Colors

local DecorPanel = {}

local function costText(decor: Decor.Decor): string
	local text = `{Kit.Icons.Coins} {Util.FormatNumber(decor.Cost)}`
	if decor.Essence then
		text ..= ` + {Kit.Icons.Essence} {decor.Essence}`
	end
	return text
end

-- Close the panel and enter build mode (Controllers/BuildController)
local function beginBuild(itemId: string?)
	PanelController.Close()
	require(Client:WaitForChild("Controllers"):WaitForChild("BuildController")).Begin(itemId)
end

function DecorPanel.Open()
	local data = DataController.Get()
	if not data then
		return
	end
	local list = PanelController.Open("Decor", `{Kit.Icons.Decor} Farm & Garden`)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local stored = (data.Inventory and data.Inventory.Decor) or {}
	-- how many of each decoration stand in the garden right now
	local placedCount: { [string]: number } = {}
	for _, entry in (data.Plot and data.Plot.Garden) or {} do
		if type(entry) == "table" and entry.D then
			placedCount[entry.D] = (placedCount[entry.D] or 0) + 1
		end
	end
	-- Name + "2 in storage · 3 placed" on the first line, a short note on the second
	local function itemLabels(row: Instance, decor: Decor.Decor, note: string, buttonWidth: number)
		local have, placed = stored[decor.Id] or 0, placedCount[decor.Id] or 0
		Kit.Label({ Text = `{decor.Icon} {decor.Name}`, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -buttonWidth, 0, 24), ZIndex = 23, Parent = row })
		if have > 0 or placed > 0 then
			Kit.Label({ Text = `📦 {have} in storage  ·  ✅ {placed} placed`, TextSize = 14, TextColor3 = C.Coins, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, -buttonWidth - 10, 0, 24), ZIndex = 23, Parent = row })
		end
		Kit.Label({ Text = note, TextSize = 14, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, -buttonWidth, 0, 18), ZIndex = 23, Parent = row })
	end

	local info = Kit.Row(list, nextOrder(), 96)
	Kit.Label({
		Text = "Build your own farm: put soil tiles anywhere on the grass, in any shape.\nThen decorate the free squares. Use ✋ Move in build mode to move anything (crops move with their soil).\nBuy more farm land at the merchant cart.",
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 23,
		Parent = info,
	})
	local placed, allowance = GardenGrid.CountSoil(data), GardenGrid.SoilAllowance(data)
	local soilRow = Kit.Row(list, nextOrder(), 64)
	Kit.Label({ Text = `🟫 Soil tiles: {placed} / {allowance} placed`, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -150, 0, 24), ZIndex = 23, Parent = soilRow })
	Kit.Label({ Text = if placed < allowance then `{allowance - placed} left to place` else "Remove one to move it", TextSize = 14, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, -150, 0, 18), ZIndex = 23, Parent = soilRow })
	Kit.RowButton(soilRow, 1, "Place soil", Color3.fromRGB(150, 105, 65), function()
		beginBuild("soil")
	end, 134)
	local gardenCount = 0
	for _ in (data.Plot and data.Plot.Garden) or {} do
		gardenCount += 1
	end
	Kit.Button({ Text = "🔨 Build mode (move / remove)", TextSize = 17, Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = C.Good, LayoutOrder = nextOrder(), ZIndex = 22, Parent = list }, function()
		beginBuild(nil)
	end)
	Kit.Label({ Text = `Decorations placed: {gardenCount}/{Decor.MaxGardenPieces}`, TextSize = 15, TextColor3 = C.Coins, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = nextOrder(), ZIndex = 22, Parent = list })

	-- Owned (in storage) first, then everything for sale
	local storedAny = false
	for _, decor in Decor.List do
		if (stored[decor.Id] or 0) > 0 then
			if not storedAny then
				storedAny = true
				Kit.Heading(list, "In storage", nextOrder())
			end
			local row = Kit.Row(list, nextOrder(), 64)
			itemLabels(row, decor, "Free to place (you own it)", 120)
			Kit.RowButton(row, 1, "Place", C.Good, function()
				beginBuild(decor.Id)
			end, 104)
		end
	end

	Kit.Heading(list, "Shop", nextOrder())
	for _, decor in Decor.List do
		local locked = data.GardenLevel < decor.MinLevel
		local row = Kit.Row(list, nextOrder(), 64)
		itemLabels(row, decor, `{decor.Info}   {costText(decor)}`, 150)
		if locked then
			row.BackgroundColor3 = C.Locked
			Kit.RowButton(row, 1, `{Kit.Icons.Lock} Lv {decor.MinLevel}`, C.Locked, function() end, 134)
		else
			Kit.RowButton(row, 1, "Buy & place", C.Accent, function()
				beginBuild(decor.Id)
			end, 134)
		end
	end
end

function DecorPanel.Start()
	-- trailing refresh: always shows the newest snapshot, at most a few times a second
	local pending = false
	DataController.Changed:Connect(function()
		if pending then
			return
		end
		pending = true
		task.delay(0.25, function()
			pending = false
			PanelController.Refresh("Decor", DecorPanel.Open)
		end)
	end)
end

return DecorPanel
