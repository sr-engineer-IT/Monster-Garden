--!strict
-- The build grid on a garden's grass (shared by server and client so both agree which squares
-- are free). Squares are CellSize studs, centered on the plot center: cell (i, j) sits at
-- plot.Center + (i * CellSize, 0, j * CellSize), for i, j in -Range..Range.
-- Soil tiles (data.Plot.Soil) and decorations (data.Plot.Garden) both sit on these squares, so a
-- player can lay out the farm anywhere. A square is blocked when it is a gate lane or building spot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Config"))

local WORLD = Config.World

local GardenGrid = {}

GardenGrid.CellSize = 8
GardenGrid.Range = 7 -- 15 x 15 squares; the outer ring by the fence stays free for walking
GardenGrid.LaneStart = 42 -- gate lanes are kept clear from here out to the fence

-- Spots that must stay clear (offset from the plot center, radius in studs)
local reserved: { { Offset: Vector3, Radius: number } } = {
	{ Offset = WORLD.MerchantOffset, Radius = 9 },
	{ Offset = WORLD.UpgradeStationOffset, Radius = 7 },
	{ Offset = WORLD.StallOffset, Radius = 8 },
	{ Offset = WORLD.PenOffset, Radius = 12 },
	{ Offset = WORLD.TowerSpot, Radius = 8 },
	{ Offset = WORLD.ShelterSpot, Radius = 9 },
	{ Offset = WORLD.SpiritGateOffset, Radius = 9 },
	{ Offset = WORLD.CreatureHome, Radius = 7 },
	{ Offset = WORLD.SpawnOffset, Radius = 6 },
}
for _, list in { WORLD.NestSpots, WORLD.LanternPosts, WORLD.TrapSpots } do
	for _, offset in list do
		table.insert(reserved, { Offset = offset, Radius = 5 })
	end
end

function GardenGrid.CellId(i: number, j: number): string
	return `g{i}_{j}`
end

function GardenGrid.Parse(cellId: any): (number?, number?)
	if type(cellId) ~= "string" or #cellId > 12 then
		return nil, nil
	end
	local a, b = string.match(cellId, "^g(%-?%d+)_(%-?%d+)$")
	local i, j = tonumber(a), tonumber(b)
	if not i or not j or math.abs(i) > GardenGrid.Range or math.abs(j) > GardenGrid.Range then
		return nil, nil
	end
	return i, j
end

function GardenGrid.Offset(i: number, j: number): Vector3
	return Vector3.new(i * GardenGrid.CellSize, 0, j * GardenGrid.CellSize)
end

-- Cell under a flat offset from the plot center (or nil outside the grid)
function GardenGrid.CellAt(offset: Vector3): (number?, number?)
	local i = math.floor(offset.X / GardenGrid.CellSize + 0.5)
	local j = math.floor(offset.Z / GardenGrid.CellSize + 0.5)
	if math.abs(i) > GardenGrid.Range or math.abs(j) > GardenGrid.Range then
		return nil, nil
	end
	return i, j
end

-- True when nothing may ever be built on this square (soil or decoration): the gate lanes and
-- their paths near the fence, and every building spot. What is already placed is checked separately.
function GardenGrid.IsBlocked(i: number, j: number): boolean
	local half = GardenGrid.CellSize / 2
	local p = GardenGrid.Offset(i, j)
	-- gate lanes: the paths from each gate in to the middle of the garden (PlotService draws them
	-- from LaneStart out to the fence)
	local lane = WORLD.GateWidth / 2 + 1
	if (math.abs(p.X) < lane and math.abs(p.Z) > GardenGrid.LaneStart) or (math.abs(p.Z) < lane and math.abs(p.X) > GardenGrid.LaneStart) then
		return true
	end
	for _, spot in reserved do
		local dx, dz = spot.Offset.X - p.X, spot.Offset.Z - p.Z
		if math.sqrt(dx * dx + dz * dz) < spot.Radius + half - 1 then
			return true
		end
	end
	return false
end

-- Soil tiles a player may place: the plot size they bought (Config.PlotSizes) plus the Extra Plot pass
function GardenGrid.SoilAllowance(data: any): number
	local size = Config.PlotSizes[data.Plot.SizeIndex] or Config.PlotSizes[1]
	local total = size.Width * size.Depth
	local passes = data.Purchases and data.Purchases.PassesOwned
	if passes and passes.pass_plot then
		total += Config.ExtraPlotPassTiles
	end
	return total
end

function GardenGrid.CountSoil(data: any): number
	local count = 0
	for _ in (data.Plot and data.Plot.Soil) or {} do
		count += 1
	end
	return count
end

-- Squares of the classic centered farm (width x depth tiles) for a plot size: where new players'
-- tiles go, and where the old fixed farm maps to
function GardenGrid.ClassicOffsets(width: number, depth: number): { Vector3 }
	local list = {}
	local tile = Config.TileSizeStuds
	for x = 0, width - 1 do
		for z = 0, depth - 1 do
			table.insert(list, Vector3.new((x - (width - 1) / 2) * tile, 0, (z - (depth - 1) / 2) * tile))
		end
	end
	return list
end

-- Free square closest to (i0, j0) (ring by ring, then by straight distance), or nil when full
function GardenGrid.NearestFree(i0: number, j0: number, isFree: (number, number) -> boolean): (number?, number?)
	local range = GardenGrid.Range
	for r = 0, range * 2 do
		local bestI, bestJ, best = nil, nil, math.huge
		for i = i0 - r, i0 + r do
			for j = j0 - r, j0 + r do
				if math.max(math.abs(i - i0), math.abs(j - j0)) == r and math.abs(i) <= range and math.abs(j) <= range and isFree(i, j) then
					local d = (i - i0) ^ 2 + (j - j0) ^ 2
					if d < best then
						bestI, bestJ, best = i, j, d
					end
				end
			end
		end
		if bestI then
			return bestI, bestJ
		end
	end
	return nil, nil
end

return GardenGrid
