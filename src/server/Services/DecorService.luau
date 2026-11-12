--!strict
-- DecorService: garden decorations (config/Decor.luau) on the build grid (shared/GardenGrid).
-- Soil tiles (PlotService) and decorations share the grid squares, so players lay out their farm
-- and garden however they like. Build mode ("PlaceDecorAt" / "RemoveDecor") places a decoration
-- on any free square (buying it if none is in storage) and sends it back to storage.
-- Saved as data.Plot.Garden[cellId] = { D = decorId, R = turns } and
-- data.Inventory.Decor[decorId] = count (storage).
-- data.Plot.Decor (decorations on soil tiles, before save version 3) is moved to the grid by
-- Migrations; the tile code below only handles any leftover.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Decor = require(ConfigFolder:WaitForChild("Decor"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local GardenGrid = require(Shared:WaitForChild("GardenGrid"))

local S = require(script.Parent.Parent.Registry)
local Assets = require(script.Parent.Parent.Assets)
local Build = require(script.Parent.Parent.Build)
local Props = require(script.Parent.Parent.Props)

local DecorService = {}

local GRASS = Color3.fromRGB(110, 175, 85)
local STONE = Color3.fromRGB(160, 160, 165)

local function notify(player: Player, text: string)
	Remotes.Get("Notify"):FireClient(player, { Text = text })
end

local function ensure(data: any)
	data.Plot.Decor = data.Plot.Decor or {}
	data.Plot.Garden = data.Plot.Garden or {}
	data.Plot.Soil = data.Plot.Soil or {}
	data.Inventory.Decor = data.Inventory.Decor or {}
end

-- Same random look for the same tile every time it is rebuilt
local function seedOf(tileId: string): number
	local h = 7
	for i = 1, #tileId do
		h = (h * 31 + string.byte(tileId, i)) % 100003
	end
	return h
end

-- Art -----------------------------------------------------------------------------------------------

local function stones(cf: CFrame, parent: Instance, rng: Random)
	for i = 1, 4 do
		local z = -3 + (i - 1) * 2
		Build.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, rng:NextNumber(1.6, 2.2), rng:NextNumber(1.6, 2.2)), CFrame = cf * CFrame.new(rng:NextNumber(-0.7, 0.7), 0.15, z) * CFrame.Angles(0, 0, math.rad(90)), Color = STONE:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.2)), Material = Enum.Material.Slate, Parent = parent })
	end
end

local function tufts(cf: CFrame, parent: Instance, rng: Random)
	for _ = 1, 5 do
		Build.Ball({ Size = Vector3.new(1, 0.7, 1) * rng:NextNumber(0.8, 1.3), CFrame = cf * CFrame.new(rng:NextNumber(-3, 3), 0.2, rng:NextNumber(-3, 3)), Color = GRASS:Lerp(Color3.fromRGB(60, 140, 50), rng:NextNumber(0, 0.6)), Material = Enum.Material.Grass, Parent = parent })
	end
	if rng:NextNumber() < 0.6 then
		Build.Ball({ Size = Vector3.one * 0.6, CFrame = cf * CFrame.new(rng:NextNumber(-2.5, 2.5), 0.5, rng:NextNumber(-2.5, 2.5)), Color = Color3.fromRGB(255, 240, 120), Parent = parent })
	end
end

local function pond(cf: CFrame, parent: Instance, rng: Random)
	Build.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 6.4, 6.4), CFrame = cf * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 110, 100), Material = Enum.Material.Slate, Parent = parent })
	Build.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 5.4, 5.4), CFrame = cf * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(70, 150, 210), Material = Enum.Material.Glass, Transparency = 0.15, Parent = parent })
	for _ = 1, 3 do
		Build.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 1.2, 1.2), CFrame = cf * CFrame.new(rng:NextNumber(-1.8, 1.8), 0.4, rng:NextNumber(-1.8, 1.8)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(80, 170, 70), Parent = parent })
	end
	Build.Ball({ Size = Vector3.one * 0.5, CFrame = cf * CFrame.new(1, 0.6, -0.8), Color = Color3.fromRGB(255, 160, 200), Parent = parent })
end

