--!strict
-- PlotService: builds the shared world, gives each player a private plot and builds its farm tiles
-- (Build Spec sections 1-3). Each plot has its own merchant cart so mobile players never walk far
-- (assumption: the spec's single NPC merchant is replaced by one cart per garden, same shared rules).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Products = require(ConfigFolder:WaitForChild("Products"))
local Util = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"))

local S = require(script.Parent.Parent.Registry)
local Build = require(script.Parent.Parent.Build)
local Assets = require(script.Parent.Parent.Assets)
local Props = require(script.Parent.Parent.Props)

export type Plot = {
	Index: number,
	Owner: Player?,
	Model: Model,
	Center: Vector3,
	Folders: { [string]: Folder },
	TileParts: { [string]: BasePart },
	SignLabel: TextLabel,
	GroveLabel: TextLabel?,
}

local WORLD = Config.World
local TILE = Config.TileSizeStuds
local HALF = WORLD.PlotHalfSize

local GRASS = Color3.fromRGB(110, 175, 85)
local FENCE = Color3.fromRGB(236, 226, 205) -- white picket; garden themes tint it
local SOIL = Color3.fromRGB(120, 85, 55)
local WOOD = Color3.fromRGB(150, 105, 65)
local PATH = Color3.fromRGB(176, 160, 132)
local ROAD = Color3.fromRGB(150, 118, 82)

local PlotService = {}

local plots: { Plot } = {}
local playerPlots: { [Player]: Plot } = {}
local plotsFolder: Folder

local function plotCenter(index: number): Vector3
	local c = WORLD.PlotCenters[index]
	return Vector3.new(c.X, WORLD.GroundY, c.Z)
end

-- Direction from the garden away from town (the side its homestead is on)
local function outward(center: Vector3): Vector3
	if math.abs(center.Z) >= math.abs(center.X) then
		return Vector3.new(0, 0, math.sign(center.Z))
	end
	return Vector3.new(math.sign(center.X), 0, 0)
end

-- Wooden picket fence on all four sides with a gap at each gate
local function buildFences(model: Model, center: Vector3)
	local gap = WORLD.GateWidth / 2
	local h = WORLD.HedgeHeight
	local g = WORLD.GroundY
	for _, side in { -1, 1 } do
		for _, along in { -1, 1 } do
			-- north/south sides
			Props.Fence(center + Vector3.new(along * gap, g, side * HALF), center + Vector3.new(along * HALF, g, side * HALF), h, FENCE, model)
			-- east/west sides
			Props.Fence(center + Vector3.new(side * HALF, g, along * gap), center + Vector3.new(side * HALF, g, along * HALF), h, FENCE, model)
		end
	end
	-- gate posts
	for _, dir in { Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0) } do
		local right = Vector3.new(-dir.Z, 0, dir.X)
		for _, s in { -1, 1 } do
			local p = center + dir * HALF + right * s * (gap + 0.6)
			Build.Part({ Name = "Hedge", Size = Vector3.new(1.2, h + 2, 1.2), Position = p + Vector3.new(0, (h + 2) / 2, 0), Color = FENCE, Material = Enum.Material.WoodPlanks, CanCollide = true, Parent = model })
			Build.Ball({ Size = Vector3.one * 1.5, Position = p + Vector3.new(0, h + 2.6, 0), Color = FENCE, Parent = model })
		end
	end
end

