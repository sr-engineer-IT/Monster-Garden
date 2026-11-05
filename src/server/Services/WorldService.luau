--!strict
-- WorldService: everything around the gardens, built once at server start.
--   * Roblox Terrain: grass floor, gentle forest hills, a ring of mountains so the world never
--     ends in the sky, a lake with a sandy shore
--   * a thick mixed forest (oaks, pines, bushes, rocks) on the hills
--   * themed explore areas (Whisper Forest, Echo Caves, Monster Territories, Ancient Moonlands)
--   * street lamps along the roads and atmosphere/haze in Lighting
-- The gardens themselves stay on the flat baseplate (PlotService). Pure decoration: no gameplay.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Explore = require(ConfigFolder:WaitForChild("Explore"))

local Build = require(script.Parent.Parent.Build)
local Props = require(script.Parent.Parent.Props)
local S = require(script.Parent.Parent.Registry)

local WorldService = {}

local WORLD = Config.World
local GROUND = WORLD.GroundY
local EDGE = WORLD.WorldHalfSize -- playable world half size
local OUTER = EDGE + 340 -- mountains reach out to here
-- Flat garden area (all gardens and roads), rounded to the 4-stud terrain grid
local BOX_X = math.ceil((WORLD.GridHalf + 8) / 4) * 4
local BOX_Z = BOX_X

local LAKE = { Center = Vector3.new(640, 0, 640), Radius = 70 }

local GRASS = Color3.fromRGB(96, 158, 74)

local terrain: Terrain
local folder: Folder

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Distance from (x, z) to the nearest place that must stay flat (gardens, explore areas, lake)
local function flatDistance(x: number, z: number): number
	local dx = math.max(0, math.abs(x) - BOX_X)
	local dz = math.max(0, math.abs(z) - BOX_Z)
	local best = math.sqrt(dx * dx + dz * dz)
	for _, region in Explore.Regions do
		local d = (Vector3.new(x, 0, z) - region.Center).Magnitude - (region.Radius + 25)
		best = math.min(best, d)
	end
	best = math.min(best, (Vector3.new(x, 0, z) - LAKE.Center).Magnitude - (LAKE.Radius + 20))
	return best
end

-- Ground height at (x, z): flat near gameplay, rolling hills in the forest, mountains at the edge
function WorldService.HeightAt(x: number, z: number): number
	local fade = smoothstep(flatDistance(x, z) / 70)
	local hills = math.max(0, math.noise(x / 95, z / 95, 3.7) + 0.15) * 16 * fade
	local m = math.max(math.abs(x), math.abs(z))
	local ramp = math.max(0, m - (EDGE - 70))
	local mountains = 0
	if ramp > 0 then
		local n = math.noise(x / 150, z / 150, 9.1)
		mountains = math.min(300, ramp * 0.75 * (0.85 + n * 1.1) + ramp * 0.15)
	end
	return GROUND + hills + math.max(0, mountains)
end

-- Terrain -----------------------------------------------------------------------------------------

local function fillFloor()
	-- Grass floor everywhere except the flat garden box (the baseplate covers that)
	local thickness = 12
	local y = GROUND - thickness / 2
	local function block(x1: number, z1: number, x2: number, z2: number)
		local step = 512
		local x = x1
		while x < x2 do
			local z = z1
			local w = math.min(step, x2 - x)
			while z < z2 do
				local d = math.min(step, z2 - z)
				terrain:FillBlock(CFrame.new(x + w / 2, y, z + d / 2), Vector3.new(w, thickness, d), Enum.Material.Grass)
				z += d
			end
			x += w
			task.wait()
		end
	end
	block(-OUTER, -OUTER, OUTER, -BOX_Z) -- north strip
	block(-OUTER, BOX_Z, OUTER, OUTER) -- south strip
	block(-OUTER, -BOX_Z, -BOX_X, BOX_Z) -- west
	block(BOX_X, -BOX_Z, OUTER, BOX_Z) -- east
end

