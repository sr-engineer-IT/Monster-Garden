--!strict
-- Scenery props shared by the gardens, the Town Square and the world. Every prop first tries a
-- real 3D model from assets/models (see Assets.luau and Resources/Model-Names.md) and falls back
-- to a stylized code-built version, so the game looks complete either way.
-- `at` is a CFrame on the ground: position = bottom center, look vector = the prop's front.

local Assets = require(script.Parent.Assets)
local Build = require(script.Parent.Build)

local Props = {}

local WOOD = Color3.fromRGB(150, 105, 65)
local DARK_WOOD = Color3.fromRGB(105, 74, 48)
local ROOF = Color3.fromRGB(196, 74, 64)
local WALL = Color3.fromRGB(245, 232, 205)
local STONE = Color3.fromRGB(150, 150, 155)

local function at(cf: CFrame, x: number, y: number, z: number): CFrame
	return cf * CFrame.new(x, y, z)
end

local function part(props: { [string]: any }): Part
	return Build.Part(props)
end

-- Trees, bushes, rocks -------------------------------------------------------------------------------

function Props.Oak(cf: CFrame, parent: Instance, rng: Random)
	if Assets.Place("Tree_Oak", cf * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), parent, { Height = rng:NextNumber(18, 26), Collide = true }) then
		return
	end
	local base = cf.Position
	local h = rng:NextNumber(12, 20)
	local trunkW = rng:NextNumber(2.2, 3.2)
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, trunkW, trunkW), CFrame = CFrame.new(base + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = DARK_WOOD, Material = Enum.Material.Wood, CanCollide = true, Parent = parent })
	local green = Color3.fromRGB(rng:NextInteger(50, 80), rng:NextInteger(125, 165), rng:NextInteger(50, 70))
	local size = rng:NextNumber(11, 16)
	Build.Ball({ Size = Vector3.one * size, Position = base + Vector3.new(0, h + 1, 0), Color = green, Material = Enum.Material.Grass, Parent = parent })
	for _ = 1, 2 do
		local off = Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-3, 0), rng:NextNumber(-4, 4))
		Build.Ball({ Size = Vector3.one * size * rng:NextNumber(0.6, 0.8), Position = base + Vector3.new(0, h, 0) + off, Color = green:Lerp(Color3.new(0, 0, 0), 0.12), Material = Enum.Material.Grass, Parent = parent })
	end
end

function Props.Pine(cf: CFrame, parent: Instance, rng: Random, color: Color3?)
	if not color and Assets.Place("Tree_Pine", cf * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), parent, { Height = rng:NextNumber(20, 30), Collide = true }) then
		return
	end
	local base = cf.Position
	local h = rng:NextNumber(16, 28)
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(h * 0.5, 2, 2), CFrame = CFrame.new(base + Vector3.new(0, h * 0.25 - 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(90, 62, 40), Material = Enum.Material.Wood, CanCollide = true, Parent = parent })
	local green = color or Color3.fromRGB(rng:NextInteger(30, 50), rng:NextInteger(95, 120), rng:NextInteger(55, 75))
	for i = 0, 3 do
		local t = i / 3
		local w = (1 - t * 0.75) * h * 0.42
		Build.Ball({ Size = Vector3.new(w, h * 0.26, w), Position = base + Vector3.new(0, h * (0.3 + t * 0.55), 0), Color = green, Material = Enum.Material.Grass, Parent = parent })
	end
end

function Props.Tree(cf: CFrame, parent: Instance, rng: Random)
	if rng:NextNumber() < 0.45 then
		Props.Pine(cf, parent, rng)
	else
		Props.Oak(cf, parent, rng)
	end
end

function Props.Bush(cf: CFrame, parent: Instance, rng: Random)
	if Assets.Place("Bush", cf * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), parent, { Height = rng:NextNumber(3, 5) }) then
		return
	end
	local base = cf.Position
	local s = rng:NextNumber(3, 6)
	local green = Color3.fromRGB(rng:NextInteger(60, 90), rng:NextInteger(140, 175), rng:NextInteger(55, 75))
	Build.Ball({ Size = Vector3.new(s * 1.4, s, s * 1.4), Position = base + Vector3.new(0, s * 0.35, 0), Color = green, Material = Enum.Material.Grass, Parent = parent })
	if rng:NextNumber() < 0.4 then
		for _ = 1, 3 do
			Build.Ball({ Size = Vector3.one * 0.7, Position = base + Vector3.new(rng:NextNumber(-s * 0.5, s * 0.5), s * 0.75, rng:NextNumber(-s * 0.5, s * 0.5)), Color = Color3.fromRGB(230, 60, 80), Parent = parent })
		end
	end