local function buildMerchant(plot: Plot)
	local base = plot.Center + WORLD.MerchantOffset
	local cart = Instance.new("Model")
	cart.Name = "MerchantCart"
	cart.Parent = plot.Model
	local facing = CFrame.lookAt(base, Vector3.new(plot.Center.X, base.Y, plot.Center.Z))
	local body = Build.Part({ Name = "Cart", Size = Vector3.new(7, 3, 4), Position = base + Vector3.new(0, 2, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, CanCollide = true, Parent = cart })
	if Assets.Place("MerchantCart", facing, cart, { Width = 9, Collide = true }) then
		body.Transparency = 1
	else
		Build.Part({ Size = Vector3.new(8, 0.4, 5), Position = base + Vector3.new(0, 6.5, 0), Color = Color3.fromRGB(240, 90, 90), Parent = cart })
		for _, x in { -3.5, 3.5 } do
			Build.Part({ Size = Vector3.new(0.4, 3, 0.4), Position = base + Vector3.new(x, 5, 1.8), Color = WOOD, Parent = cart })
		end
		for _, x in { -2.5, 2.5 } do
			Build.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 2.4, 2.4), CFrame = CFrame.new(base + Vector3.new(x, 1.2, -2.2)) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(70, 50, 30), Parent = cart })
		end
		-- produce on the cart
		for i, color in { Color3.fromRGB(255, 140, 40), Color3.fromRGB(220, 60, 120), Color3.fromRGB(120, 200, 80) } do
			Build.Ball({ Size = Vector3.one * 1.3, Position = base + Vector3.new(-3 + i * 1.6, 4.1, 0), Color = color, Parent = cart })
		end
	end
	-- seed sacks and a produce crate beside the cart
	for i, info in { { 5.6, 0.2, Color3.fromRGB(255, 140, 40) }, { 6.4, 1.9, Color3.fromRGB(220, 60, 120) }, { 7.2, 0.4, Color3.fromRGB(240, 210, 60) } } do
		local at = facing * CFrame.new(info[1], 0, info[2])
		Build.Part({ Size = Vector3.new(1.4, 1.8, 1.2), CFrame = at * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, math.rad(i * 25), 0), Color = Color3.fromRGB(214, 190, 140), Material = Enum.Material.Fabric, CanCollide = true, Parent = cart })
		Build.Part({ Size = Vector3.new(0.9, 0.35, 0.8), CFrame = at * CFrame.new(0, 1.95, 0), Color = Color3.fromRGB(190, 165, 115), Material = Enum.Material.Fabric, Parent = cart })
		Build.Part({ Size = Vector3.new(0.6, 0.6, 0.6), CFrame = at * CFrame.new(0, 2.2, 0), Color = info[3], Parent = cart })
	end
	local crateAt = facing * CFrame.new(-5.8, 0, 0.6)
	Build.Part({ Size = Vector3.new(2.2, 1.2, 1.6), CFrame = crateAt * CFrame.new(0, 0.6, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, CanCollide = true, Parent = cart })
	for j, color in { Color3.fromRGB(255, 140, 40), Color3.fromRGB(230, 60, 60), Color3.fromRGB(120, 200, 80), Color3.fromRGB(255, 200, 60) } do
		Build.Part({ Size = Vector3.new(0.6, 0.6, 0.6), CFrame = crateAt * CFrame.new(-0.75 + (j - 1) * 0.5, 1.4, (j % 2) * 0.4 - 0.2), Color = color, Parent = cart })
	end

	local gui = Build.Billboard(body, 160, 40, 6)
	gui.Size = UDim2.fromScale(8, 2)
	Build.Label(gui, "Merchant", { TextColor3 = Color3.fromRGB(255, 230, 120), Font = Enum.Font.FredokaOne })

	local prompt = Build.Prompt(body, "Shop", "Merchant Cart", { Distance = 12 })
	prompt.Triggered:Connect(function(player)
		if player == plot.Owner then
			S.EconomyService.OpenMerchant(player)
		end
	end)
end

-- Upgrade Station: a workbench where the owner buys permanent upgrades (UpgradeService)
local function buildUpgradeStation(plot: Plot)
	local base = plot.Center + WORLD.UpgradeStationOffset
	local station = Instance.new("Model")
	station.Name = "UpgradeStation"
	station.Parent = plot.Model
	local facing = CFrame.lookAt(base, Vector3.new(plot.Center.X, base.Y, plot.Center.Z))
	local bench = Build.Part({ Name = "Bench", Size = Vector3.new(8, 3, 3.4), CFrame = facing * CFrame.new(0, 1.5, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, CanCollide = true, Parent = station })
	-- table top, tool rack and a few tools
	Build.Part({ Size = Vector3.new(8.6, 0.4, 3.8), CFrame = facing * CFrame.new(0, 3.2, 0), Color = Color3.fromRGB(110, 78, 50), Material = Enum.Material.Wood, Parent = station })
	Build.Part({ Size = Vector3.new(8, 4, 0.4), CFrame = facing * CFrame.new(0, 5.4, 1.6), Color = Color3.fromRGB(120, 86, 56), Material = Enum.Material.WoodPlanks, Parent = station })
	for i, color in { Color3.fromRGB(170, 170, 180), Color3.fromRGB(200, 80, 60), Color3.fromRGB(80, 160, 90) } do
		local x = -3 + i * 1.6
		Build.Part({ Size = Vector3.new(0.25, 2.4, 0.25), CFrame = facing * CFrame.new(x, 5.2, 1.3), Color = Color3.fromRGB(90, 62, 40), Parent = station })
		Build.Part({ Size = Vector3.new(0.9, 0.5, 0.2), CFrame = facing * CFrame.new(x, 6.5, 1.3), Color = color, Material = Enum.Material.Metal, Parent = station })
	end
	Build.Part({ Size = Vector3.new(1.4, 1, 1), CFrame = facing * CFrame.new(-2.6, 3.9, -0.4), Color = Color3.fromRGB(220, 60, 60), Material = Enum.Material.Metal, Parent = station }) -- toolbox
	Build.Ball({ Size = Vector3.one * 1, CFrame = facing * CFrame.new(2.4, 3.9, -0.4), Color = Color3.fromRGB(120, 230, 120), Material = Enum.Material.Neon, Parent = station }) -- glowing seed

	local gui = Build.Billboard(bench, 160, 40, 7)
	gui.Size = UDim2.fromScale(9, 2)
	Build.Label(gui, "🔧 Upgrades", { TextColor3 = Color3.fromRGB(150, 230, 255), Font = Enum.Font.FredokaOne })

	local prompt = Build.Prompt(bench, "Upgrades", "Upgrade Station", { Distance = 12 })
	prompt.Triggered:Connect(function(player)
		if player == plot.Owner then
			S.UpgradeService.Open(player)
		end
	end)
end

-- Locked Spirit Grove gate teaser (section 22.3)
local function buildSpiritGate(plot: Plot)
	local base = plot.Center + WORLD.SpiritGateOffset
	local gate = Instance.new("Model")
	gate.Name = "SpiritGroveGate"
	gate.Parent = plot.Model
	local arch: BasePart
	local art = Assets.Place("SpiritGate", CFrame.lookAt(base, Vector3.new(plot.Center.X, base.Y, plot.Center.Z)), gate, { Height = 10, Collide = true })
	if art then
		arch = Build.Part({ Size = Vector3.new(1, 1, 1), Position = base + Vector3.new(0, 8.5, 0), Transparency = 1, Parent = gate })
	else
		for _, x in { -3, 3 } do
			Build.Part({ Size = Vector3.new(1.5, 8, 1.5), Position = base + Vector3.new(x, 4, 0), Color = Color3.fromRGB(200, 200, 220), Material = Enum.Material.Marble, CanCollide = true, Parent = gate })
		end
		arch = Build.Part({ Size = Vector3.new(8, 1, 1.5), Position = base + Vector3.new(0, 8.5, 0), Color = Color3.fromRGB(160, 200, 255), Material = Enum.Material.Neon, Parent = gate })
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(160, 200, 255)
	light.Range = 14
	light.Parent = arch
	local gui = Build.Billboard(arch, 200, 50, 3)
	gui.Size = UDim2.fromScale(10, 2.6)
	plot.GroveLabel = Build.Label(gui, "Spirit Grove\nUnlocks at Level 25", { TextColor3 = Color3.fromRGB(200, 220, 255) })
end

-- Paths, flower beds, the homestead (cottage, shed, well, mailbox, scarecrow) and trees
local function buildDecor(model: Model, center: Vector3, index: number)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model
	local g = WORLD.GroundY
	local inner = 44 -- farm edge at its biggest is 40
	local outLength = (WORLD.PlotSpacing - HALF * 2) / 2 - 8
	local width = WORLD.GateWidth - 6
	for _, dir in { Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0) } do
		local alongX = dir.X ~= 0
		local inside = HALF - inner
		local insideMid = center + dir * (inner + inside / 2)
		Build.Part({ Name = "Path", Size = if alongX then Vector3.new(inside, 0.1, width) else Vector3.new(width, 0.1, inside), Position = insideMid + Vector3.new(0, 0.25, 0), Color = PATH, Material = Enum.Material.Cobblestone, Parent = decor })
		local outsideMid = center + dir * (HALF + outLength / 2)
		Build.Part({ Name = "Path", Size = if alongX then Vector3.new(outLength, 0.1, width) else Vector3.new(width, 0.1, outLength), Position = outsideMid + Vector3.new(0, 0.05, 0), Color = PATH, Material = Enum.Material.Cobblestone, Parent = decor })
	end

	local rng = Random.new(index * 97)
	-- flower beds inside along the fence
	for _, spot in { Vector3.new(-24, 0, -65), Vector3.new(24, 0, -65), Vector3.new(-26, 0, 65), Vector3.new(28, 0, 65) } do
		Props.FlowerBed(CFrame.new(center + spot + Vector3.new(0, g + 0.2, 0)), 16, decor, rng)
	end

	-- small grass tufts, flowers and pebbles in the open grass, away from paths, the farm and every
	-- building spot (keeps room to build and to run around at night)
	local reserved = { WORLD.MerchantOffset, WORLD.UpgradeStationOffset, WORLD.StallOffset, WORLD.PenOffset, WORLD.TowerSpot, WORLD.ShelterSpot, WORLD.SpiritGateOffset, WORLD.CreatureHome, WORLD.SpawnOffset }
	for _, list in { WORLD.LanternPosts, WORLD.TrapSpots, WORLD.NestSpots } do
		for _, p in list do
			table.insert(reserved, p)
		end
	end
	local placed, tries = 0, 0
	while placed < 26 and tries < 400 do
		tries += 1
		local x, z = rng:NextNumber(-HALF + 4, HALF - 4), rng:NextNumber(-HALF + 4, HALF - 4)
		local ok = math.max(math.abs(x), math.abs(z)) > inner + 2 and math.abs(x) > 9 and math.abs(z) > 9
		if ok and z < -inner + 0 and z > -64 and math.abs(x) < 36 then
			ok = false -- Extra Plot area (north)
		end
		if ok and math.abs(z) > 61 and math.abs(x) > 14 and math.abs(x) < 38 then
			ok = false -- flower beds
		end
		for _, r in reserved do
			if ok and (Vector3.new(x, 0, z) - Vector3.new(r.X, 0, r.Z)).Magnitude < 9 then
				ok = false
			end
		end
		if ok then
			placed += 1
			local at = center + Vector3.new(x, g + 0.2, z)
			local roll = rng:NextNumber()
			if roll < 0.45 then
				for i = 1, 3 do -- grass tuft
					Build.Part({ Size = Vector3.new(0.25, rng:NextNumber(0.8, 1.4), 0.25), CFrame = CFrame.new(at + Vector3.new((i - 2) * 0.35, 0.5, rng:NextNumber(-0.2, 0.2))) * CFrame.Angles(0, 0, math.rad((i - 2) * 18)), Color = Color3.fromRGB(80, rng:NextInteger(150, 175), 60), Parent = decor })
				end
			elseif roll < 0.8 then
				local color = ({ Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 220, 90), Color3.fromRGB(170, 130, 255), Color3.fromRGB(255, 255, 255) })[rng:NextInteger(1, 4)]
				for i = 1, 3 do -- little flower clump
					local p = at + Vector3.new(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8))
					Build.Part({ Size = Vector3.new(0.15, 0.7, 0.15), Position = p + Vector3.new(0, 0.35, 0), Color = Color3.fromRGB(70, 150, 60), Parent = decor })
					Build.Part({ Size = Vector3.new(0.45, 0.3, 0.45), Position = p + Vector3.new(0, 0.8, 0), Color = color, Parent = decor })
				end
			else
				for i = 1, 2 do -- pebbles
					Build.Part({ Size = Vector3.new(rng:NextNumber(0.6, 1.1), 0.4, rng:NextNumber(0.5, 0.9)), CFrame = CFrame.new(at + Vector3.new(i * 0.7, 0.1, rng:NextNumber(-0.4, 0.4))) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = Color3.fromRGB(140, 140, 145), Material = Enum.Material.Slate, Parent = decor })
				end
			end
		end
	end

	-- homestead outside the fence, on the side away from town, facing the garden
	local out = outward(center)
	local right = Vector3.new(-out.Z, 0, out.X)
	local function spot(o: number, r: number): CFrame
		local p = center + out * o + right * r + Vector3.new(0, g, 0)
		return CFrame.lookAt(p, p - out)
	end
	Props.Cottage(spot(HALF + 17, -34), decor)
	Props.Shed(spot(HALF + 15, 32), decor)
	Props.Well(spot(HALF + 11, -16), decor)
	Props.Mailbox(spot(HALF + 4, 9), decor)
	Props.Bush(spot(HALF + 6, -48), decor, rng)
	Props.Bush(spot(HALF + 6, 46), decor, rng)
	-- scarecrow outside the fence between the gate and the shed
	Props.Scarecrow(spot(HALF + 7, 20), decor)

	-- trees at the outer corners and along the fence outside
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			Props.Tree(CFrame.new(center + Vector3.new(cx * (HALF + 13), g, cz * (HALF + 13))), decor, rng)
		end
	end
	for _, dir in { Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0) } do
		if dir ~= out then
			local side = Vector3.new(-dir.Z, 0, dir.X)
			for _, r in { -42, 42 } do
				if rng:NextNumber() < 0.7 then
					Props.Tree(CFrame.new(center + dir * (HALF + 12) + side * (r + rng:NextNumber(-6, 6)) + Vector3.new(0, g, 0)), decor, rng)
				else
					Props.Bush(CFrame.new(center + dir * (HALF + 7) + side * r + Vector3.new(0, g, 0)), decor, rng)
				end
			end
		end
	end