local function fillHills()
	local count = 0
	local function column(x: number, z: number, size: number)
		local h = WorldService.HeightAt(x, z) - GROUND
		if h < 1 then
			return
		end
		local top = if h > 170 then Enum.Material.Snow elseif h > 70 then Enum.Material.Rock else Enum.Material.Grass
		if h > 10 then
			terrain:FillBlock(CFrame.new(x, GROUND + (h - 6) / 2, z), Vector3.new(size, h - 6, size), Enum.Material.Rock)
			terrain:FillBlock(CFrame.new(x, GROUND + h - 4, z), Vector3.new(size, 8, size), top)
		else
			terrain:FillBlock(CFrame.new(x, GROUND + h / 2, z), Vector3.new(size, h, size), Enum.Material.Grass)
		end
		count += 1
		if count % 300 == 0 then
			task.wait()
		end
	end
	-- Forest hills: 8 stud columns inside the world
	for x = -EDGE, EDGE, 8 do
		for z = -EDGE, EDGE, 8 do
			if math.abs(x) > BOX_X + 8 or math.abs(z) > BOX_Z + 8 then
				column(x, z, 8)
			end
		end
	end
	-- Mountains: 16 stud columns in the outer ring
	for x = -OUTER, OUTER, 16 do
		for z = -OUTER, OUTER, 16 do
			if math.max(math.abs(x), math.abs(z)) > EDGE then
				column(x, z, 16)
			end
		end
	end
end

local function fillLake()
	local c = LAKE.Center
	local disc = CFrame.new(c.X, GROUND - 1, c.Z) * CFrame.Angles(0, 0, math.rad(90))
	terrain:FillCylinder(disc, 2, LAKE.Radius + 14, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(c.X, GROUND - 4, c.Z) * CFrame.Angles(0, 0, math.rad(90)), 8, LAKE.Radius, Enum.Material.Water)
	-- reeds and lily pads
	local rng = Random.new(5)
	for i = 1, 26 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = LAKE.Radius + rng:NextNumber(-4, 6)
		local p = c + Vector3.new(math.cos(angle) * r, GROUND, math.sin(angle) * r)
		Build.Part({ Size = Vector3.new(0.4, rng:NextNumber(3, 5), 0.4), Position = p + Vector3.new(0, 1.5, 0), Color = Color3.fromRGB(90, 140, 60), Parent = folder })
	end
	for i = 1, 14 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(10, LAKE.Radius - 10)
		Build.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 4, 4), CFrame = CFrame.new(c + Vector3.new(math.cos(angle) * r, GROUND + 0.05, math.sin(angle) * r)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(70, 160, 70), Parent = folder })
	end
end

local function nearRegion(p: Vector3, pad: number): boolean
	for _, region in Explore.Regions do
		if (p - region.Center).Magnitude < region.Radius + pad then
			return true
		end
	end
	return (p - LAKE.Center).Magnitude < LAKE.Radius + 16
end

local function buildForest()
	local forest = Instance.new("Folder")
	forest.Name = "Forest"
	forest.Parent = folder
	local rng = Random.new(42)
	local placed = { tree = 0, bush = 0, rock = 0 }
	local want = { tree = 720, bush = 360, rock = 180 }
	local tries = 0
	while (placed.tree < want.tree or placed.bush < want.bush or placed.rock < want.rock) and tries < 30000 do
		tries += 1
		local x = rng:NextNumber(-EDGE + 10, EDGE - 10)
		local z = rng:NextNumber(-EDGE + 10, EDGE - 10)
		if math.abs(x) > BOX_X + 14 or math.abs(z) > BOX_Z + 14 then
			local p = Vector3.new(x, 0, z)
			if not nearRegion(p, 14) then
				local base = Vector3.new(x, WorldService.HeightAt(x, z) - 0.5, z)
				local roll = rng:NextNumber()
				if roll < 0.6 and placed.tree < want.tree then
					placed.tree += 1
					if rng:NextNumber() < 0.45 then
						Props.Pine(CFrame.new(base), forest, rng)
					else
						Props.Oak(CFrame.new(base), forest, rng)
					end
				elseif roll < 0.85 and placed.bush < want.bush then
					placed.bush += 1
					Props.Bush(CFrame.new(base), forest, rng)
				elseif placed.rock < want.rock then
					placed.rock += 1
					Props.Rock(CFrame.new(base), forest, rng)
				end
			end
		end
		if tries % 150 == 0 then
			task.wait()
		end
	end