end

function Props.Rock(cf: CFrame, parent: Instance, rng: Random, color: Color3?)
	if not color and Assets.Place("Rock", cf * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), parent, { Width = rng:NextNumber(4, 9), Collide = true }) then
		return
	end
	local s = rng:NextNumber(3, 8)
	part({
		Size = Vector3.new(s * rng:NextNumber(1, 1.6), s * rng:NextNumber(0.6, 1), s),
		CFrame = CFrame.new(cf.Position + Vector3.new(0, s * 0.25, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)),
		Color = color or Color3.fromRGB(rng:NextInteger(120, 145), rng:NextInteger(120, 140), rng:NextInteger(125, 145)),
		Material = Enum.Material.Slate,
		CanCollide = true,
		Parent = parent,
	})
end

function Props.FlowerBed(cf: CFrame, length: number, parent: Instance, rng: Random)
	local colors = { Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 220, 90), Color3.fromRGB(170, 130, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 150, 70) }
	part({ Name = "FlowerBed", Size = Vector3.new(length, 0.5, 4), CFrame = at(cf, 0, 0.25, 0), Color = Color3.fromRGB(95, 65, 45), Material = Enum.Material.Ground, Parent = parent })
	local count = math.floor(length / 1.8)
	for i = 1, count do
		local x = -length / 2 + 0.9 + (i - 1) * 1.8
		local z = rng:NextNumber(-1.2, 1.2)
		part({ Size = Vector3.new(0.2, 1, 0.2), CFrame = at(cf, x, 0.9, z), Color = Color3.fromRGB(70, 150, 60), Parent = parent })
		Build.Ball({ Size = Vector3.one * rng:NextNumber(0.8, 1.1), CFrame = at(cf, x, 1.6, z), Color = colors[rng:NextInteger(1, #colors)], Parent = parent })
	end
end

-- Lamps and fences ----------------------------------------------------------------------------------

function Props.Lamp(cf: CFrame, parent: Instance)
	local model = Assets.Place("Lamp", cf, parent, { Height = 11, Collide = true })
	local bulbPart: BasePart
	if model then
		bulbPart = model:FindFirstChildWhichIsA("BasePart", true) :: BasePart
	else
		part({ Size = Vector3.new(0.8, 10, 0.8), CFrame = at(cf, 0, 5, 0), Color = Color3.fromRGB(50, 50, 60), Material = Enum.Material.Metal, CanCollide = true, Parent = parent })
		part({ Size = Vector3.new(2.4, 0.3, 2.4), CFrame = at(cf, 0, 11.8, 0), Color = Color3.fromRGB(50, 50, 60), Material = Enum.Material.Metal, Parent = parent })
		bulbPart = Build.Ball({ Size = Vector3.one * 2, CFrame = at(cf, 0, 10.8, 0), Color = Color3.fromRGB(255, 220, 150), Material = Enum.Material.Neon, Parent = parent })
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 150)
	light.Range = 34
	light.Brightness = 1.6
	light.Shadows = false
	light.Parent = bulbPart
end

-- Wooden picket fence from a to b (on the ground). Visible parts are named "Hedge" so garden
-- themes can recolor them; an invisible wall keeps players and monsters to the gates.
function Props.Fence(a: Vector3, b: Vector3, height: number, color: Color3, parent: Instance)
	local length = (b - a).Magnitude
	if length < 0.5 then
		return
	end
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, b)
	part({ Name = "FenceWall", Size = Vector3.new(1, height + 2, length), CFrame = cf + Vector3.new(0, (height + 2) / 2, 0), Transparency = 1, CanCollide = true, Parent = parent })
	for _, y in { height * 0.35, height * 0.75 } do
		part({ Name = "Hedge", Size = Vector3.new(0.4, 0.5, length), CFrame = cf + Vector3.new(0, y, 0), Color = color, Material = Enum.Material.WoodPlanks, Parent = parent })
	end
	local pickets = math.max(2, math.floor(length / 1.6))
	for i = 0, pickets do
		local p = a:Lerp(b, i / pickets)
		local tall = if i % 4 == 0 then height + 0.6 else height
		part({ Name = "Hedge", Size = Vector3.new(0.5, tall, 0.9), CFrame = CFrame.lookAt(p, p + cf.LookVector) + Vector3.new(0, tall / 2, 0), Color = if i % 4 == 0 then color:Lerp(Color3.new(0, 0, 0), 0.15) else color, Material = Enum.Material.WoodPlanks, Parent = parent })
	end
end

-- Homestead buildings ------------------------------------------------------------------------------------

function Props.Cottage(cf: CFrame, parent: Instance)
	if Assets.Place("Cottage", cf, parent, { Width = 18, Collide = true }) then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Cottage"
	model.Parent = parent
	part({ Size = Vector3.new(16, 0.8, 12), CFrame = at(cf, 0, 0.4, 0), Color = STONE, Material = Enum.Material.Cobblestone, CanCollide = true, Parent = model })
	part({ Size = Vector3.new(15, 8, 11), CFrame = at(cf, 0, 4.8, 0), Color = WALL, Material = Enum.Material.Plaster, CanCollide = true, Parent = model })
	-- beams on the corners
	for _, x in { -7.4, 7.4 } do
		for _, z in { -5.4, 5.4 } do
			part({ Size = Vector3.new(0.8, 8, 0.8), CFrame = at(cf, x, 4.8, z), Color = DARK_WOOD, Material = Enum.Material.Wood, Parent = model })
		end
	end
	-- pitched roof: two slanted slabs
	for _, side in { -1, 1 } do
		part({ Size = Vector3.new(17.5, 0.8, 8.4), CFrame = at(cf, 0, 10.7, side * 3.2) * CFrame.Angles(math.rad(side * 36), 0, 0), Color = ROOF, Material = Enum.Material.Slate, CanCollide = true, Parent = model })
	end
	part({ Size = Vector3.new(1.4, 4, 1.4), CFrame = at(cf, 4.5, 13, 2), Color = Color3.fromRGB(140, 90, 80), Material = Enum.Material.Brick, Parent = model })
	-- door and windows on the front (-Z)
	part({ Size = Vector3.new(3, 5.5, 0.4), CFrame = at(cf, 0, 3.55, -5.6), Color = DARK_WOOD, Material = Enum.Material.WoodPlanks, Parent = model })
	part({ Size = Vector3.new(0.5, 0.5, 0.3), CFrame = at(cf, 1, 3.6, -5.85), Color = Color3.fromRGB(230, 190, 80), Material = Enum.Material.Metal, Parent = model })
	for _, x in { -4.6, 4.6 } do
		local window = part({ Size = Vector3.new(2.8, 2.4, 0.3), CFrame = at(cf, x, 5.2, -5.6), Color = Color3.fromRGB(255, 225, 150), Material = Enum.Material.Neon, Parent = model })
		window.Transparency = 0.2
		part({ Size = Vector3.new(3.4, 0.4, 0.6), CFrame = at(cf, x, 3.8, -5.75), Color = DARK_WOOD, Parent = model })
	end
	-- doorstep and window flower boxes
	part({ Size = Vector3.new(4, 0.5, 2), CFrame = at(cf, 0, 0.55, -6.8), Color = STONE, Material = Enum.Material.Slate, Parent = model })
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 200, 130)
	glow.Range = 16
	glow.Brightness = 0.8
	glow.Parent = model:FindFirstChildWhichIsA("BasePart")
end

function Props.Shed(cf: CFrame, parent: Instance)
	if Assets.Place("Shed", cf, parent, { Width = 12, Collide = true }) then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Shed"
	model.Parent = parent
	part({ Size = Vector3.new(10, 6, 8), CFrame = at(cf, 0, 3, 0), Color = Color3.fromRGB(176, 70, 60), Material = Enum.Material.WoodPlanks, CanCollide = true, Parent = model })
	part({ Size = Vector3.new(11, 0.6, 9), CFrame = at(cf, 0, 6.4, 0) * CFrame.Angles(math.rad(-8), 0, 0), Color = Color3.fromRGB(90, 90, 95), Material = Enum.Material.CorrodedMetal, CanCollide = true, Parent = model })
	part({ Size = Vector3.new(5, 4.5, 0.3), CFrame = at(cf, 0, 2.3, -4.1), Color = Color3.fromRGB(245, 235, 220), Material = Enum.Material.WoodPlanks, Parent = model })
	part({ Size = Vector3.new(0.3, 4.5, 0.4), CFrame = at(cf, 0, 2.3, -4.25) * CFrame.Angles(0, 0, math.rad(45)), Color = Color3.fromRGB(245, 235, 220), Parent = model })
	-- hay bale and barrel beside it
	part({ Size = Vector3.new(3, 2, 2), CFrame = at(cf, 7, 1, -1), Color = Color3.fromRGB(225, 195, 100), Material = Enum.Material.Fabric, CanCollide = true, Parent = model })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 2, 2), CFrame = at(cf, 7, 1.3, 2) * CFrame.Angles(0, 0, math.rad(90)), Color = DARK_WOOD, Material = Enum.Material.Wood, CanCollide = true, Parent = model })