end

-- Dirt roads between the gardens and around the town (4 x 4 grid lines)
local function buildRoads()
	local roads = Instance.new("Folder")
	roads.Name = "Roads"
	roads.Parent = Workspace
	local n = WORLD.GridSize
	local span = n * WORLD.PlotSpacing + 16
	for i = 0, n do
		local c = (i - n / 2) * WORLD.PlotSpacing
		Build.Part({ Name = "Road", Size = Vector3.new(16, 0.1, span), Position = Vector3.new(c, WORLD.GroundY + 0.06, 0), Color = ROAD, Material = Enum.Material.Ground, Parent = roads })
		Build.Part({ Name = "Road", Size = Vector3.new(span, 0.16, 16), Position = Vector3.new(0, WORLD.GroundY + 0.08, c), Color = ROAD, Material = Enum.Material.Ground, Parent = roads })
	end
end

local function buildPlot(index: number): Plot
	local center = plotCenter(index)
	local model = Instance.new("Model")
	model.Name = `Plot{index}`
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)

	Build.Part({ Name = "Ground", Size = Vector3.new(HALF * 2, 0.2, HALF * 2), Position = center + Vector3.new(0, 0.1, 0), Color = GRASS, Material = Enum.Material.Grass, CanCollide = true, Parent = model })
	buildFences(model, center)
	buildDecor(model, center, index)

	-- name sign beside the gate that faces town
	local toTown = -outward(center)
	local signAt = center + toTown * (HALF + 3) + Vector3.new(-toTown.Z, 0, toTown.X) * 14
	Build.Part({ Name = "Sign", Size = Vector3.new(1, 6, 1), Position = signAt + Vector3.new(0, 3, 0), Color = WOOD, CanCollide = true, Parent = model })
	local boardAt = signAt + Vector3.new(0, 5.2, 0)
	local board = Build.Part({ Size = Vector3.new(6, 2.6, 0.4), CFrame = CFrame.lookAt(boardAt, boardAt + toTown), Color = Color3.fromRGB(190, 145, 95), Material = Enum.Material.WoodPlanks, Parent = model })
	local signGui = Build.Billboard(board, 260, 50, 3)
	signGui.Size = UDim2.fromScale(16, 3)
	signGui.MaxDistance = 250
	local signLabel = Build.Label(signGui, "Free garden", { Font = Enum.Font.FredokaOne })

	local folders = {}
	for _, name in { "Tiles", "Buildings", "Creatures", "Monsters", "Petals", "Garden" } do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = model
		folders[name] = folder
	end

	local plot: Plot = {
		Index = index,
		Owner = nil,
		Model = model,
		Center = center,
		Folders = folders,
		TileParts = {},
		SignLabel = signLabel,
	}
	buildMerchant(plot)
	buildUpgradeStation(plot)
	buildSpiritGate(plot)
	model.Parent = plotsFolder
	return plot
