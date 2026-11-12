--!strict
-- Decor panel (menu button "Decor"): buy and place garden decorations.
-- Place opens build mode (Controllers/BuildController): tap a green grass square, or a soil tile
-- to turn it into garden (no crops grow there). The server checks everything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Decor = require(ConfigFolder:WaitForChild("Decor"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("UI"):WaitForChild("Kit"))
local DataController = require(Client:WaitForChild("Controllers"):WaitForChild("DataController"))
local PanelController = require(Client:WaitForChild("Controllers"):WaitForChild("PanelController"))

local C = Kit.Colors

local DecorPanel = {}

local function totalTiles(data: any): number
	local size = Config.PlotSizes[data.Plot.SizeIndex] or Config.PlotSizes[1]
	local total = size.Width * size.Depth
	if data.Purchases and data.Purchases.PassesOwned and data.Purchases.PassesOwned.pass_plot then
		total += Config.World.ExtraPlotColumns * Config.World.ExtraPlotRows
	end
	return total
end

local function costText(decor: Decor.Decor): string
	local text = `{Kit.Icons.Coins} {Util.FormatNumber(decor.Cost)}`
	if decor.Essence then
		text ..= ` + {Kit.Icons.Essence} {decor.Essence}`
	end
	return text
end

-- Close the panel and enter build mode (Controllers/BuildController)
local function beginBuild(decorId: string?)
	PanelController.Close()
	require(Client:WaitForChild("Controllers"):WaitForChild("BuildController")).Begin(decorId)
end

function DecorPanel.Open()
	local data = DataController.Get()
	if not data then
		return
	end
	local list = PanelController.Open("Decor", `{Kit.Icons.Decor} Decorate`)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local placedMap = (data.Plot and data.Plot.Decor) or {}
	local stored = (data.Inventory and data.Inventory.Decor) or {}
	local placed = 0
	for _ in placedMap do
		placed += 1
	end
	local total = totalTiles(data)

	local info = Kit.Row(list, nextOrder(), 96)
	Kit.Label({
		Text = "Tap Place, then tap any green square on the grass (grass decorations keep all your farm land).\nTap a soil tile instead to turn it into garden: no crops grow there.\nUse Remove in build mode to put things back in storage.",
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 23,
		Parent = info,
	})
	local gardenCount = 0
	for _ in (data.Plot and data.Plot.Garden) or {} do
		gardenCount += 1
	end
	Kit.Button({ Text = "🔨 Build mode (move / remove)", TextSize = 17, Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = C.Good, LayoutOrder = nextOrder(), ZIndex = 22, Parent = list }, function()
		beginBuild(nil)
	end)
	Kit.Label({ Text = `On grass: {gardenCount}/{Decor.MaxGardenPieces}   •   Farm tiles: {total - placed} of {total}`, TextSize = 15, TextColor3 = C.Coins, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = nextOrder(), ZIndex = 22, Parent = list })

	-- Owned (in storage) first, then everything for sale
	local storedAny = false
	for _, decor in Decor.List do
		if (stored[decor.Id] or 0) > 0 then
			if not storedAny then
				storedAny = true
				Kit.Heading(list, "In storage", nextOrder())
			end
			local row = Kit.Row(list, nextOrder(), 64)
			Kit.Label({ Text = `{decor.Icon} {decor.Name}  x{stored[decor.Id]}`, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -120, 0, 24), ZIndex = 23, Parent = row })
			Kit.Label({ Text = "Free to place (you own it)", TextSize = 13, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, -120, 0, 18), ZIndex = 23, Parent = row })
			Kit.RowButton(row, 1, "Place", C.Good, function()
				beginBuild(decor.Id)
			end, 104)
		end
	end

	Kit.Heading(list, "Shop", nextOrder())
	for _, decor in Decor.List do
		local locked = data.GardenLevel < decor.MinLevel
		local row = Kit.Row(list, nextOrder(), 64)
		Kit.Label({ Text = `{decor.Icon} {decor.Name}`, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -150, 0, 24), ZIndex = 23, Parent = row })
		Kit.Label({ Text = `{decor.Info}   {costText(decor)}`, TextSize = 13, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, -150, 0, 18), ZIndex = 23, Parent = row })
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
