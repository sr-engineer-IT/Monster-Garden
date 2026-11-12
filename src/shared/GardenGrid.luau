--!strict
-- The build grid on a garden's grass (shared by server and client so both agree which squares
-- are free). Squares are CellSize studs, centered on the plot center: cell (i, j) sits at
-- plot.Center + (i * CellSize, 0, j * CellSize), for i, j in -Range..Range.
-- A square is blocked when it is near a soil tile, a building spot, a gate lane or the fence.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Config"))

local WORLD = Config.World

local GardenGrid = {}

GardenGrid.CellSize = 8
GardenGrid.Range = 7 -- 15 x 15 squares; the outer ring by the fence stays free for walking

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

-- tileOffsets: offsets (from the plot center) of every soil tile in this garden
function GardenGrid.IsBlocked(i: number, j: number, tileOffsets: { Vector3 }): boolean
	local half = GardenGrid.CellSize / 2
	local p = GardenGrid.Offset(i, j)
	-- gate lanes and the paths from each gate (a cross through the middle)
	local lane = WORLD.GateWidth / 2 + 1
	if math.abs(p.X) < lane or math.abs(p.Z) < lane then
		return true
	end
	-- soil tiles (with a 1-stud walkway around the farm)
	local tileReach = Config.TileSizeStuds / 2 + half + 1
	for _, t in tileOffsets do
		if math.abs(t.X - p.X) < tileReach and math.abs(t.Z - p.Z) < tileReach then
			return true
		end
	end
	for _, spot in reserved do
		local dx, dz = spot.Offset.X - p.X, spot.Offset.Z - p.Z
		if math.sqrt(dx * dx + dz * dz) < spot.Radius + half - 1 then
			return true
		end
	end
	return false
end

return GardenGrid