end

local function teleportToPlot(player: Player, character: Model)
	local plot = playerPlots[player]
	if not plot then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	task.wait(0.1) -- let Roblox finish its own spawn placement first
	if root and character.Parent then
		local spawnAt = plot.Center + WORLD.SpawnOffset + Vector3.new(0, 4, 0)
		character:PivotTo(CFrame.lookAt(spawnAt, plot.Center + Vector3.new(0, 4, 0)))
	end
end

local function assign(player: Player)
	if playerPlots[player] then
		return
	end
	for _, plot in plots do
		if plot.Owner == nil then
			plot.Owner = player
			playerPlots[player] = plot
			plot.Model:SetAttribute("OwnerUserId", player.UserId)
			plot.SignLabel.Text = `{player.DisplayName}'s Garden`
			player:SetAttribute("PlotIndex", plot.Index)
			return
		end
	end
	warn(`[PlotService] No free plot for {player.Name}`)
end

local function release(player: Player)
	local plot = playerPlots[player]
	if not plot then
		return
	end
	playerPlots[player] = nil
	plot.Owner = nil
	plot.Model:SetAttribute("OwnerUserId", 0)
	plot.SignLabel.Text = "Free garden"
	for _, child in plot.Model:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Hedge" then
			child.Color = FENCE
		elseif child:IsA("BasePart") and child.Name == "Ground" then
			child.Color = GRASS
		end
	end
	if plot.GroveLabel then
		plot.GroveLabel.Text = "Spirit Grove\nUnlocks at Level 25"
	end
	for _, folder in plot.Folders do
		folder:ClearAllChildren()
	end
	table.clear(plot.TileParts)
