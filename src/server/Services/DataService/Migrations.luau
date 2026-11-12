--!strict
-- Profile schema migrations. Steps[n] upgrades a profile from version n to n + 1.
-- Example for a future bump to version 2:
--   Steps[1] = function(data) data.NewField = data.OldField; data.OldField = nil end
-- Reconcile() runs after migration, so purely new fields need no step.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local GardenGrid = require(Shared:WaitForChild("GardenGrid"))
local Util = require(Shared:WaitForChild("Util"))
local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Config"))

local Migrations = {}

Migrations.Steps = {} :: { [number]: (data: any) -> () }

-- v2 -> v3: the farm is no longer a fixed square. Every old soil tile (the WxD square for the
-- plot size, plus the Extra Plot pass strip) becomes a placed soil tile on the build grid at the
-- same spot, keeping its crop. Decorations that sat on soil tiles move to that grass square.
Migrations.Steps[2] = function(data: any)
	local plot = data.Plot
	plot.Soil = plot.Soil or {}
	plot.Garden = plot.Garden or {}
	data.Inventory.Decor = data.Inventory.Decor or {}
	local oldDecor = plot.Decor or {}
	plot.Decor = {}
	local crops = data.Crops or {}
	data.Crops = {}

	local size = Config.PlotSizes[plot.SizeIndex] or Config.PlotSizes[1]
	local old: { { Id: string, Offset: Vector3 } } = {}
	for x = 0, size.Width - 1 do
		for z = 0, size.Depth - 1 do
			table.insert(old, { Id = Util.TileId(x, z), Offset = Vector3.new((x - (size.Width - 1) / 2) * Config.TileSizeStuds, 0, (z - (size.Depth - 1) / 2) * Config.TileSizeStuds) })
		end
	end
	local passes = data.Purchases and data.Purchases.PassesOwned
	if passes and passes.pass_plot then
		local world = Config.World
		for i = 0, world.ExtraPlotColumns - 1 do
			for j = 0, world.ExtraPlotRows - 1 do
				table.insert(old, { Id = `e{i}_{j}`, Offset = world.ExtraPlotOrigin + Vector3.new(i * Config.TileSizeStuds, 0, -j * Config.TileSizeStuds) })
			end
		end
	end

	local function isFree(i: number, j: number): boolean
		local id = GardenGrid.CellId(i, j)
		return not GardenGrid.IsBlocked(i, j) and not plot.Soil[id] and not plot.Garden[id]
	end
	for _, tile in old do
		local i, j = GardenGrid.CellAt(tile.Offset)
		if not i or not j or not isFree(i, j) then
			i, j = GardenGrid.NearestFree(i or 0, j or 0, isFree)
		end
		local decorId = oldDecor[tile.Id]
		if i and j then
			local id = GardenGrid.CellId(i, j)
			if decorId then
				plot.Garden[id] = { D = decorId, R = 0 }
			else
				plot.Soil[id] = true
				if crops[tile.Id] then
					data.Crops[id] = crops[tile.Id]
				end
			end
		elseif decorId then
			data.Inventory.Decor[decorId] = (data.Inventory.Decor[decorId] or 0) + 1
		end
	end
	plot.SoilReady = true
end

-- v1 -> v2: life stages now come from age. Creatures saved as Adults with age 0 start at adult age.
Migrations.Steps[1] = function(data: any)
	for _, creature in data.Creatures or {} do
		if creature.Stage == "Adult" and (creature.AgeMinutes or 0) == 0 then
			creature.AgeMinutes = GameMath.StageStartMinutes(creature, "Adult")
		end
	end
end

-- Returns false when the profile cannot be used by this server version.
function Migrations.Migrate(data: any, targetVersion: number): (boolean, string?)
	local version = if type(data.SchemaVersion) == "number" then data.SchemaVersion else 1

	if version > targetVersion then
		-- Saved by a newer server; an old server must not touch it
		return false, `profile version {version} is newer than server version {targetVersion}`
	end

	while version < targetVersion do
		local step = Migrations.Steps[version]
		if not step then
			return false, `missing migration step from version {version}`
		end
		step(data)
		version += 1
		data.SchemaVersion = version
	end

	return true, nil
end

return Migrations
