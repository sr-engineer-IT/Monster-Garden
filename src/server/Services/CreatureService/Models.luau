--!strict
-- Placeholder creature models built from parts. Size follows life stage and Giant Size;
-- mutations, recolor tokens and equipped glows change the look only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Creatures = require(ConfigFolder:WaitForChild("Creatures"))
local Products = require(ConfigFolder:WaitForChild("Products"))
local GameMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameMath"))

local Build = require(script.Parent.Parent.Parent.Build)
local Assets = require(script.Parent.Parent.Parent.Assets)
local Rig = require(script.Parent.Parent.Parent.Rig)

export type Parts = {
	Model: Model,
	Body: BasePart,
	Size: number,
	Footprint: number, -- half the width of what you see (model or shapes), for spacing
	Status: TextLabel,
	FedBar: Frame,
	PetPrompt: ProximityPrompt,
	FeedPrompt: ProximityPrompt,
}

local Models = {}

local MOONLIT_GLOW = Color3.fromRGB(170, 210, 255)
local SHADOW_GLOW = Color3.fromRGB(90, 40, 140)
local STAGE_SCALE = { Baby = 0.55, Young = 0.8, Adult = 1, Elder = 1 }

local function has(list: { string }?, id: string): boolean
	return list ~= nil and table.find(list, id) ~= nil
end

function Models.Size(creature: any): number
	local look = Creatures.Looks[creature.Species] or Creatures.Looks.rabbit
	local size = look.Size * (STAGE_SCALE[creature.Stage] or 1)
	if has(creature.Powers, "GiantSize") then
		size *= 1 + Config.Breeding.GiantSizeScale
	end
	return size
end

local function cosmeticColor(id: string?): Color3?
	if id == nil then
		return nil
	end
	local cosmetic = Products.CosmeticById[id] or (Products.PassCosmetics :: any)[id]
	return cosmetic and cosmetic.Color
end

