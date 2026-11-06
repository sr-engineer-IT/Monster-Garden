--!strict
-- CropArt: blocky "voxel" crops, a different look for every crop and three growth stages
-- (1 sprout, 2 growing, 3 ready). Small crops grow as a patch of 4 plants per soil tile, big crops
-- as one large plant. Moonlit crops glow blue. Parts are kept low for phones (about 4-14 per tile).
-- A real 3D model "Crop_<id>" in assets/models replaces the ready (stage 3) look automatically.

local Assets = require(script.Parent.Assets)
local Build = require(script.Parent.Build)

local CropArt = {}

local LEAF = Color3.fromRGB(86, 176, 62)
local LEAF_DARK = Color3.fromRGB(58, 138, 48)
local STEM = Color3.fromRGB(72, 150, 52)
local WOOD = Color3.fromRGB(130, 92, 58)
local MOONLIT = Color3.fromRGB(150, 205, 255)

type Ctx = { Model: Model, Top: CFrame, K: number, Moonlit: boolean, Rng: Random }

local function block(ctx: Ctx, size: Vector3, offset: Vector3, color: Color3, props: { [string]: any }?): Part
	local p: { [string]: any } = {
		Size = size * ctx.K,
		CFrame = ctx.Top * CFrame.new(offset * ctx.K),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Parent = ctx.Model,
	}
	for key, value in props or {} do
		p[key] = value
	end
	if p.Rotate then
		p.CFrame = p.CFrame * p.Rotate
		p.Rotate = nil
	end
	return Build.Part(p)
end

-- Fruit block: glows when the crop is Moonlit or naturally glowing
local function fruit(ctx: Ctx, size: Vector3, offset: Vector3, color: Color3, glowing: boolean?): Part
	local lit = ctx.Moonlit or glowing == true
	local part = block(ctx, size, offset, if ctx.Moonlit then MOONLIT else color, { Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic })
	return part
end