end

-- Explore area themes ---------------------------------------------------------------------------------

local function ringPoint(center: Vector3, radius: number, angle: number): Vector3
	return center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local function buildRegionThemes()
	local rng = Random.new(77)
	for _, region in Explore.Regions do
		local theme = Instance.new("Folder")
		theme.Name = `Theme_{region.Id}`
		theme.Parent = folder
		local c = region.Center
		local r = region.Radius
		-- opening faces the gardens (world center)
		local toCenter = math.atan2(-c.Z, -c.X)
		local function inGap(angle: number): boolean
			local diff = math.abs((angle - toCenter + math.pi) % (2 * math.pi) - math.pi)
			return diff < 0.35
		end

		if region.Id == "forest" then
			-- Whisper Forest: wall of dark pines, glowing mushrooms, purple mist lights
			for i = 1, 70 do
				local angle = rng:NextNumber(0, math.pi * 2)
				if not inGap(angle) then
					Props.Pine(CFrame.new(ringPoint(c, r + rng:NextNumber(4, 40), angle)), theme, rng, Color3.fromRGB(25, rng:NextInteger(70, 90), 60))
				end
			end
			for i = 1, 18 do
				local p = ringPoint(c, rng:NextNumber(10, r - 6), rng:NextNumber(0, math.pi * 2))
				local stem = rng:NextNumber(1.5, 3)
				Build.Part({ Size = Vector3.new(0.6, stem, 0.6), Position = p + Vector3.new(0, stem / 2, 0), Color = Color3.fromRGB(230, 225, 210), Parent = theme })
				local cap = Build.Ball({ Size = Vector3.new(2.6, 1.2, 2.6), Position = p + Vector3.new(0, stem, 0), Color = Color3.fromRGB(180, 90, 255), Material = Enum.Material.Neon, Parent = theme })
				if i % 3 == 0 then
					local light = Instance.new("PointLight")
					light.Color = Color3.fromRGB(180, 110, 255)
					light.Range = 18
					light.Brightness = 1.5
					light.Parent = cap
				end
			end
		elseif region.Id == "caves" then
			-- Echo Caves: a ring of rocky cliffs with an entrance, glowing crystals
			for i = 0, 35 do
				local angle = i / 36 * math.pi * 2
				if not inGap(angle) then
					local p = ringPoint(c, r + 14, angle)
					terrain:FillBall(Vector3.new(p.X, GROUND + 8, p.Z), rng:NextNumber(14, 22), Enum.Material.Slate)
				end
			end
			for i = 1, 14 do
				local p = ringPoint(c, rng:NextNumber(r * 0.4, r - 4), rng:NextNumber(0, math.pi * 2))
				local crystal = Build.Part({ Size = Vector3.new(1.6, rng:NextNumber(4, 9), 1.6), CFrame = CFrame.new(p + Vector3.new(0, 2.5, 0)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)), Color = Color3.fromRGB(110, 220, 255), Material = Enum.Material.Neon, Parent = theme })
				if i % 3 == 0 then
					local light = Instance.new("PointLight")
					light.Color = Color3.fromRGB(110, 220, 255)
					light.Range = 20
					light.Parent = crystal
				end
			end
		elseif region.Id == "territories" then
			-- Monster Territories: cracked dark ground, bone spikes, dead trees
			terrain:FillCylinder(CFrame.new(c.X, GROUND - 1, c.Z) * CFrame.Angles(0, 0, math.rad(90)), 2.2, r + 30, Enum.Material.CrackedLava)
			for i = 1, 26 do
				local angle = rng:NextNumber(0, math.pi * 2)
				if not inGap(angle) then
					local p = ringPoint(c, r + rng:NextNumber(-2, 18), angle)
					local h = rng:NextNumber(6, 14)
					Build.Part({ Size = Vector3.new(1.6, h, 1.6), CFrame = CFrame.new(p + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)), Color = Color3.fromRGB(235, 225, 200), Material = Enum.Material.Marble, CanCollide = true, Parent = theme })
				end
			end
			for i = 1, 16 do
				local p = ringPoint(c, r + rng:NextNumber(20, 45), rng:NextNumber(0, math.pi * 2))
				local h = rng:NextNumber(10, 16)
				Build.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.6, 1.6), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 45, 40), Material = Enum.Material.Wood, CanCollide = true, Parent = theme })
				for b = 1, 2 do
					Build.Part({ Size = Vector3.new(0.6, h * 0.35, 0.6), CFrame = CFrame.new(p + Vector3.new(0, h * (0.55 + b * 0.15), 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(rng:NextNumber(30, 55))), Color = Color3.fromRGB(60, 45, 40), Parent = theme })
				end
			end
		elseif region.Id == "moonlands" then
			-- Ancient Moonlands: pale stone ground, ruined pillars, floating moon rocks
			terrain:FillCylinder(CFrame.new(c.X, GROUND - 1, c.Z) * CFrame.Angles(0, 0, math.rad(90)), 2.2, r + 30, Enum.Material.Salt)
			for i = 0, 11 do
				local angle = i / 12 * math.pi * 2
				if not inGap(angle) then
					local p = ringPoint(c, r + 8, angle)
					local h = if i % 3 == 0 then rng:NextNumber(4, 8) else rng:NextNumber(14, 22)
					Build.Part({ Size = Vector3.new(4, h, 4), Position = p + Vector3.new(0, h / 2, 0), Color = Color3.fromRGB(205, 210, 230), Material = Enum.Material.Marble, CanCollide = true, Parent = theme })
				end
			end
			for i = 1, 10 do
				local p = ringPoint(c, rng:NextNumber(0, r + 30), rng:NextNumber(0, math.pi * 2))
				local s = rng:NextNumber(3, 7)
				local stone = Build.Part({ Size = Vector3.new(s, s * 0.7, s), CFrame = CFrame.new(p + Vector3.new(0, rng:NextNumber(18, 34), 0)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6), 0), Color = Color3.fromRGB(150, 160, 210), Material = Enum.Material.Slate, Parent = theme })
				local glow = Instance.new("PointLight")
				glow.Color = Color3.fromRGB(170, 190, 255)
				glow.Range = 16
				glow.Parent = stone
			end
		end
		task.wait()
	end
