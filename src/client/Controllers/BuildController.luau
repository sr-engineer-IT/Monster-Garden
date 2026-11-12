--!strict
-- Build mode (Garden panel -> "Place", "Place soil" or "Build mode"): shows the build grid on your
-- own garden. Three tools:
--   Place:  tap a green square to put the chosen item there (a soil tile or a decoration)
--   Move:   tap a decoration or soil tile, then tap a green square to move it there
--           (soil tiles take their growing crop with them)
--   Remove: tap a decoration (back to storage) or an empty soil tile (back to your tile count)
-- Green squares are free, yellow ones have a decoration. Gates, paths and building spots stay
-- clear (shared/GardenGrid). Display only: the server checks every request.

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

BuildController.Soil = "soil" -- item id for soil tiles (decorations use their Decor ids)

local FREE = Color3.fromRGB(110, 230, 120)
local TAKEN = Color3.fromRGB(255, 210, 70)
local PICKED = Color3.fromRGB(255, 140, 40)
local BAD = Color3.fromRGB(240, 80, 80)
local FACING = { "North", "East", "South", "West" }

local active = false
local mode = "place" -- "place" | "move" | "remove"
local selected: string? = nil -- item to place
local moveFrom: string? = nil -- square picked up by the Move tool
local turns = 0

local gui: ScreenGui
local titleLabel: TextLabel
local turnButton: TextButton
local moveButton: TextButton
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

local function layout(data: any): ({ [string]: boolean }, { [string]: any })
	local plotData = data and data.Plot or {}
	return plotData.Soil or {}, plotData.Garden or {}
end

local function itemName(data: any, cellId: string): string
	local soil, garden = layout(data)
	local entry = garden[cellId]
	if entry and Decor.ById[entry.D] then
		local decor = Decor.ById[entry.D]
		return `{decor.Icon} {decor.Name}`
	elseif soil[cellId] then
		return if data.Crops and data.Crops[cellId] then "🟫 Soil tile (with its crop)" else "🟫 Soil tile"
	end
	return "item"
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
	-- the turn button only matters for decorations
	local turning = mode == "place" and selected ~= nil and selected ~= BuildController.Soil
	if mode == "move" and moveFrom and data then
		local _, garden = layout(data)
		turning = garden[moveFrom] ~= nil
	end
	turnButton.Visible = turning
	if mode == "remove" then
		titleLabel.Text = "🗑 Remove: tap a decoration (back to storage) or an empty soil tile"
	elseif mode == "move" then
		titleLabel.Text = if moveFrom and data then `✋ Moving {itemName(data, moveFrom)}: tap a green square` else "✋ Move: tap a decoration or soil tile to pick it up"
	elseif selected == BuildController.Soil then
		local placed = if data then GardenGrid.CountSoil(data) else 0
		local allowance = if data then GardenGrid.SoilAllowance(data) else 0
		titleLabel.Text = `🟫 Soil tiles: {placed} / {allowance} placed. Tap a green square to add one`
	elseif selected and Decor.ById[selected] then
		local decor = Decor.ById[selected]
		local owned = data and data.Inventory and data.Inventory.Decor and data.Inventory.Decor[decor.Id] or 0
		local cost = if owned > 0 then `have {owned}` else `{Kit.Icons.Coins} {Util.FormatNumber(decor.Cost)}{if decor.Essence then ` + {Kit.Icons.Essence} {decor.Essence}` else ""}`
		titleLabel.Text = `{decor.Icon} {decor.Name} ({cost}): tap a green square`
	else
		titleLabel.Text = "Tap Pick or Soil to place something, or Move"
	end
	turnButton.Text = `↻ {FACING[turns + 1]}`
	moveButton.BackgroundColor3 = if mode == "move" then C.Premium else C.Panel
	removeButton.BackgroundColor3 = if mode == "remove" then C.Bad else C.Panel
end

local function setMode(newMode: string)
	mode = newMode
	moveFrom = nil
	updateBar()
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
	local soil, garden = layout(data)
	if moveFrom and not soil[moveFrom] and not garden[moveFrom] then
		moveFrom = nil -- it was moved or removed
	end
	local folder = Instance.new("Folder")
	folder.Name = "BuildGrid"
	local range = GardenGrid.Range
	for i = -range, range do
		for j = -range, range do
			local id = GardenGrid.CellId(i, j)
			local p = center + GardenGrid.Offset(i, j)
			if id == moveFrom then
				square(PICKED, 0.3, Vector3.new(p.X, top + (if soil[id] then 0.75 else 0.1), p.Z), GardenGrid.CellSize - 0.4, folder)
			elseif not soil[id] and (garden[id] ~= nil or not GardenGrid.IsBlocked(i, j)) then
				square(if garden[id] then TAKEN else FREE, 0.65, Vector3.new(p.X, top + 0.08, p.Z), GardenGrid.CellSize - 0.8, folder)
			end
		end
	end
	hover = square(Color3.new(1, 1, 1), 1, Vector3.new(center.X, top + 0.15, center.Z), GardenGrid.CellSize - 0.2, folder)
	folder.Parent = Workspace
	overlay = folder