end

function Props.Well(cf: CFrame, parent: Instance)
	if Assets.Place("Well", cf, parent, { Height = 8, Collide = true }) then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Well"
	model.Parent = parent
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 5, 5), CFrame = at(cf, 0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = STONE, Material = Enum.Material.Cobblestone, CanCollide = true, Parent = model })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 4, 4), CFrame = at(cf, 0, 2.9, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 120, 180), Parent = model })
	for _, x in { -2.2, 2.2 } do
		part({ Size = Vector3.new(0.5, 5, 0.5), CFrame = at(cf, x, 5, 0), Color = DARK_WOOD, Parent = model })
	end
	for _, side in { -1, 1 } do
		part({ Size = Vector3.new(5.6, 0.4, 2.2), CFrame = at(cf, 0, 7.8, side * 0.9) * CFrame.Angles(math.rad(side * 30), 0, 0), Color = ROOF, Parent = model })
	end
end

function Props.Mailbox(cf: CFrame, parent: Instance)
	if Assets.Place("Mailbox", cf, parent, { Height = 4 }) then
		return
	end
	part({ Size = Vector3.new(0.4, 3, 0.4), CFrame = at(cf, 0, 1.5, 0), Color = DARK_WOOD, Parent = parent })
	part({ Size = Vector3.new(1.2, 1, 1.8), CFrame = at(cf, 0, 3.4, 0), Color = Color3.fromRGB(70, 110, 200), Material = Enum.Material.Metal, Parent = parent })
	part({ Size = Vector3.new(0.1, 0.8, 0.3), CFrame = at(cf, 0.65, 3.9, 0.4), Color = Color3.fromRGB(220, 50, 50), Parent = parent })