end

-- Public API -----------------------------------------------------------------------------

function PlotService.GetPlot(player: Player): Plot?
	return playerPlots[player]
end

function PlotService.GetSize(data: any): (number, number)
	local entry = Config.PlotSizes[data.Plot.SizeIndex] or Config.PlotSizes[1]
	return entry.Width, entry.Depth
end

-- Next plot size the player could buy (or nil)
function PlotService.GetNextExpansion(data: any): any
	local nextEntry = Config.PlotSizes[data.Plot.SizeIndex + 1]
	if nextEntry and data.GardenLevel >= nextEntry.Level then
		return nextEntry
	end
	return nil
end

function PlotService.IsInside(plot: Plot, position: Vector3, margin: number?): boolean
	local offset = position - plot.Center
	local limit = HALF + (margin or 0)
	return math.abs(offset.X) <= limit and math.abs(offset.Z) <= limit
end

function PlotService.GetTilePart(player: Player, tileId: string): BasePart?
	local plot = playerPlots[player]
	return if plot then plot.TileParts[tileId] else nil
end

-- The player's own tile under (or closest to) a position, within reach studs (flat distance)
function PlotService.TileAt(player: Player, position: Vector3, reach: number): (string?, BasePart?)
	local plot = playerPlots[player]
	if not plot then
		return nil, nil
	end
	local bestId, bestTile, best = nil, nil, reach
	for tileId, tile in plot.TileParts do
		local offset = tile.Position - position
		local flat = math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
		if flat < best and math.abs(offset.Y) < 8 then
			bestId, bestTile, best = tileId, tile, flat
		end
	end
	return bestId, bestTile
