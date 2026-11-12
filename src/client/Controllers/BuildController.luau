--!strict
-- Build mode (Garden panel -> "Place", "Place soil" or "Build mode"): edit your own garden on the
-- build grid. Three tools:
--   Place:  put the chosen item (a soil tile or a decoration) on a green square
--   Move:   tap a decoration or soil tile, then a green square (soil takes its crop along)
--   Remove: a decoration goes back to storage, an empty soil tile back to your tile count
-- Comfortable on phones:
--   * Build camera: looks down on the whole garden. Drag to pan, pinch or mouse wheel to zoom,
--     WASD / arrow keys pan on PC. Walking is paused while building.
--   * Touch screens tap twice: the first tap marks a square, then "✓" (or the same square
--     again) does it, so a wrong tap never costs coins. A mouse click acts at once (the square
--     under the mouse is highlighted before clicking).
--   * The HUD's menu, seed bar and action buttons hide; the build bar sits at the bottom.
-- Green squares are free, yellow ones have a decoration. Gates, paths and building spots stay
-- clear (shared/GardenGrid). Display only: the server checks every request.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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

-- Build camera
local PITCH = math.rad(58) -- how steeply the camera looks down
local ZOOM_MIN, ZOOM_MAX, ZOOM_START = 35, 150, 95 -- camera distance from the point it looks at
local PAN_LIMIT = 62 -- how far from the garden center the camera may look

local active = false
local mode = "place" -- "place" | "move" | "remove"
local selected: string? = nil -- item to place
local moveFrom: string? = nil -- square picked up by the Move tool
local pending: string? = nil -- touch screens: square marked by the first tap, waiting for ✓
local turns = 0

local gui: ScreenGui
local titleLabel: TextLabel
local turnButton: TextButton
local moveButton: TextButton
local removeButton: TextButton
local confirmButton: TextButton
local overlay: Folder? = nil
local hover: Part? = nil
local marker: Part? = nil

local camFocus = Vector3.zero
local camYaw = 0
local camZoom = ZOOM_START
local savedCameraType: Enum.CameraType? = nil

local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function toast(text: string)
	local ok, hud = pcall(require, script.Parent:WaitForChild("HUDController"))
	if ok and hud.Toast then
		hud.Toast(text)
	end
end

local function setHudHidden(on: boolean)
	local ok, hud = pcall(require, script.Parent:WaitForChild("HUDController"))
	if ok and hud.SetBuildMode then
		hud.SetBuildMode(on)
	end
end

-- Walking pauses while building (on phones this also hides the joystick and jump button)
local function setWalking(on: boolean)
	pcall(function()
		local module = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: any)
		local controls = module:GetControls()
		if on then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

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

-- Camera ---------------------------------------------------------------------------------------------

local function clampFocus(plotCenter: Vector3, focus: Vector3): Vector3
	local offset = focus - plotCenter
	return Vector3.new(plotCenter.X + math.clamp(offset.X, -PAN_LIMIT, PAN_LIMIT), focus.Y, plotCenter.Z + math.clamp(offset.Z, -PAN_LIMIT, PAN_LIMIT))
end

local function flatVectors(): (Vector3, Vector3)
	local forward = Vector3.new(math.sin(camYaw), 0, math.cos(camYaw))
	local right = Vector3.new(-forward.Z, 0, forward.X) -- forward x up, same as the camera's RightVector
	return forward, right
end

local function updateCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local forward = flatVectors()
	local position = camFocus - forward * (camZoom * math.cos(PITCH)) + Vector3.new(0, camZoom * math.sin(PITCH), 0)
	camera.CFrame = CFrame.lookAt(position, camFocus)
end