function Models.Build(creature: any, equippedGlow: string?): Parts
	local look = Creatures.Looks[creature.Species] or Creatures.Looks.rabbit
	local size = Models.Size(creature)
	local moonlit = has(creature.Mutations, "Moonlit")
	local shadow = has(creature.Mutations, "Shadow")
	local nightVision = has(creature.Mutations, "NightVision") or has(creature.Powers, "NightVision")
	local bodyColor = Creatures.RecolorPalette[creature.ColorIndex or 0] or look.Body
	if creature.Stage == "Elder" then
		bodyColor = bodyColor:Lerp(Color3.fromRGB(200, 200, 200), 0.35)
	end

	local model = Instance.new("Model")
	model.Name = creature.Id
	local body = Build.Ball({
		Name = "Body",
		Size = Vector3.one * size,
		Position = Vector3.zero,
		Color = if shadow then SHADOW_GLOW elseif moonlit then MOONLIT_GLOW else bodyColor,
		Material = if moonlit or shadow then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		Parent = model,
	})
	local headPos = Vector3.new(0, size * 0.45, -size * 0.4)
	Build.Ball({ Size = Vector3.one * size * 0.7, Position = headPos, Color = bodyColor, Parent = model })
	local eyeColor = if nightVision then Color3.fromRGB(120, 255, 120) else Color3.fromRGB(20, 20, 20)
	for _, side in { -1, 1 } do
		Build.Ball({ Size = Vector3.one * size * 0.14, Position = headPos + Vector3.new(side * size * 0.15, size * 0.08, -size * 0.32), Color = eyeColor, Material = if nightVision then Enum.Material.Neon else Enum.Material.SmoothPlastic, Parent = model })
		if look.Ears then
			Build.Part({ Size = Vector3.new(size * 0.15, size * 0.55, size * 0.1), Position = headPos + Vector3.new(side * size * 0.15, size * 0.5, 0), Color = look.Accent, Parent = model })
		end
	end
	if not look.Ears then
		Build.Ball({ Size = Vector3.one * size * 0.25, Position = headPos + Vector3.new(0, size * 0.38, 0), Color = look.Accent, Parent = model })
	end
	if has(creature.Mutations, "Escaped") then
		-- Scar look
		Build.Part({ Size = Vector3.new(size * 0.05, size * 0.3, size * 0.05), CFrame = CFrame.new(headPos + Vector3.new(size * 0.2, 0, -size * 0.3)) * CFrame.Angles(0, 0, math.rad(30)), Color = Color3.fromRGB(200, 90, 90), Parent = model })
	end

	local glow = cosmeticColor(equippedGlow) or (if moonlit then MOONLIT_GLOW elseif shadow then SHADOW_GLOW else nil)
	if has(creature.Mutations, "Eclipse") then
		-- super-rare: dark purple-gold glow with sparkles
		glow = Color3.fromRGB(180, 90, 255)
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 210, 90)
		sparkles.Parent = body
	elseif has(creature.Mutations, "Celestial") then
		-- super-rare: bright white-gold glow with sparkles
		glow = Color3.fromRGB(255, 250, 210)
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 255, 255)
		sparkles.Parent = body
	elseif has(creature.Mutations, "StarTouched") or has(creature.Mutations, "HungerBlessed") then
		glow = Color3.fromRGB(255, 230, 120)
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = glow
		sparkles.Parent = body
	end
	if glow then
		local light = Instance.new("PointLight")
		light.Color = glow
		light.Range = 10
		light.Parent = body
	end
	model.PrimaryPart = body

	-- Real 3D model (assets/models/Creature_<species>.rbxm) replaces the shapes if present
	local art = Assets.Dress(model, `Creature_{creature.Species}`, body, { Height = size * 1.25, Query = false, AlignLength = true })
	local footprint = size * 0.6
	if art then
		local _, artSize = Assets.Bounds(art)
		footprint = math.max(artSize.X, artSize.Z) * 0.5
	end
	if art then
		local tint = if shadow then SHADOW_GLOW elseif moonlit then MOONLIT_GLOW else glow
		if tint then
			local highlight = Instance.new("Highlight")
			highlight.FillColor = tint
			highlight.FillTransparency = 0.6
			highlight.OutlineColor = tint
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.Parent = art
		end
	end

	local gui = Build.Billboard(body, 170, 50, size * 0.6 + 1.8)
	-- Sized in studs (not screen pixels) so tags stay small and never cover the player
	gui.Size = UDim2.fromScale(5.5, 1.6)
	gui.MaxDistance = 50
	local stars = string.rep("*", #(creature.Mutations or {}))
	local stageText = if creature.Stage ~= "Adult" then ` ({creature.Stage})` else ""
	Build.Label(gui, `{GameMath.CreatureName(creature)}{stageText} {stars}`, { Size = UDim2.fromScale(1, 0.46) })
	local fedBar = Build.Bar(gui, Color3.fromRGB(110, 220, 90), UDim2.fromScale(0.15, 0.5), UDim2.fromScale(0.7, 0.12))
	local status = Build.Label(gui, "", { Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.68), TextColor3 = Color3.fromRGB(255, 220, 140) })

	local petPrompt = Build.Prompt(body, "Pet", GameMath.CreatureName(creature), { Distance = 6 })
	local feedPrompt = Build.Prompt(body, "Feed", "", { Distance = 6 })
	feedPrompt.KeyboardKeyCode = Enum.KeyCode.R -- different key so it shows next to Pet

	-- Smooth hop / idle animation on each player's screen (see Rig.luau, AnimationController)
	Rig.Attach(model, body, "Creature")

	return {
		Model = model,
		Body = body,
		Size = size,
		Footprint = footprint,
		Status = status,
		FedBar = fedBar,
		PetPrompt = petPrompt,
		FeedPrompt = feedPrompt,
	}
end

return Models