end

-- Lamps ------------------------------------------------------------------------------------------------

local function buildLamps()
	local lamps = Instance.new("Folder")
	lamps.Name = "Lamps"
	lamps.Parent = folder
	local n = WORLD.GridSize
	-- every road crossing, offset to a corner so lamps never block the road
	for i = 0, n do
		for j = 0, n do
			local x = (i - n / 2) * WORLD.PlotSpacing
			local z = (j - n / 2) * WORLD.PlotSpacing
			if not (x == 0 and z == 0) then -- the town fountain sits on the middle crossing
				Props.Lamp(CFrame.new(x + 11, GROUND, z + 11), lamps)
			end
		end
	end
	-- both sides of every garden gate, outside the fence
	local half = WORLD.PlotHalfSize
	local side = WORLD.GateWidth / 2 + 3
	for _, c in WORLD.PlotCenters do
		local center = Vector3.new(c.X, GROUND, c.Z)
		for _, dir in { Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0) } do
			local right = Vector3.new(-dir.Z, 0, dir.X)
			Props.Lamp(CFrame.new(center + dir * (half + 5) + right * side), lamps)
		end
	end
end

-- Town Square -----------------------------------------------------------------------------------------

local function buildTown()
	local town = Instance.new("Folder")
	town.Name = "TownSquare"
	town.Parent = folder
	local rng = Random.new(1234)
	local plaza = WORLD.TownPlazaRadius
	local center = Vector3.new(0, GROUND, 0)

	-- cobblestone plaza with a ring pattern
	local function disc(radius: number, y: number, color: Color3, material: Enum.Material)
		Build.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, radius * 2, radius * 2), CFrame = CFrame.new(center + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = material, CanCollide = true, Parent = town })
	end
	disc(plaza + 4, 0.2, Color3.fromRGB(150, 140, 125), Enum.Material.Cobblestone)
	disc(plaza, 0.24, Color3.fromRGB(196, 186, 165), Enum.Material.Cobblestone)
	disc(plaza * 0.55, 0.28, Color3.fromRGB(175, 165, 145), Enum.Material.Cobblestone)
	Props.Fountain(CFrame.new(center + Vector3.new(0, 0.3, 0)), town)

	-- welcome arch sign over the fountain
	local title = Build.Part({ Size = Vector3.new(1, 1, 1), Position = center + Vector3.new(0, 26, 0), Transparency = 1, Parent = town })
	local gui = Build.Billboard(title, 420, 90, 0)
	gui.Size = UDim2.fromScale(64, 13) -- in studs: a real-size sign, not a fixed screen size
	gui.MaxDistance = 900
	Build.Label(gui, "Moonlit Grove", { TextColor3 = Color3.fromRGB(255, 225, 120), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0 })

	-- benches and lamps around the plaza, facing the fountain
	for i = 0, 7 do
		local angle = (i + 0.5) / 8 * math.pi * 2
		local p = center + Vector3.new(math.cos(angle) * (plaza - 12), 0.3, math.sin(angle) * (plaza - 12))
		Props.Bench(CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z)), town)
		local lampAt = center + Vector3.new(math.cos(angle) * (plaza + 6), 0, math.sin(angle) * (plaza + 6))
		Props.Lamp(CFrame.new(lampAt), town)
	end

	-- shops on three corners of the plaza, facing the fountain
	for _, shop in WORLD.TownShops do
		local p = center + shop.Offset
		local counter = Props.ShopBooth(CFrame.lookAt(p, center * Vector3.new(1, 0, 1) + Vector3.new(0, p.Y, 0)), shop.Id, shop.Name, shop.Color, town)
		local prompt = Build.Prompt(counter, "Shop", shop.Name, { Distance = 12 })
		prompt.Triggered:Connect(function(player)
			S.EconomyService.OpenMerchant(player)
		end)
		Build.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 36, 36), CFrame = CFrame.new(p + Vector3.new(0, 0.22, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(196, 186, 165), Material = Enum.Material.Cobblestone, Parent = town })
	end

	-- notice board on the fourth corner
	local boardAt = center + Vector3.new(-92, 0, 92)
	local facing = CFrame.lookAt(boardAt, center)
	Build.Part({ Size = Vector3.new(14, 9, 0.6), CFrame = facing * CFrame.new(0, 6, 0), Color = Color3.fromRGB(150, 105, 65), Material = Enum.Material.WoodPlanks, CanCollide = true, Parent = town })
	for _, x in { -6.5, 6.5 } do
		Build.Part({ Size = Vector3.new(0.8, 11, 0.8), CFrame = facing * CFrame.new(x, 5.5, 0.4), Color = Color3.fromRGB(105, 74, 48), Parent = town })
	end
	local face = Build.Part({ Size = Vector3.new(13, 8, 0.1), CFrame = facing * CFrame.new(0, 6, -0.36), Color = Color3.fromRGB(240, 228, 200), Material = Enum.Material.Fabric, Parent = town })
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.PixelsPerStud = 40
	surface.Parent = face
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(80, 55, 35)
	text.Text = "TOWN NOTICES\n\nGrow crops in your garden.\nSell them at any shop.\nDefend your garden at night!\nVisit friends and trade."
	text.Parent = surface
	Instance.new("UIPadding", text).PaddingLeft = UDim.new(0, 20)
	Build.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 30, 30), CFrame = CFrame.new(boardAt + Vector3.new(0, 0.22, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(196, 186, 165), Material = Enum.Material.Cobblestone, Parent = town })

	-- park: trees, bushes and flower beds in the town grass, clear of roads, plaza and shops
	local edge = WORLD.PlotSpacing - 14
	local placed, tries = 0, 0
	while placed < 46 and tries < 2000 do
		tries += 1
		local x = rng:NextNumber(-edge, edge)
		local z = rng:NextNumber(-edge, edge)
		local p = Vector3.new(x, GROUND, z)
		local clear = math.abs(x) > 16 and math.abs(z) > 16 and p.Magnitude > plaza + 22
		for _, shop in WORLD.TownShops do
			if (p - shop.Offset).Magnitude < 30 then
				clear = false
			end
		end
		if (p - Vector3.new(-92, 0, 92)).Magnitude < 26 then
			clear = false
		end
		if clear then
			placed += 1
			if placed % 3 == 0 then
				Props.Bush(CFrame.new(p), town, rng)
			else
				Props.Tree(CFrame.new(p), town, rng)
			end
		end
	end
	for _, q in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		for k = 0, 1 do
			local p = q * (plaza + 30 + k * 10)
			Props.FlowerBed(CFrame.lookAt(p, Vector3.zero) + Vector3.new(0, GROUND + 0.2, 0), 12, town, rng)
		end
	end