local function glow(part: BasePart, color: Color3, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 1.2
	light.Parent = part
end

-- Two crossed leaves (a little "V" of flat blocks)
local function leaves(ctx: Ctx, at: Vector3, height: number, color: Color3?)
	local c = color or LEAF
	block(ctx, Vector3.new(0.18, height, 0.5), at + Vector3.new(-0.15, height / 2, 0), c, { Rotate = CFrame.Angles(0, 0, math.rad(22)) })
	block(ctx, Vector3.new(0.18, height * 0.9, 0.5), at + Vector3.new(0.15, height * 0.45, 0), c, { Rotate = CFrame.Angles(0, math.rad(90), math.rad(-22)) })
end

local function sprout(ctx: Ctx, at: Vector3)
	leaves(ctx, at, 0.55, LEAF)
end

-- The 4 plant spots of a small-crop patch (relative to the tile center, unscaled studs)
local SPOTS = { Vector3.new(-1.3, 0, -1.3), Vector3.new(1.3, 0, -1.3), Vector3.new(-1.3, 0, 1.3), Vector3.new(1.3, 0, 1.3) }

-- Crop looks --------------------------------------------------------------------------------------

local function rootCrop(ctx: Ctx, stage: number, rootColor: Color3, tipColor: Color3, round: boolean)
	for _, at in SPOTS do
		if stage == 1 then
			sprout(ctx, at)
		else
			local grown = stage == 3
			local w = if grown then (if round then 0.75 else 0.6) else 0.4
			local h = if grown then (if round then 0.7 else 0.55) else 0.35
			fruit(ctx, Vector3.new(w, h, w), at + Vector3.new(0, h / 2, 0), rootColor)
			if round and grown then
				block(ctx, Vector3.new(0.2, 0.2, 0.2), at + Vector3.new(0, 0.05, 0), tipColor)
			end
			leaves(ctx, at + Vector3.new(0, h, 0), if grown then 0.9 else 0.6, LEAF)
		end
	end
end

local function tomato(ctx: Ctx, stage: number, color: Color3)
	if stage == 1 then
		sprout(ctx, Vector3.new(-1, 0, 0))
		sprout(ctx, Vector3.new(1, 0, 0))
		return
	end
	local h = if stage == 3 then 2.6 else 1.7
	block(ctx, Vector3.new(0.18, h + 0.4, 0.18), Vector3.new(0, (h + 0.4) / 2, 0), WOOD) -- stake
	block(ctx, Vector3.new(1.3, h * 0.55, 1.1), Vector3.new(0, h * 0.45, 0), LEAF_DARK)
	block(ctx, Vector3.new(1.0, h * 0.4, 1.3), Vector3.new(0.1, h * 0.75, 0), LEAF)
	if stage == 3 then
		for _, o in { Vector3.new(0.6, 1.0, -0.55), Vector3.new(-0.6, 1.5, -0.5), Vector3.new(0.55, 1.9, 0.5), Vector3.new(-0.55, 0.8, 0.55) } do
			fruit(ctx, Vector3.new(0.5, 0.5, 0.5), o, color)
		end
	else
		fruit(ctx, Vector3.new(0.35, 0.35, 0.35), Vector3.new(0.6, 0.9, -0.55), Color3.fromRGB(140, 200, 80))
	end
end

local function corn(ctx: Ctx, stage: number, color: Color3)
	for _, x in { -1.2, 1.2 } do
		local at = Vector3.new(x, 0, 0)
		if stage == 1 then
			sprout(ctx, at)
		else
			local h = if stage == 3 then 4.2 else 2.4
			block(ctx, Vector3.new(0.28, h, 0.28), at + Vector3.new(0, h / 2, 0), STEM)
			block(ctx, Vector3.new(0.14, h * 0.45, 0.6), at + Vector3.new(0.35, h * 0.45, 0), LEAF, { Rotate = CFrame.Angles(0, 0, math.rad(-35)) })
			block(ctx, Vector3.new(0.14, h * 0.4, 0.6), at + Vector3.new(-0.35, h * 0.65, 0), LEAF, { Rotate = CFrame.Angles(0, 0, math.rad(35)) })
			if stage == 3 then
				fruit(ctx, Vector3.new(0.42, 1.0, 0.42), at + Vector3.new(0.3, h * 0.58, 0.2), color)
				block(ctx, Vector3.new(0.12, 0.5, 0.12), at + Vector3.new(0, h + 0.2, 0), Color3.fromRGB(220, 190, 110))
			end
		end
	end
end

local function pumpkin(ctx: Ctx, stage: number, color: Color3)
	if stage == 1 then
		sprout(ctx, Vector3.zero)
		return
	end
	block(ctx, Vector3.new(2.6, 0.25, 0.5), Vector3.new(0, 0.12, 1.2), LEAF_DARK, { Rotate = CFrame.Angles(0, math.rad(20), 0) }) -- vine
	block(ctx, Vector3.new(1.0, 0.3, 1.0), Vector3.new(-1.3, 0.15, 1.1), LEAF)
	if stage == 2 then
		fruit(ctx, Vector3.new(1.0, 0.7, 1.0), Vector3.new(0, 0.35, 0), Color3.fromRGB(150, 190, 70))
		return
	end
	local body = fruit(ctx, Vector3.new(2.2, 1.5, 2.2), Vector3.new(0, 0.75, 0), color)
	for _, x in { -0.75, 0, 0.75 } do -- ribs
		block(ctx, Vector3.new(0.2, 1.52, 2.24), Vector3.new(x, 0.75, 0), body.Color:Lerp(Color3.new(0, 0, 0), 0.18), { Material = body.Material })
	end
	block(ctx, Vector3.new(0.28, 0.5, 0.28), Vector3.new(0.1, 1.7, 0), Color3.fromRGB(100, 120, 50))
end

local function berryBush(ctx: Ctx, stage: number, color: Color3, glowing: boolean)
	if stage == 1 then
		sprout(ctx, Vector3.new(-0.8, 0, 0))
		sprout(ctx, Vector3.new(0.8, 0, 0.4))
		return
	end
	local s = if stage == 3 then 1 else 0.7
	block(ctx, Vector3.new(2.2 * s, 1.4 * s, 2.0 * s), Vector3.new(0, 0.7 * s, 0), LEAF_DARK)
	block(ctx, Vector3.new(1.6 * s, 0.9 * s, 1.6 * s), Vector3.new(0.2, 1.5 * s, -0.1), LEAF)
	if stage == 3 then
		local lit
		for _, o in { Vector3.new(0.9, 0.9, -0.9), Vector3.new(-0.9, 1.2, -0.7), Vector3.new(0.7, 1.7, 0.6), Vector3.new(-0.6, 0.6, 0.95), Vector3.new(0.1, 2.0, 0) } do
			lit = fruit(ctx, Vector3.new(0.42, 0.42, 0.42), o, color, glowing)
		end
		if (glowing or ctx.Moonlit) and lit then
			glow(lit, if ctx.Moonlit then MOONLIT else color, 10)
		end
	end
end

local function starfruit(ctx: Ctx, stage: number, color: Color3)
	if stage == 1 then
		sprout(ctx, Vector3.zero)
		return
	end
	local h = if stage == 3 then 2.8 else 1.8
	block(ctx, Vector3.new(0.35, h, 0.35), Vector3.new(0, h / 2, 0), WOOD)
	block(ctx, Vector3.new(2.4, 1.0, 2.4), Vector3.new(0, h + 0.3, 0), LEAF)
	block(ctx, Vector3.new(1.6, 0.6, 1.6), Vector3.new(0, h + 1.0, 0), LEAF_DARK)
	if stage == 3 then
		for _, o in { Vector3.new(1.1, h - 0.15, 0.6), Vector3.new(-1.0, h - 0.1, -0.7) } do
			local a = fruit(ctx, Vector3.new(0.7, 0.18, 0.18), o, color)
			fruit(ctx, Vector3.new(0.18, 0.18, 0.7), o, color)
			fruit(ctx, Vector3.new(0.5, 0.18, 0.18), o, color, nil).CFrame = a.CFrame * CFrame.Angles(0, math.rad(45), 0)
		end
	end
end

local function melon(ctx: Ctx, stage: number, color: Color3)
	if stage == 1 then
		sprout(ctx, Vector3.zero)
		return
	end
	block(ctx, Vector3.new(2.4, 0.25, 0.5), Vector3.new(0, 0.12, -1.2), LEAF_DARK, { Rotate = CFrame.Angles(0, math.rad(-15), 0) })
	local size = if stage == 3 then Vector3.new(2.4, 1.4, 1.6) else Vector3.new(1.2, 0.8, 0.9)
	local body = fruit(ctx, size, Vector3.new(0, size.Y / 2, 0.2), color, stage == 3)
	if stage == 3 then
		for _, x in { -0.7, 0.1, 0.9 } do
			block(ctx, Vector3.new(0.18, 1.42, 1.62), Vector3.new(x, 0.7, 0.2), color:Lerp(Color3.new(0, 0, 0.2), 0.35), { Material = body.Material })
		end
		glow(body, if ctx.Moonlit then MOONLIT else color, 12)
	end
end

local LOOKS: { [string]: (Ctx, number, any) -> () } = {
	carrot = function(ctx, stage, crop) rootCrop(ctx, stage, crop.Color, crop.Color, false) end,
	radish = function(ctx, stage, crop) rootCrop(ctx, stage, crop.Color, Color3.fromRGB(245, 240, 240), true) end,
	tomato = function(ctx, stage, crop) tomato(ctx, stage, crop.Color) end,
	corn = function(ctx, stage, crop) corn(ctx, stage, crop.Color) end,
	pumpkin = function(ctx, stage, crop) pumpkin(ctx, stage, crop.Color) end,
	glowberry = function(ctx, stage, crop) berryBush(ctx, stage, crop.Color, true) end,
	lureberry = function(ctx, stage, crop) berryBush(ctx, stage, crop.Color, true) end,
	starfruit = function(ctx, stage, crop) starfruit(ctx, stage, crop.Color) end,
	moonmelon = function(ctx, stage, crop) melon(ctx, stage, crop.Color) end,
}

-- Builds the crop model on a soil tile. stage: 1 sprout, 2 growing, 3 ready.
function CropArt.Build(tile: BasePart, crop: any, stage: number, moonlit: boolean): Model
	local model = Instance.new("Model")
	model.Name = "Crop"
	local top = CFrame.new(tile.Position + Vector3.new(0, tile.Size.Y / 2, 0))
	local k = tile.Size.X / 7.4 -- art is designed for an 8-stud tile

	-- Real 3D model for ready crops, if one is saved as Crop_<id>
	if stage == 3 and Assets.Has(`Crop_{crop.Id}`) then
		local art = Assets.Place(`Crop_{crop.Id}`, top, model, { Width = tile.Size.X * 0.8 })
		if art and moonlit then
			local h = Instance.new("Highlight")
			h.FillColor = MOONLIT
			h.FillTransparency = 0.6
			h.OutlineTransparency = 1
			h.Parent = art
		end
		model.Parent = tile
		return model
	end

	local ctx: Ctx = { Model = model, Top = top, K = k, Moonlit = moonlit, Rng = Random.new() }
	local look = LOOKS[crop.Id]
	if look then
		look(ctx, stage, crop)
	else
		rootCrop(ctx, stage, crop.Color, crop.Color, true) -- unknown crop: generic patch
	end
	-- Ready crops sparkle a little so players spot them
	if stage == 3 then
		local first = model:FindFirstChildWhichIsA("BasePart")
		if first then
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			sparkle.Color = ColorSequence.new(if moonlit then MOONLIT else Color3.fromRGB(255, 245, 180))
			sparkle.Size = NumberSequence.new(0.35, 0)
			sparkle.Lifetime = NumberRange.new(0.8, 1.2)
			sparkle.Rate = 1.5
			sparkle.Speed = NumberRange.new(0.5, 1)
			sparkle.SpreadAngle = Vector2.new(180, 180)
			sparkle.LightEmission = 1
			sparkle.Parent = first
		end
	end
	if moonlit and stage == 3 then
		local first = model:FindFirstChildWhichIsA("BasePart")
		if first and not first:FindFirstChildOfClass("PointLight") then
			glow(first, MOONLIT, 8)
		end
	end
	model.Parent = tile
	return model
end

-- Short burst of particles at a tile (water splash, harvest pop). Server-side, replicates.
function CropArt.Burst(tile: BasePart, kind: string)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, tile.Size.Y / 2 + 0.6, 0)
	attachment.Parent = tile
	local emitter = Instance.new("ParticleEmitter")
	if kind == "Water" then
		emitter.Color = ColorSequence.new(Color3.fromRGB(120, 190, 255))
		emitter.Size = NumberSequence.new(0.35, 0.1)
		emitter.Transparency = NumberSequence.new(0.1, 1)
		emitter.Lifetime = NumberRange.new(0.5, 0.8)
		emitter.Speed = NumberRange.new(6, 9)
		emitter.SpreadAngle = Vector2.new(35, 35)
		emitter.Acceleration = Vector3.new(0, -30, 0)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Rate = 70
	else -- Harvest
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 235, 120))
		emitter.Size = NumberSequence.new(0.6, 0)
		emitter.Transparency = NumberSequence.new(0, 1)
		emitter.Lifetime = NumberRange.new(0.5, 0.8)
		emitter.Speed = NumberRange.new(5, 8)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.LightEmission = 1
		emitter.Rate = 80
	end
	emitter.Parent = attachment
	task.delay(0.25, function()
		emitter.Enabled = false
	end)
	task.delay(1.5, function()
		attachment:Destroy()
	end)
end

return CropArt
