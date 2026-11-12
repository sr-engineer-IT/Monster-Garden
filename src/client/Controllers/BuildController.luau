--!strict
-- Build mode (Decor panel -> "Place" or "Build mode"): shows the grass build grid on your own
-- garden and lets you tap or click a square to place the chosen decoration, or tap a soil tile to
-- turn it into garden. Remove mode sends decorations back to storage.
-- Green squares are free, yellow ones have a decoration. Gates, paths, the farm and building
-- spots stay clear (shared/GardenGrid). Display only: the server checks every request.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Decor = require(ConfigFolder:WaitForChild("Decor"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenGrid = require(Shared:WaitForChild("GardenGrid"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))
local DataController = require(script.Parent:WaitForChild("DataController"))

local player = Players.LocalPlayer
local C = Kit.Colors

local BuildController = {}

local FREE = Color3.fromRGB(110, 230, 120)
local TAKEN = Color3.fromRGB(255, 210, 70)
local BAD = Color3.fromRGB(240, 80, 80)
local FACING = { "North", "East", "South", "West" }

local active = false
local selected: string? = nil
local turns = 0
local removing = false

local gui: ScreenGui
local titleLabel: TextLabel
local turnButton: TextButton
local removeButton: TextButton
local overlay: Folder? = nil
local hover: Part? = nil

local function myPlot(): Instance?
	local plots = Workspace:FindFirstChild("Plots")
	for _, plot in plots and plots:GetChildren() or {} do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

-- Plot center and the grass top height (the Ground part is 0.2 thick, centered 0.1 above the center)
local function plotFrame(plot: Instance): (Vector3?, number)
	local ground = plot:FindFirstChild("Ground")
	if ground and ground:IsA("BasePart") then
		return ground.Position - Vector3.new(0, 0.1, 0), ground.Position.Y + ground.Size.Y / 2
	end
	return nil, 0
end

local function soilTiles(plot: Instance): { BasePart }
	local list = {}
	local tiles = plot:FindFirstChild("Tiles")
	for _, tile in tiles and tiles:GetChildren() or {} do
		if tile:IsA("BasePart") and tile:GetAttribute("TileId") ~= nil then
			table.insert(list, tile)
		end
	end
	return list
end

local function square(color: Color3, transparency: number, position: Vector3, size: number, parent: Instance): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Transparency = transparency
	part.Size = Vector3.new(size, 0.12, size)
	part.Position = position
	part.Parent = parent
	return part
end

local function updateBar()
	if not active then
		return
	end
	local data = DataController.Get()
	local decor = selected and Decor.ById[selected]
	if removing then
		titleLabel.Text = "🗑 Remove: tap a decoration to put it back in storage"
	elseif decor then
		local owned = data and data.Inventory and data.Inventory.Decor and data.Inventory.Decor[decor.Id] or 0
		local cost = if owned > 0 then `have {owned}` else `{Kit.Icons.Coins} {Util.FormatNumber(decor.Cost)}{if decor.Essence then ` + {Kit.Icons.Essence} {decor.Essence}` else ""}`
		titleLabel.Text = `{decor.Icon} {decor.Name} ({cost}): tap a green square or a soil tile`
	else
		titleLabel.Text = "Tap Pick to choose a decoration"
	end
	turnButton.Text = `↻ {FACING[turns + 1]}`
	removeButton.BackgroundColor3 = if removing then C.Bad else C.Panel
	removeButton.Text = if removing then "🗑 Removing" else "🗑 Remove"
end

local function buildOverlay()
	if overlay then
		overlay:Destroy()
		overlay = nil
	end
	hover = nil
	local plot = myPlot()
	local data = DataController.Get()
	if not active or not plot or not data then
		return
	end
	local center, top = plotFrame(plot)
	if not center then
		return
	end
	local offsets = {}
	for _, tile in soilTiles(plot) do
		table.insert(offsets, tile.Position - center)
	end
	local garden = (data.Plot and data.Plot.Garden) or {}
	local folder = Instance.new("Folder")
	folder.Name = "BuildGrid"
	local range = GardenGrid.Range
	for i = -range, range do
		for j = -range, range do
			local taken = garden[GardenGrid.CellId(i, j)] ~= nil
			if taken or not GardenGrid.IsBlocked(i, j, offsets) then
				local p = center + GardenGrid.Offset(i, j)
				square(if taken then TAKEN else FREE, 0.65, Vector3.new(p.X, top + 0.08, p.Z), GardenGrid.CellSize - 0.8, folder)
			end
		end
	end
	local marker = square(Color3.new(1, 1, 1), 1, Vector3.new(center.X, top + 0.15, center.Z), GardenGrid.CellSize - 0.2, folder)
	hover = marker
	folder.Parent = Workspace
	overlay = folder
end

-- What is under a screen point: a soil tile, or a grass square
type Target = { Kind: string, Id: string, Position: Vector3, Size: number, Ok: boolean }

local function targetAt(screen: Vector2): Target?
	local plot = myPlot()
	local camera = Workspace.CurrentCamera
	if not plot or not camera then
		return nil
	end
	local center, top = plotFrame(plot)
	if not center then
		return nil
	end
	local ray = camera:ScreenPointToRay(screen.X, screen.Y)
	if ray.Direction.Y > -0.01 then
		return nil
	end
	local point = ray.Origin + ray.Direction * ((top - ray.Origin.Y) / ray.Direction.Y)
	local data = DataController.Get()
	local offsets = {}
	for _, tile in soilTiles(plot) do
		local d = tile.Position - point
		if math.abs(d.X) <= tile.Size.X / 2 and math.abs(d.Z) <= tile.Size.Z / 2 then
			local tileId = tile:GetAttribute("TileId") :: string
			local decorated = data and data.Plot and data.Plot.Decor and data.Plot.Decor[tileId] ~= nil
			local planted = data and data.Crops and data.Crops[tileId] ~= nil
			local ok = if removing then decorated else (not decorated and not planted)
			return { Kind = "Tile", Id = tileId, Position = tile.Position, Size = tile.Size.X, Ok = ok == true }
		end
		table.insert(offsets, tile.Position - center)
	end
	local i, j = GardenGrid.CellAt(point - center)
	if not i or not j then
		return nil
	end
	local cellId = GardenGrid.CellId(i, j)
	local taken = data and data.Plot and data.Plot.Garden and data.Plot.Garden[cellId] ~= nil
	local ok = if removing then taken else (not taken and not GardenGrid.IsBlocked(i, j, offsets))
	local p = center + GardenGrid.Offset(i, j)
	return { Kind = "Cell", Id = cellId, Position = Vector3.new(p.X, top, p.Z), Size = GardenGrid.CellSize, Ok = ok == true }
end

local function showHover(screen: Vector2)
	if not hover then
		return
	end
	local target = targetAt(screen)
	if not target then
		hover.Transparency = 1
		return
	end
	local y = if target.Kind == "Tile" then target.Position.Y + 0.3 else target.Position.Y + 0.15
	hover.Size = Vector3.new(target.Size - 0.2, 0.12, target.Size - 0.2)
	hover.Position = Vector3.new(target.Position.X, y, target.Position.Z)
	hover.Color = if target.Ok then Color3.new(1, 1, 1) else BAD
	hover.Transparency = 0.35
end

local function act(screen: Vector2)
	local target = targetAt(screen)
	if not target then
		return
	end
	if removing then
		if target.Ok then
			Remotes.Get("RemoveDecor"):FireServer(target.Id)
		end
	elseif selected then
		if target.Kind == "Tile" then
			Remotes.Get("PlaceDecor"):FireServer(selected, target.Id)
		else
			Remotes.Get("PlaceDecorAt"):FireServer(selected, target.Id, turns)
		end
	end
end

function BuildController.IsActive(): boolean
	return active
end

-- Enter build mode with a decoration chosen (or nil to only remove / pick later)
function BuildController.Begin(decorId: string?)
	if not myPlot() then
		return
	end
	selected = decorId
	removing = decorId == nil
	active = true
	gui.Enabled = true
	updateBar()
	buildOverlay()
end

function BuildController.Stop()
	active = false
	gui.Enabled = false
	if overlay then
		overlay:Destroy()
		overlay = nil
	end
	hover = nil
end

function BuildController.Start()
	gui = Kit.New("ScreenGui", { Name = "BuildMode", ResetOnSpawn = false, Enabled = false, DisplayOrder = 4, Parent = player:WaitForChild("PlayerGui") })
	local bar = Kit.New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 72), Size = UDim2.new(1, -24, 0, 108), BackgroundColor3 = C.Hud, BackgroundTransparency = 0.1, Parent = gui }, {
		Kit.Corner(14),
		Kit.Padding(8),
		Kit.New("UISizeConstraint", { MaxSize = Vector2.new(540, 108) }),
	})
	titleLabel = Kit.Label({ Text = "", TextSize = 15, TextWrapped = true, Size = UDim2.new(1, 0, 0, 38), Parent = bar })
	local row = Kit.New("Frame", { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Parent = bar }, {
		Kit.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function button(text: string, color: Color3, order: number, onClick: () -> ()): TextButton
		return Kit.Button({ Text = text, TextSize = 15, Size = UDim2.new(0.25, -6, 1, 0), BackgroundColor3 = color, LayoutOrder = order, Parent = row }, onClick)
	end
	button("🪴 Pick", C.Good, 1, function()
		require(script.Parent.Parent:WaitForChild("Panels"):WaitForChild("DecorPanel")).Open()
	end)
	turnButton = button("↻ North", C.Panel, 2, function()
		turns = (turns + 1) % 4
		updateBar()
	end)
	removeButton = button("🗑 Remove", C.Panel, 3, function()
		removing = not removing
		updateBar()
	end)
	button("✓ Done", C.Accent, 4, BuildController.Stop)

	-- A tap or click (not a camera drag) places or removes
	local pressStart: { [InputObject]: { Position: Vector2, Time: number } } = {}
	UserInputService.InputBegan:Connect(function(input, processed)
		if not active or processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressStart[input] = { Position = Vector2.new(input.Position.X, input.Position.Y), Time = os.clock() }
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local start = pressStart[input]
		pressStart[input] = nil
		if not active or not start then
			return
		end
		local now = Vector2.new(input.Position.X, input.Position.Y)
		if (now - start.Position).Magnitude < 12 and os.clock() - start.Time < 0.4 then
			act(now)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if active and input.UserInputType == Enum.UserInputType.MouseMovement then
			showHover(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)

	local pending = false
	DataController.Changed:Connect(function()
		if not active or pending then
			return
		end
		pending = true
		task.delay(0.2, function()
			pending = false
			if active then
				updateBar()
				buildOverlay()
			end
		end)
	end)
end

return BuildController