end

-- True when the position is on (or within margin of) one of the plot's soil tiles
function PlotService.IsOnField(plot: Plot, position: Vector3, margin: number?): boolean
	local limit = TILE / 2 + (margin or 0)
	for _, tile in plot.TileParts do
		local p = tile.Position
		if math.abs(p.X - position.X) <= limit and math.abs(p.Z - position.Z) <= limit then
			return true
		end
	end
	return false
end

function PlotService.IsInsideOwnerPlot(player: Player?, position: Vector3): boolean
	local plot = player and playerPlots[player]
	return plot ~= nil and PlotService.IsInside(plot, position)
end

-- Slight color variation between soil tiles so the farm does not look flat
local function tileShade(tileId: string): number
	local h = 0
	for i = 1, #tileId do
		h = (h * 31 + string.byte(tileId, i)) % 997
	end
	return (h % 7) / 40
end

local function addTile(plot: Plot, tileId: string, position: Vector3)
	local soilColor = SOIL:Lerp(Color3.fromRGB(150, 105, 65), tileShade(tileId))
	local tile = Build.Part({ Name = tileId, Size = Vector3.new(TILE - 0.6, 0.4, TILE - 0.6), Position = position, Color = soilColor, Material = Enum.Material.Ground, CanCollide = true, Parent = plot.Folders.Tiles })
	tile:SetAttribute("TileId", tileId)
	tile:SetAttribute("SoilColor", soilColor) -- DecorService restores this when a decoration is picked up
	-- two raised planting rows (the crops sit on them)
	for _, x in { -1.3, 1.3 } do
		Build.Part({ Name = "Ridge", Size = Vector3.new(1.5, 0.12, TILE - 1.4), Position = position + Vector3.new(x * (TILE / 8), 0.26, 0), Color = SOIL:Lerp(Color3.fromRGB(160, 115, 75), 0.35), Material = Enum.Material.Ground, Parent = tile })
	end
	local prompt = Build.Prompt(tile, "Plant", "Soil", { Distance = 9 })
	prompt.Triggered:Connect(function(who)
		if who == plot.Owner then
			S.CropService.OnTileTriggered(who, tileId)
		end
	end)
	plot.TileParts[tileId] = tile