end

function Props.Scarecrow(cf: CFrame, parent: Instance)
	if Assets.Place("Scarecrow", cf, parent, { Height = 8 }) then
		return
	end
	part({ Size = Vector3.new(0.5, 7, 0.5), CFrame = at(cf, 0, 3.5, 0), Color = DARK_WOOD, Parent = parent })
	part({ Size = Vector3.new(5, 0.4, 0.4), CFrame = at(cf, 0, 5.2, 0), Color = DARK_WOOD, Parent = parent })
	part({ Size = Vector3.new(2.4, 2.6, 1.2), CFrame = at(cf, 0, 4.6, 0), Color = Color3.fromRGB(80, 120, 190), Material = Enum.Material.Fabric, Parent = parent })
	Build.Ball({ Size = Vector3.one * 1.8, CFrame = at(cf, 0, 6.8, 0), Color = Color3.fromRGB(230, 190, 120), Material = Enum.Material.Fabric, Parent = parent })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 3.2, 3.2), CFrame = at(cf, 0, 7.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(200, 160, 70), Material = Enum.Material.Fabric, Parent = parent })
	part({ Size = Vector3.new(1.4, 1, 1.4), CFrame = at(cf, 0, 8.1, 0), Color = Color3.fromRGB(200, 160, 70), Material = Enum.Material.Fabric, Parent = parent })
end

