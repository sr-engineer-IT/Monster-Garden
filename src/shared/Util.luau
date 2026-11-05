--!strict
-- Small pure helpers shared by server and client.

local HttpService = game:GetService("HttpService")

local Util = {}

function Util.DeepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[Util.DeepCopy(k)] = Util.DeepCopy(v)
	end
	return copy :: any
end

function Util.Clamp(value: number, min: number, max: number): number
	return math.max(min, math.min(max, value))
end

function Util.Round(value: number): number
	return math.floor(value + 0.5)
end

-- Inclusive random integer using the given Random (or a shared one)
local sharedRandom = Random.new()
function Util.RandomInt(min: number, max: number, rng: Random?): number
	return (rng or sharedRandom):NextInteger(min, max)
end

function Util.Chance(probability: number, rng: Random?): boolean
	return (rng or sharedRandom):NextNumber() < probability
end

-- Pick a key from { [key] = weight }. Returns nil when all weights are 0.
function Util.WeightedPick<K>(weights: { [K]: number }, rng: Random?): K?
	local total = 0
	for _, weight in weights do
		total += math.max(weight, 0)
	end
	if total <= 0 then
		return nil
	end
	local roll = (rng or sharedRandom):NextNumber() * total
	for key, weight in weights do
		roll -= math.max(weight, 0)
		if roll <= 0 then
			return key
		end
	end
	return nil
end

function Util.NewId(): string
	return HttpService:GenerateGUID(false)
end

function Util.CountKeys(t: { [any]: any }): number
	local count = 0
	for _ in t do
		count += 1
	end
	return count
end

-- Day number used for daily caps and login gifts (UTC days)
function Util.DayNumber(timestamp: number?): number
	return (timestamp or os.time()) // 86400
end

-- 1234567 -> "1.2M"
function Util.FormatNumber(n: number): string
	local abs = math.abs(n)
	if abs >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif abs >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif abs >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

function Util.TileId(x: number, z: number): string
	return `{x}_{z}`
end

function Util.ParseTileId(tileId: string): (number?, number?)
	local x, z = string.match(tileId, "^(%-?%d+)_(%-?%d+)$")
	return tonumber(x), tonumber(z)
end

return Util