end

-- Lighting -------------------------------------------------------------------------------------------------

local function setupLighting()
	Lighting.Ambient = Color3.fromRGB(70, 70, 80)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.3
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.28
		atmosphere.Offset = 0.2
		atmosphere.Color = Color3.fromRGB(199, 215, 240)
		atmosphere.Decay = Color3.fromRGB(110, 125, 150)
		atmosphere.Glare = 0.2
		atmosphere.Haze = 1.2
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.MoonAngularSize = 16
		sky.SunAngularSize = 14
		sky.StarCount = 4000
		sky.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.6
		bloom.Size = 30
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
	end
end

-- Baseplate: only under the flat garden area, grass colored (terrain covers the rest)
local function setupBaseplate()
	for _, child in Workspace:GetChildren() do
		if child:IsA("BasePart") and not child:IsA("Terrain") and (child.Name == "Baseplate" or child.Size.X >= 500 and child.Size.Z >= 500) then
			child.Size = Vector3.new(BOX_X * 2, 20, BOX_Z * 2)
			child.CFrame = CFrame.new(0, GROUND - 10, 0)
			child.Color = GRASS
			child.Material = Enum.Material.Grass
			for _, decal in child:GetChildren() do
				if decal:IsA("Texture") or decal:IsA("Decal") then
					decal:Destroy()
				end
			end
		elseif child:IsA("SpawnLocation") then
			child.Position = Vector3.new(child.Position.X, GROUND + child.Size.Y / 2, child.Position.Z)
		end
	end
end

function WorldService.Init()
	terrain = Workspace.Terrain
	folder = Instance.new("Folder")
	folder.Name = "World"
	folder.Parent = Workspace
	setupBaseplate()
	setupLighting()
	pcall(function()
		terrain:SetMaterialColor(Enum.Material.Grass, GRASS)
		terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(120, 118, 115))
		terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(215, 195, 145))
		terrain.WaterColor = Color3.fromRGB(60, 140, 190)
		terrain.WaterTransparency = 0.4
		terrain.WaterWaveSize = 0.08
		terrain.WaterReflectance = 0.6
	end)
	pcall(function()
		(terrain :: any).Decoration = true -- animated grass blades
	end)
end

function WorldService.Start()
	task.spawn(function()
		local started = os.clock()
		fillFloor()
		fillHills()
		fillLake()
		buildTown()
		buildLamps()
		buildForest()
		buildRegionThemes()
		print(`[WorldService] World built in {string.format("%.1f", os.clock() - started)}s`)
	end)
end

return WorldService