function Props.Bench(cf: CFrame, parent: Instance)
	if Assets.Place("Bench", cf, parent, { Width = 6, Collide = true }) then
		return
	end
	part({ Size = Vector3.new(6, 0.4, 2), CFrame = at(cf, 0, 1.6, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, CanCollide = true, Parent = parent })
	part({ Size = Vector3.new(6, 1.6, 0.3), CFrame = at(cf, 0, 2.6, 0.9), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = parent })
	for _, x in { -2.6, 2.6 } do
		part({ Size = Vector3.new(0.4, 1.6, 1.8), CFrame = at(cf, x, 0.8, 0), Color = Color3.fromRGB(60, 60, 65), Material = Enum.Material.Metal, Parent = parent })
	end
end

-- Town Square -----------------------------------------------------------------------------------------------

function Props.Fountain(cf: CFrame, parent: Instance)
	if Assets.Place("Fountain", cf, parent, { Width = 26, Collide = true }) then
		return
	end
	local function disc(radius: number, height: number, y: number, color: Color3, material: Enum.Material, collide: boolean): Part
		return part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, radius * 2, radius * 2), CFrame = at(cf, 0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = material, CanCollide = collide, Parent = parent })
	end
	disc(13, 2.4, 1.2, STONE, Enum.Material.Cobblestone, true)
	local water = disc(11.5, 0.3, 2.3, Color3.fromRGB(80, 170, 230), Enum.Material.Glass, false)
	water.Transparency = 0.25
	disc(2, 7, 4.5, Color3.fromRGB(205, 205, 215), Enum.Material.Marble, true)
	disc(5, 0.8, 8, Color3.fromRGB(205, 205, 215), Enum.Material.Marble, false)
	local top = disc(4.2, 0.3, 8.45, Color3.fromRGB(80, 170, 230), Enum.Material.Glass, false)
	top.Transparency = 0.25
	local orb = Build.Ball({ Size = Vector3.one * 2.4, CFrame = at(cf, 0, 10, 0), Color = Color3.fromRGB(180, 220, 255), Material = Enum.Material.Neon, Parent = parent })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(170, 210, 255)
	light.Range = 30
	light.Brightness = 1.5
	light.Parent = orb
	local splash = Instance.new("ParticleEmitter")
	splash.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255))
	splash.Size = NumberSequence.new(0.6, 0.1)
	splash.Transparency = NumberSequence.new(0.2, 1)
	splash.Lifetime = NumberRange.new(0.8, 1.2)
	splash.Rate = 40
	splash.Speed = NumberRange.new(8, 11)
	splash.SpreadAngle = Vector2.new(18, 18)
	splash.Acceleration = Vector3.new(0, -25, 0)
	splash.Parent = orb
end

-- Market booth with a striped awning. Returns the counter part (for the Shop prompt).
function Props.ShopBooth(cf: CFrame, id: string, title: string, color: Color3, parent: Instance): BasePart
	local model = Instance.new("Model")
	model.Name = id
	model.Parent = parent
	local counter = part({ Name = "Counter", Size = Vector3.new(12, 3.4, 3), CFrame = at(cf, 0, 1.7, -2), Color = WOOD, Material = Enum.Material.WoodPlanks, CanCollide = true, Parent = model })
	if Assets.Place(id, cf, model, { Width = 14, Collide = true }) then
		counter.Transparency = 1
	else
		part({ Size = Vector3.new(12, 6, 0.6), CFrame = at(cf, 0, 3, 3), Color = DARK_WOOD, Material = Enum.Material.WoodPlanks, CanCollide = true, Parent = model })
		for _, x in { -5.7, 5.7 } do
			part({ Size = Vector3.new(0.6, 9, 0.6), CFrame = at(cf, x, 4.5, -3.2), Color = DARK_WOOD, Parent = model })
			part({ Size = Vector3.new(0.6, 9, 0.6), CFrame = at(cf, x, 4.5, 3), Color = DARK_WOOD, Parent = model })
		end
		-- striped awning
		for i = 0, 5 do
			part({
				Size = Vector3.new(2.2, 0.4, 7.4),
				CFrame = at(cf, -5.5 + i * 2.2, 9.6, -0.2) * CFrame.Angles(math.rad(-12), 0, 0),
				Color = if i % 2 == 0 then color else Color3.fromRGB(250, 248, 240),
				Material = Enum.Material.Fabric,
				Parent = model,
			})
		end
		-- goods on the counter
		for i = -2, 2 do
			Build.Ball({ Size = Vector3.one * 1.4, CFrame = at(cf, i * 2.2, 3.9, -2), Color = color:Lerp(Color3.new(1, 1, 1), (i + 2) * 0.12), Parent = model })
		end
	end
	local gui = Build.Billboard(counter, 260, 54, 9)
	gui.Size = UDim2.fromScale(16, 3.4)
	gui.MaxDistance = 200
	Build.Label(gui, title, { TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.4), Font = Enum.Font.FredokaOne })
	return counter
end

return Props