end

-- (Re)build farm tiles for the current plot size, plus the Extra Plot pass area
function PlotService.BuildTiles(player: Player)
	local plot = playerPlots[player]
	local data = S.DataService.GetData(player)
	if not plot or not data then
		return
	end
	plot.Folders.Tiles:ClearAllChildren()
	table.clear(plot.TileParts)

	local width, depth = PlotService.GetSize(data)
	for x = 0, width - 1 do
		for z = 0, depth - 1 do
			local offset = Vector3.new((x - (width - 1) / 2) * TILE, 0.4, (z - (depth - 1) / 2) * TILE)
			addTile(plot, Util.TileId(x, z), plot.Center + offset)
		end
	end
	-- wooden border around the farm
	local halfW, halfD = width * TILE / 2 + 0.5, depth * TILE / 2 + 0.5
	for _, side in { -1, 1 } do
		Build.Part({ Name = "Border", Size = Vector3.new(halfW * 2 + 1, 0.8, 0.8), Position = plot.Center + Vector3.new(0, 0.4, side * halfD), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = plot.Folders.Tiles })
		Build.Part({ Name = "Border", Size = Vector3.new(0.8, 0.8, halfD * 2), Position = plot.Center + Vector3.new(side * halfW, 0.4, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = plot.Folders.Tiles })
	end
	if data.Purchases.PassesOwned.pass_plot then
		for i = 0, WORLD.ExtraPlotColumns - 1 do
			for j = 0, WORLD.ExtraPlotRows - 1 do
				addTile(plot, `e{i}_{j}`, plot.Center + WORLD.ExtraPlotOrigin + Vector3.new(i * TILE, 0.4, -j * TILE))
			end
		end
	end
	S.DecorService.RefreshAll(player)
	S.CropService.RefreshAll(player)
end

-- Garden theme cosmetic recolors hedges and ground
function PlotService.ApplyTheme(player: Player)
	local plot = playerPlots[player]
	local data = S.DataService.GetData(player)
	if not plot or not data then
		return
	end
	local theme = data.Equipped.Theme and (Products.CosmeticById[data.Equipped.Theme] or (Products.PassCosmetics :: any)[data.Equipped.Theme])
	local hedgeColor = if theme and theme.Color then theme.Color:Lerp(FENCE, 0.3) else FENCE
	local groundColor = if theme and theme.Color then theme.Color:Lerp(GRASS, 0.6) else GRASS
	for _, child in plot.Model:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Hedge" then
			child.Color = hedgeColor
		elseif child:IsA("BasePart") and child.Name == "Ground" then
			child.Color = groundColor
		end
	end
end


function PlotService.Init()
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = Workspace
	for index = 1, WORLD.PlotCount do
		table.insert(plots, buildPlot(index))
	end
	buildRoads()
end

function PlotService.Start()
	local function onPlayerAdded(player: Player)
		assign(player)
		player.CharacterAdded:Connect(function(character)
			teleportToPlot(player, character)
		end)
		if player.Character then
			task.spawn(teleportToPlot, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(release)

	S.DataService.ProfileLoaded:Connect(function(player: Player)
		assign(player) -- no-op unless the profile loaded before PlayerAdded ran here
		PlotService.BuildTiles(player)
		PlotService.ApplyTheme(player)
	end)
end

return PlotService