local function startCamera(center: Vector3, top: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	savedCameraType = camera.CameraType
	-- keep the direction the player was already looking, so the garden does not flip around
	local look = camera.CFrame.LookVector
	camYaw = if Vector3.new(look.X, 0, look.Z).Magnitude > 0.1 then math.atan2(look.X, look.Z) else math.pi
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local start = if root and root:IsA("BasePart") then root.Position else center
	camFocus = clampFocus(center, Vector3.new(start.X, top, start.Z))
	camZoom = ZOOM_START
	camera.CameraType = Enum.CameraType.Scriptable
	updateCamera()
end

local function stopCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = savedCameraType or Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function pan(screenDelta: Vector2)
	local camera = Workspace.CurrentCamera
	local plot = myPlot()
	if not camera or not plot then
		return
	end
	local center = plotFrame(plot)
	if not center then
		return
	end
	-- world studs per screen pixel at the point the camera looks at
	local perPixel = 2 * camZoom * math.tan(math.rad(camera.FieldOfView) / 2) / math.max(camera.ViewportSize.Y, 1)
	local forward, right = flatVectors()
	camFocus = clampFocus(center, camFocus - right * screenDelta.X * perPixel + forward * screenDelta.Y * perPixel / math.sin(PITCH))
	updateCamera()
end

local function zoom(factor: number)
	camZoom = math.clamp(camZoom * factor, ZOOM_MIN, ZOOM_MAX)
	updateCamera()
end

-- Bar --------------------------------------------------------------------------------------------------

-- What tapping the square would do (text for the ✓ button), or nil if nothing
local function actionText(data: any, cellId: string): string?
	if mode == "remove" then
		return `🗑 Remove {itemName(data, cellId)}`
	elseif mode == "move" then
		return if moveFrom then `✓ Move here` else nil
	elseif selected == BuildController.Soil then
		return "✓ Place soil here"
	elseif selected and Decor.ById[selected] then
		local decor = Decor.ById[selected]
		local owned = data.Inventory and data.Inventory.Decor and data.Inventory.Decor[decor.Id] or 0
		return if owned > 0 then `✓ Place {decor.Name} here` else `✓ Buy {decor.Name} here ({Kit.Icons.Coins} {Util.FormatNumber(decor.Cost)})`
	end
	return nil
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
	local tap = if isTouch() then "tap" else "click"
	if mode == "remove" then
		titleLabel.Text = `🗑 Remove: {tap} a decoration or an empty soil tile`
	elseif mode == "move" then
		titleLabel.Text = if moveFrom and data then `✋ Moving {itemName(data, moveFrom)}: {tap} a green square` else `✋ Move: {tap} a decoration or soil tile`
	elseif selected == BuildController.Soil then
		local placed = if data then GardenGrid.CountSoil(data) else 0
		local allowance = if data then GardenGrid.SoilAllowance(data) else 0
		titleLabel.Text = `🟫 Soil tiles: {placed} / {allowance} placed. {tap} a green square`
	elseif selected and Decor.ById[selected] then
		local decor = Decor.ById[selected]
		local owned = data and data.Inventory and data.Inventory.Decor and data.Inventory.Decor[decor.Id] or 0
		local cost = if owned > 0 then `have {owned}` else `{Kit.Icons.Coins} {Util.FormatNumber(decor.Cost)}{if decor.Essence then ` + {Kit.Icons.Essence} {decor.Essence}` else ""}`
		titleLabel.Text = `{decor.Icon} {decor.Name} ({cost}): {tap} a green square`
	else
		titleLabel.Text = "Pick something to place, or Move"
	end
	if not isTouch() then
		titleLabel.Text ..= "  •  drag to look around, wheel to zoom"
	end
	turnButton.Text = `↻ {FACING[turns + 1]}`
	moveButton.BackgroundColor3 = if mode == "move" then C.Premium else C.Panel
	removeButton.BackgroundColor3 = if mode == "remove" then C.Bad else C.Panel
	local text = if pending and data then actionText(data, pending) else nil
	confirmButton.Visible = text ~= nil
	confirmButton.Text = text or ""
	confirmButton.BackgroundColor3 = if mode == "remove" then C.Bad else C.Good
end

local function setMode(newMode: string)
	mode = newMode
	moveFrom = nil
	pending = nil
	updateBar()
end

-- Grid overlay -----------------------------------------------------------------------------------------

local function placeMarker(cellId: string?)
	if not marker then
		return
	end
	local plot = myPlot()
	local data = DataController.Get()
	local i, j = GardenGrid.Parse(cellId)
	if not cellId or not plot or not data or not i or not j then
		marker.Transparency = 1
		return
	end
	local center, top = plotFrame(plot)
	if not center then
		return
	end
	local soil = layout(data)
	local p = center + GardenGrid.Offset(i, j)
	marker.Position = Vector3.new(p.X, top + (if soil[cellId] then 0.8 else 0.2), p.Z)
	marker.Color = if mode == "remove" then BAD else Color3.new(1, 1, 1)
	marker.Transparency = 0.15
end

local function buildOverlay()
	if overlay then
		overlay:Destroy()
		overlay = nil
	end
	hover, marker = nil, nil
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
				square(if garden[id] then TAKEN else FREE, 0.6, Vector3.new(p.X, top + 0.08, p.Z), GardenGrid.CellSize - 0.8, folder)
			end
		end
	end
	hover = square(Color3.new(1, 1, 1), 1, Vector3.new(center.X, top + 0.15, center.Z), GardenGrid.CellSize - 0.2, folder)
	-- the touch-screen "marked" square: a thick frame-like plate above everything
	marker = square(Color3.new(1, 1, 1), 1, Vector3.new(center.X, top + 0.2, center.Z), GardenGrid.CellSize + 0.4, folder)
	folder.Parent = Workspace
	overlay = folder
	placeMarker(pending)
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

-- Actions ----------------------------------------------------------------------------------------------

-- Sends the request for a square (after the touch confirm, or at once with a mouse)
local function run(cellId: string)
	local data = DataController.Get()
	if not data then
		return
	end
	local soil, garden = layout(data)
	if mode == "remove" then
		if garden[cellId] then
			Remotes.Get("RemoveDecor"):FireServer(cellId)
		elseif soil[cellId] then
			Remotes.Get("RemoveSoil"):FireServer(cellId) -- the server explains if a crop grows there
		end
	elseif mode == "move" then
		if moveFrom then
			Remotes.Get("MoveItem"):FireServer(moveFrom, cellId, if garden[moveFrom] then turns else nil)
			moveFrom = nil
		end
	elseif selected == BuildController.Soil then
		Remotes.Get("PlaceSoil"):FireServer(cellId)
	elseif selected then
		Remotes.Get("PlaceDecorAt"):FireServer(selected, cellId, turns)
	end
	pending = nil
	placeMarker(nil)
	updateBar()
end

local function act(screen: Vector2)
	local target = targetAt(screen)
	local data = DataController.Get()
	if not target or not data then
		return
	end
	local _, garden = layout(data)
	-- Move tool, first step: pick an item up (free and harmless, so no confirm needed)
	if mode == "move" and target.Item then
		moveFrom = if moveFrom == target.Id then nil else target.Id
		local entry = moveFrom and garden[moveFrom]
		if entry then
			turns = (entry.R or 0) % 4
		end
		pending = nil
		updateBar()
		buildOverlay()
		return
	end
	if not target.Ok then
		pending = nil
		placeMarker(nil)
		updateBar()
		-- say why, so a tap that does nothing never feels broken
		local soil = layout(data)
		if mode == "remove" then
			if soil[target.Id] then
				toast("A crop is growing there. Harvest it first, or use ✋ Move to take it along.")
			end
		elseif mode == "place" and selected == BuildController.Soil and not target.Item and GardenGrid.CountSoil(data) >= GardenGrid.SoilAllowance(data) then
			toast(`All {GardenGrid.SoilAllowance(data)} soil tiles are placed. Remove one, or buy more farm land at the merchant cart.`)
		elseif mode == "place" and selected then
			toast(if target.Item then "Something is already there." else "You can't build there (gates, paths and buildings stay clear).")
		end
		return
	end
	if not isTouch() or pending == target.Id then
		run(target.Id) -- mouse click, or the same square tapped again
		return
	end
	-- touch screens: mark the square first, then ✓ (or tap it again) does it
	pending = target.Id
	placeMarker(pending)
	updateBar()
end

function BuildController.IsActive(): boolean
	return active
end

-- Enter build mode with an item to place (BuildController.Soil or a decoration id), or nil to
-- start with the Move tool
function BuildController.Begin(itemId: string?)
	local plot = myPlot()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not plot then
		return
	end
	local center, top = plotFrame(plot)
	if not center or not root or not root:IsA("BasePart") then
		return
	end
	local offset = root.Position - center
	if math.abs(offset.X) > 72 or math.abs(offset.Z) > 72 then
		toast("Go to your own garden to build.")
		return
	end
	selected = itemId
	mode = if itemId then "place" else "move"
	moveFrom, pending = nil, nil
	if not active then
		active = true
		gui.Enabled = true
		setHudHidden(true)
		setWalking(false)
		startCamera(center, top)
	end
	updateBar()
	buildOverlay()
end

function BuildController.Stop()
	if not active then
		return
	end
	active = false
	moveFrom, pending = nil, nil
	gui.Enabled = false
	if overlay then
		overlay:Destroy()
		overlay = nil
	end
	hover, marker = nil, nil
	stopCamera()
	setWalking(true)
	setHudHidden(false)
end

function BuildController.Start()
	local touch = isTouch()
	gui = Kit.New("ScreenGui", { Name = "BuildMode", ResetOnSpawn = false, Enabled = false, DisplayOrder = 4, Parent = player:WaitForChild("PlayerGui") })
	local barHeight = if touch then 132 else 112
	local bar = Kit.New("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -24, 0, barHeight), BackgroundColor3 = C.Hud, BackgroundTransparency = 0.08, Parent = gui }, {
		Kit.Corner(14),
		Kit.Padding(8),
		Kit.New("UISizeConstraint", { MaxSize = Vector2.new(720, barHeight) }),
	})
	titleLabel = Kit.Label({ Text = "", TextSize = if touch then 18 else 16, TextWrapped = true, Size = UDim2.new(1, 0, 0, 40), Parent = bar })
	local row = Kit.New("Frame", { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -46), BackgroundTransparency = 1, Parent = bar }, {
		Kit.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function button(text: string, color: Color3, order: number, onClick: () -> ()): TextButton
		return Kit.Button({ Text = text, TextSize = if touch then 17 else 15, TextWrapped = true, Size = UDim2.new(1 / 6, -6, 1, 0), BackgroundColor3 = color, LayoutOrder = order, Parent = row }, onClick)
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
	-- touch screens: big confirm button above the bar for the marked square
	confirmButton = Kit.Button({ Text = "", TextSize = 20, TextWrapped = true, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -(barHeight + 20)), Size = UDim2.new(0, 360, 0, 56), BackgroundColor3 = C.Good, Visible = false, Parent = gui }, function()
		if pending then
			run(pending)
		end
	end)

	-- Input: a short tap or click uses the tool; a drag pans the camera; pinch / wheel zoom
	local presses: { [InputObject]: { Start: Vector2, Last: Vector2, Time: number, Dragged: boolean } } = {}
	local touches = 0
	local pinchedAt = 0
	UserInputService.InputBegan:Connect(function(input, processed)
		if not active or processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local at = Vector2.new(input.Position.X, input.Position.Y)
			presses[input] = { Start = at, Last = at, Time = os.clock(), Dragged = false }
			if input.UserInputType == Enum.UserInputType.Touch then
				touches += 1
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not active then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			zoom(if input.Position.Z > 0 then 0.88 else 1 / 0.88)
			return
		end
		local at = Vector2.new(input.Position.X, input.Position.Y)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			showHover(at)
			-- left-drag pans on PC
			for press, state in presses do
				if press.UserInputType == Enum.UserInputType.MouseButton1 then
					if (at - state.Start).Magnitude > 12 then
						state.Dragged = true
					end
					if state.Dragged then
						pan(at - state.Last)
					end
					state.Last = at
				end
			end
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local state = presses[input]
			if state and touches == 1 then
				if (at - state.Start).Magnitude > 12 then
					state.Dragged = true
				end
				if state.Dragged then
					pan(at - state.Last)
				end
			end
			if state then
				state.Last = at
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local state = presses[input]
		presses[input] = nil
		if input.UserInputType == Enum.UserInputType.Touch and state then
			touches = math.max(0, touches - 1)
		end
		if not active or not state then
			return
		end
		local at = Vector2.new(input.Position.X, input.Position.Y)
		if not state.Dragged and os.clock() - state.Time < 0.45 and os.clock() - pinchedAt > 0.3 and (at - state.Start).Magnitude < 12 then
			act(at)
		end
	end)
	local pinchStart = camZoom
	UserInputService.TouchPinch:Connect(function(_, scale, _, state, processed)
		if not active or processed then
			return
		end
		pinchedAt = os.clock()
		if state == Enum.UserInputState.Begin then
			pinchStart = camZoom
		elseif scale > 0 then
			camZoom = math.clamp(pinchStart / scale, ZOOM_MIN, ZOOM_MAX)
			updateCamera()
		end
	end)
	-- WASD / arrow keys pan on PC
	RunService.RenderStepped:Connect(function(dt)
		if not active then
			return
		end
		local x, y = 0, 0
		if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
			y += 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
			y -= 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
			x += 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
			x -= 1
		end
		if x ~= 0 or y ~= 0 then
			local camera = Workspace.CurrentCamera
			local perPixel = if camera then 2 * camZoom * math.tan(math.rad(camera.FieldOfView) / 2) / math.max(camera.ViewportSize.Y, 1) else 0.1
			local speed = camZoom * 0.9 * dt / math.max(perPixel, 0.01)
			pan(Vector2.new(-x * speed, y * speed * math.sin(PITCH)))
		else
			updateCamera() -- keep the camera where it is (some scripts move it back)
		end
	end)

	-- Leave build mode cleanly if the character respawns
	player.CharacterAdded:Connect(function()
		BuildController.Stop()
	end)

	local refreshPending = false
	DataController.Changed:Connect(function()
		if not active or refreshPending then
			return
		end
		refreshPending = true
		task.delay(0.2, function()
			refreshPending = false
			if active then
				updateBar()
				buildOverlay()
			end
		end)
	end)
end

return BuildController