local function smallFountain(cf: CFrame, parent: Instance)
	Build.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 6.6, 6.6), CFrame = cf * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = STONE, Material = Enum.Material.Cobblestone, Parent = parent })
	Build.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 5.6, 5.6), CFrame = cf * CFrame.new(0, 1.45, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(80, 160, 220), Material = Enum.Material.Glass, Parent = parent })
	Build.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 1, 1), CFrame = cf * CFrame.new(0, 2.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = STONE, Material = Enum.Material.Marble, Parent = parent })
	Build.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 2.6, 2.6), CFrame = cf * CFrame.new(0, 4.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = STONE, Material = Enum.Material.Marble, Parent = parent })
	local top = Build.Ball({ Size = Vector3.one * 0.9, CFrame = cf * CFrame.new(0, 4.9, 0), Color = Color3.fromRGB(150, 210, 255), Material = Enum.Material.Glass, Parent = parent })
	local splash = Instance.new("ParticleEmitter")
	splash.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255))
	splash.Size = NumberSequence.new(0.3, 0.1)
	splash.Lifetime = NumberRange.new(0.6, 0.9)
	splash.Rate = 18
	splash.Speed = NumberRange.new(4, 6)
	splash.SpreadAngle = Vector2.new(25, 25)
	splash.Acceleration = Vector3.new(0, -18, 0)
	splash.Parent = top
end

local function statue(cf: CFrame, parent: Instance)
	Build.Part({ Size = Vector3.new(3.4, 1, 3.4), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(230, 230, 240), Material = Enum.Material.Marble, Parent = parent })
	Build.Part({ Size = Vector3.new(2, 4, 2), CFrame = cf * CFrame.new(0, 3, 0), Color = Color3.fromRGB(225, 225, 235), Material = Enum.Material.Marble, Parent = parent })
	local moon = Build.Ball({ Size = Vector3.one * 2.6, CFrame = cf * CFrame.new(0, 6.4, 0), Color = Color3.fromRGB(190, 215, 255), Material = Enum.Material.Neon, Parent = parent })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(170, 200, 255)
	light.Range = 18
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = moon
end

local function rock(cf: CFrame, parent: Instance)
	if Assets.Place("Rock", cf, parent, { Width = 5 }) then
		return
	end
	Build.Part({ Size = Vector3.new(4.5, 2.6, 3.4), CFrame = cf * CFrame.new(0, 1, 0) * CFrame.Angles(0.15, 0.4, -0.1), Color = Color3.fromRGB(130, 132, 138), Material = Enum.Material.Slate, Parent = parent })
	Build.Part({ Size = Vector3.new(3.6, 0.4, 2.6), CFrame = cf * CFrame.new(0, 2.35, 0) * CFrame.Angles(0.15, 0.4, -0.1), Color = Color3.fromRGB(90, 150, 70), Material = Enum.Material.Grass, Parent = parent })
end

local function buildArt(decorId: string, cf: CFrame, parent: Instance, rng: Random)
	if decorId == "grass" then
		tufts(cf, parent, rng)
	elseif decorId == "path" then
		stones(cf, parent, rng)
	elseif decorId == "flowers" then
		Props.FlowerBed(cf, 6.4, parent, rng)
	elseif decorId == "bush" then
		Props.Bush(cf, parent, rng)
	elseif decorId == "rock" then
		rock(cf, parent)
	elseif decorId == "mailbox" then
		Props.Mailbox(cf, parent)
	elseif decorId == "bench" then
		Props.Bench(cf, parent)
	elseif decorId == "lamp" then
		Props.Lamp(cf, parent)
	elseif decorId == "scarecrow" then
		Props.Scarecrow(cf, parent)
	elseif decorId == "pond" then
		pond(cf, parent, rng)
	elseif decorId == "oak" then
		if not Assets.Place("Tree_Oak", cf, parent, { Height = 16 }) then
			Props.Oak(cf, parent, rng)
		end
	elseif decorId == "pine" then
		if not Assets.Place("Tree_Pine", cf, parent, { Height = 18 }) then
			Props.Pine(cf, parent, rng)
		end
	elseif decorId == "well" then
		Props.Well(cf, parent)
	elseif decorId == "fountain" then
		if not Assets.Place("Fountain", cf, parent, { Width = 7 }) then
			smallFountain(cf, parent)
		end
	elseif decorId == "statue" then
		statue(cf, parent)
	end
end

