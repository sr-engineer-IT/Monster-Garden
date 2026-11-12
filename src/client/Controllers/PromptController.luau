--!strict
-- Shows prompts only where they apply: prompts inside a garden show for its owner (or for everyone
-- when marked Public, like shop stalls and Heist Pens); prompts the server marked Hidden stay off.
-- Soil tiles: only the tile you are standing on (or the closest one) shows its prompt, so E always
-- plants, waters or harvests the tile under you, not the one the camera happens to face.
-- This is display only: the server checks every trigger anyway.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local PromptController = {}

local tilePrompts: { [ProximityPrompt]: BasePart } = {}
local nearestTile: ProximityPrompt? = nil
local creaturePrompts: { [ProximityPrompt]: boolean } = {}
local tileBusy = false -- the nearest soil tile has an action (plant / water / harvest)

local TILE_REACH = 7 -- studs (flat distance from tile center) at which a tile can be chosen

local function plotOf(instance: Instance): Instance?
	local current = instance.Parent
	while current and current ~= Workspace do
		if current:GetAttribute("PlotIndex") ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function isTilePrompt(prompt: ProximityPrompt): boolean
	local parent = prompt.Parent
	return parent ~= nil and parent:IsA("BasePart") and parent:GetAttribute("TileId") ~= nil
end

local function update(prompt: ProximityPrompt)
	local plot = plotOf(prompt)
	local allowed = true
	if plot and prompt:GetAttribute("Public") ~= true then
		allowed = plot:GetAttribute("OwnerUserId") == player.UserId
	end
	if tilePrompts[prompt] then
		allowed = allowed and prompt == nearestTile
	end
	if prompt:GetAttribute("CreaturePrompt") == true then
		creaturePrompts[prompt] = true
		-- Pet uses E too: while a tile can be worked, E belongs to the soil
		allowed = allowed and not tileBusy
	end
	prompt.Enabled = allowed and prompt:GetAttribute("Hidden") ~= true
end

local function watch(prompt: ProximityPrompt)
	if isTilePrompt(prompt) then
		tilePrompts[prompt] = prompt.Parent :: BasePart
		prompt.Destroying:Connect(function()
			tilePrompts[prompt] = nil
			if nearestTile == prompt then
				nearestTile = nil
			end
		end)
	end
	prompt.Destroying:Connect(function()
		creaturePrompts[prompt] = nil
	end)
	prompt:GetAttributeChangedSignal("CreaturePrompt"):Connect(function()
		update(prompt)
	end)
	prompt:GetAttributeChangedSignal("Hidden"):Connect(function()
		update(prompt)
	end)
	prompt:GetAttributeChangedSignal("Public"):Connect(function()
		update(prompt)
	end)
	update(prompt)
end

-- Pick the tile under (or closest to) the character, by flat distance to the tile center
local function pickNearestTile()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local best: ProximityPrompt? = nil
	if root and root:IsA("BasePart") then
		local pos = root.Position
		local bestDistance = TILE_REACH
		for prompt, tile in tilePrompts do
			local offset = tile.Position - pos
			local flat = math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
			if flat < bestDistance and math.abs(offset.Y) < 8 then
				best, bestDistance = prompt, flat
			end
		end
	end
	if best ~= nearestTile then
		local old = nearestTile
		nearestTile = best
		if old and old.Parent then
			update(old)
		end
		if best then
			update(best)
		end
	end
	local busy = best ~= nil and best:GetAttribute("Hidden") ~= true
	if busy ~= tileBusy then
		tileBusy = busy
		for prompt in creaturePrompts do
			update(prompt)
		end
	end
end

function PromptController.Start()
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			watch(descendant)
		end
	end
	Workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			watch(descendant)
		end
	end)
	local plots = Workspace:WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			for _, descendant in plot:GetDescendants() do
				if descendant:IsA("ProximityPrompt") then
					update(descendant)
				end
			end
		end)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.1 then
			elapsed = 0
			pickNearestTile()
		end
	end)
end

return PromptController