end

-- The square under a screen point, and whether the current tool works there
type Target = { Id: string, Position: Vector3, Soil: boolean, Item: boolean, Ok: boolean }

local function targetAt(screen: Vector2): Target?
	local plot = myPlot()
	local camera = Workspace.CurrentCamera
	local data = DataController.Get()
	if not plot or not camera or not data then
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
	local i, j = GardenGrid.CellAt(point - center)
	if not i or not j then
		return nil
	end
	local id = GardenGrid.CellId(i, j)
	local soil, garden = layout(data)
	local hasSoil = soil[id] == true
	local isItem = hasSoil or garden[id] ~= nil
	local free = not isItem and not GardenGrid.IsBlocked(i, j)
	local ok
	if mode == "remove" then
		ok = garden[id] ~= nil or (hasSoil and not (data.Crops and data.Crops[id]))
	elseif mode == "move" then
		ok = if moveFrom then (free or isItem) else isItem -- tapping another item picks that one instead
	else
		ok = free and selected ~= nil
		if selected == BuildController.Soil then
			ok = ok and GardenGrid.CountSoil(data) < GardenGrid.SoilAllowance(data)
		end
	end
	local p = center + GardenGrid.Offset(i, j)
	return { Id = id, Position = Vector3.new(p.X, top, p.Z), Soil = hasSoil, Item = isItem, Ok = ok == true }
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
	hover.Position = Vector3.new(target.Position.X, target.Position.Y + (if target.Soil then 0.75 else 0.15), target.Position.Z)
	hover.Color = if target.Ok then Color3.new(1, 1, 1) else BAD
	hover.Transparency = 0.35
end

local function act(screen: Vector2)
	local target = targetAt(screen)
	local data = DataController.Get()
	if not target or not data then
		return
	end
	local _, garden = layout(data)
	if mode == "remove" then
		if garden[target.Id] then
			Remotes.Get("RemoveDecor"):FireServer(target.Id)
		elseif target.Soil then
			Remotes.Get("RemoveSoil"):FireServer(target.Id) -- the server explains if a crop grows there
		end
	elseif mode == "move" then
		if target.Item then
			-- pick it up (or pick a different one); decorations keep their facing until you turn them
			moveFrom = if moveFrom == target.Id then nil else target.Id
			local entry = moveFrom and garden[moveFrom]
			if entry then
				turns = (entry.R or 0) % 4
			end
			updateBar()
			buildOverlay()
		elseif moveFrom then
			Remotes.Get("MoveItem"):FireServer(moveFrom, target.Id, if garden[moveFrom] then turns else nil)
			moveFrom = nil
			updateBar()
		end
	elseif selected == BuildController.Soil then
		Remotes.Get("PlaceSoil"):FireServer(target.Id)
	elseif selected then
		Remotes.Get("PlaceDecorAt"):FireServer(selected, target.Id, turns)
	end
end

function BuildController.IsActive(): boolean
	return active
end

-- Enter build mode with an item to place (BuildController.Soil or a decoration id), or nil to
-- start with the Move tool
function BuildController.Begin(itemId: string?)
	if not myPlot() then
		return
	end
	selected = itemId
	mode = if itemId then "place" else "move"
	moveFrom = nil
	active = true
	gui.Enabled = true
	updateBar()
	buildOverlay()
end

function BuildController.Stop()
	active = false
	moveFrom = nil
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
		Kit.New("UISizeConstraint", { MaxSize = Vector2.new(620, 108) }),
	})
	titleLabel = Kit.Label({ Text = "", TextSize = 15, TextWrapped = true, Size = UDim2.new(1, 0, 0, 38), Parent = bar })
	local row = Kit.New("Frame", { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Parent = bar }, {
		Kit.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function button(text: string, color: Color3, order: number, onClick: () -> ()): TextButton
		return Kit.Button({ Text = text, TextSize = 14, TextWrapped = true, Size = UDim2.new(1 / 6, -5, 1, 0), BackgroundColor3 = color, LayoutOrder = order, Parent = row }, onClick)
	end
	button("🌻 Pick", C.Good, 1, function()
		require(script.Parent.Parent:WaitForChild("Panels"):WaitForChild("DecorPanel")).Open()
	end)
	button("🟫 Soil", Color3.fromRGB(150, 105, 65), 2, function()
		selected = BuildController.Soil
		setMode("place")
		buildOverlay()
	end)
	moveButton = button("✋ Move", C.Panel, 3, function()
		setMode(if mode == "move" then "place" else "move")
		buildOverlay()
	end)
	turnButton = button("↻ North", C.Panel, 4, function()
		turns = (turns + 1) % 4
		updateBar()
	end)
	removeButton = button("🗑 Remove", C.Panel, 5, function()
		setMode(if mode == "remove" then "place" else "remove")
		buildOverlay()
	end)
	button("✓ Done", C.Accent, 6, BuildController.Stop)

	-- A tap or click (not a camera drag) uses the current tool
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