-- Walk-through and not clickable, so the garden stays easy to move around and prompts keep working
local function makeStatic(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
end

-- Show (or clear) the decoration on one tile: grass look + art, or plain soil again
local function applyTile(tile: BasePart, tileId: string, decorId: string?)
	local old = tile:FindFirstChild("Decor")
	if old then
		old:Destroy()
	end
	local soil = tile:GetAttribute("SoilColor")
	tile.Color = if decorId then GRASS else (if typeof(soil) == "Color3" then soil else tile.Color)
	tile.Material = if decorId then Enum.Material.Grass else Enum.Material.Ground
	for _, child in tile:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Ridge" then
			child.Transparency = if decorId then 1 else 0
		end
	end
	if not decorId then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Decor"
	local seed = seedOf(tileId)
	local turn = math.rad((seed % 4) * 90)
	local top = CFrame.new(tile.Position + Vector3.new(0, tile.Size.Y / 2, 0)) * CFrame.Angles(0, turn, 0)
	buildArt(decorId, top, model, Random.new(seed))
	makeStatic(model)
	model.Parent = tile
end

-- API -----------------------------------------------------------------------------------------------

-- Rebuild every decoration (after the farm tiles are rebuilt). Decorations on tiles that no
-- longer exist (smaller plot after a Rebirth) go back to storage.
function DecorService.RefreshAll(player: Player)
	local data = S.DataService.GetData(player)
	local plot = S.PlotService.GetPlot(player)
	if not data or not plot then
		return
	end
	ensure(data)
	local returned = 0
	for tileId, decorId in data.Plot.Decor do
		if not plot.TileParts[tileId] or not Decor.ById[decorId] or data.Crops[tileId] then
			data.Plot.Decor[tileId] = nil
			if Decor.ById[decorId] then
				data.Inventory.Decor[decorId] = (data.Inventory.Decor[decorId] or 0) + 1
				returned += 1
			end
		end
	end
	for tileId, tile in plot.TileParts do
		applyTile(tile, tileId, data.Plot.Decor[tileId])
	end
	returned += DecorService.RefreshGarden(player, data, plot)
	if returned > 0 then
		S.DataService.MarkChanged(player)
		notify(player, `{returned} decoration(s) went back to your storage. Place them again from the Garden menu.`)
	end
end

function DecorService.PickUp(player: Player, tileId: string)
	local data = S.DataService.GetData(player)
	local tile = S.PlotService.GetTilePart(player, tileId)
	if not data or not tile then
		return
	end
	ensure(data)
	local decorId = data.Plot.Decor[tileId]
	if not decorId then
		return
	end
	data.Plot.Decor[tileId] = nil
	data.Inventory.Decor[decorId] = (data.Inventory.Decor[decorId] or 0) + 1
	applyTile(tile, tileId, nil)
	S.CropService.RefreshAll(player)
	S.DataService.MarkChanged(player)
	local decor = Decor.ById[decorId]
	notify(player, `Picked up {if decor then decor.Name else "decoration"}. This tile is farm soil again.`)
end

-- Uses one from storage, or buys one. True when the player may place it now.
local function takeOne(player: Player, data: any, decor: Decor.Decor): boolean
	local owned = data.Inventory.Decor[decor.Id] or 0
	if owned > 0 then
		data.Inventory.Decor[decor.Id] = if owned > 1 then owned - 1 else nil
		return true
	end
	if data.GardenLevel < decor.MinLevel then
		notify(player, `{decor.Name} unlocks at Garden Level {decor.MinLevel}.`)
		return false
	end
	return S.EconomyService.Spend(player, { Coins = decor.Cost, Essence = decor.Essence })
end

local function inOwnGarden(player: Player): boolean
	local root = S.AntiExploit.GetRootPosition(player)
	if root and S.PlotService.IsInsideOwnerPlot(player, root) then
		return true
	end
	notify(player, "Go to your own garden to decorate.")
	return false
end

-- Grass build grid (shared/GardenGrid) ---------------------------------------------------------------

local function gardenFolder(plot: any): Instance
	local folder = plot.Model:FindFirstChild("Garden")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Garden"
		folder.Parent = plot.Model
	end
	return folder
end

local function buildCell(plot: any, cellId: string, entry: any)
	local i, j = GardenGrid.Parse(cellId)
	if not i or not j then
		return
	end
	local folder = gardenFolder(plot)
	local old = folder:FindFirstChild(cellId)
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = cellId
	local position = plot.Center + GardenGrid.Offset(i, j) + Vector3.new(0, 0.2, 0) -- top of the grass
	local cf = CFrame.new(position) * CFrame.Angles(0, math.rad(((entry.R or 0) % 4) * 90), 0)
	buildArt(entry.D, cf, model, Random.new(seedOf(cellId)))
	makeStatic(model)
	model.Parent = folder
end

-- Rebuild the grass decorations. Pieces that are now blocked (the farm grew over them) go back
-- to storage.
function DecorService.RefreshGarden(player: Player, data: any, plot: any): number
	local returned = 0
	for cellId, entry in data.Plot.Garden do
		local i, j = GardenGrid.Parse(cellId)
		local valid = type(entry) == "table" and Decor.ById[entry.D] ~= nil
		if not valid or not i or not j or GardenGrid.IsBlocked(i, j) or data.Plot.Soil[cellId] ~= nil then
			data.Plot.Garden[cellId] = nil
			if valid then
				data.Inventory.Decor[entry.D] = (data.Inventory.Decor[entry.D] or 0) + 1
				returned += 1
			end
		end
	end
	gardenFolder(plot):ClearAllChildren()
	for cellId, entry in data.Plot.Garden do
		buildCell(plot, cellId, entry)
	end
	return returned
end

function DecorService.CountGarden(data: any): number
	local count = 0
	for _ in (data.Plot.Garden or {}) do
		count += 1
	end
	return count
end

local function onPlaceDecorAt(player: Player, data: any, decorId: any, cellId: any, turns: any)
	if not S.AntiExploit.IsKeyOf(decorId, Decor.ById) or not S.AntiExploit.IsInteger(turns, 0, 3) then
		return
	end
	local i, j = GardenGrid.Parse(cellId)
	local plot = S.PlotService.GetPlot(player)
	if not i or not j or not plot or not inOwnGarden(player) then
		return
	end
	ensure(data)
	if data.Plot.Garden[cellId] then
		notify(player, "Something is already there. Use Remove first.")
		return
	end
	if data.Plot.Soil[cellId] then
		notify(player, "A soil tile is there. Remove it first (it must have no crop).")
		return
	end
	if GardenGrid.IsBlocked(i, j) then
		notify(player, "You can't build there (keep gates, paths and buildings clear).")
		return
	end
	if DecorService.CountGarden(data) >= Decor.MaxGardenPieces then
		notify(player, `Your garden is full ({Decor.MaxGardenPieces} decorations). Remove one first.`)
		return
	end
	local decor = Decor.ById[decorId]
	if not takeOne(player, data, decor) then
		return
	end
	local entry = { D = decorId, R = turns }
	data.Plot.Garden[cellId] = entry
	buildCell(plot, cellId, entry)
	S.DataService.MarkChanged(player)
end

-- target = a grass cellId or a decorated soil tileId
local function onRemoveDecor(player: Player, data: any, target: any)
	if not S.AntiExploit.IsString(target, 16) or not inOwnGarden(player) then
		return
	end
	ensure(data)
	local entry = data.Plot.Garden[target]
	if entry then
		data.Plot.Garden[target] = nil
		data.Inventory.Decor[entry.D] = (data.Inventory.Decor[entry.D] or 0) + 1
		local plot = S.PlotService.GetPlot(player)
		local model = plot and gardenFolder(plot):FindFirstChild(target)
		if model then
			model:Destroy()
		end
		S.DataService.MarkChanged(player)
		local decor = Decor.ById[entry.D]
		notify(player, `{if decor then decor.Name else "Decoration"} went back to storage.`)
	elseif data.Plot.Decor[target] then
		DecorService.PickUp(player, target)
	end
end

-- Build mode Move: a decoration or a soil tile goes from one square to a free one. Decorations
-- keep their look (turns = new facing); soil tiles take their growing crop with them.
local function onMoveItem(player: Player, data: any, fromId: any, toId: any, turns: any)
	local fi, fj = GardenGrid.Parse(fromId)
	local ti, tj = GardenGrid.Parse(toId)
	local plot = S.PlotService.GetPlot(player)
	if not fi or not fj or not ti or not tj or fromId == toId or not plot or not inOwnGarden(player) then
		return
	end
	if turns ~= nil and not S.AntiExploit.IsInteger(turns, 0, 3) then
		return
	end
	ensure(data)
	local garden, soil = data.Plot.Garden, data.Plot.Soil
	if garden[toId] or soil[toId] then
		notify(player, "That square is taken. Pick a green square.")
		return
	end
	if GardenGrid.IsBlocked(ti, tj) then
		notify(player, "You can't build there (keep gates, paths and buildings clear).")
		return
	end
	local entry = garden[fromId]
	if entry then
		garden[fromId] = nil
		local moved = { D = entry.D, R = if turns ~= nil then turns else entry.R }
		garden[toId] = moved
		local old = gardenFolder(plot):FindFirstChild(fromId)
		if old then
			old:Destroy()
		end
		buildCell(plot, toId, moved)
		S.DataService.MarkChanged(player)
	elseif soil[fromId] then
		soil[fromId] = nil
		soil[toId] = true
		if data.Crops[fromId] then
			data.Crops[toId] = data.Crops[fromId]
			data.Crops[fromId] = nil
		end
		S.PlotService.BuildTiles(player)
	end
end

-- Count of decorations on soil tiles (they use up farm land)
function DecorService.CountPlaced(data: any): number
	local count = 0
	for _ in (data.Plot.Decor or {}) do
		count += 1
	end
	return count
end

function DecorService.Init() end

function DecorService.Start()
	S.AntiExploit.Bind("PlaceDecorAt", onPlaceDecorAt)
	S.AntiExploit.Bind("RemoveDecor", onRemoveDecor)
	S.AntiExploit.Bind("MoveItem", onMoveItem)
end

return DecorService
