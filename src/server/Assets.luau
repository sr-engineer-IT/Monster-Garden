--!strict
-- Model loader: lets real 3D models replace the code-built placeholder shapes without any code.
--
-- How to add a model:
--   1. In Studio, select your model, right-click > Save to File... and save it as
--      E:\Monster-Garden\assets\models\<Name>.rbxm   (the file name is the model name)
--   2. Rebuild the place (build-place.bat). It appears in ReplicatedStorage.Models.
--   Any name listed in Resources/Model-Names.md is used automatically; anything missing keeps
--   its placeholder. Models are scaled to fit and anchored by code, so any size works.
--   Models should face -Z (Studio's "front"); the bottom of the model sits on the ground.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ModelFixes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ModelFixes"))

local Assets = {}

-- name -> part count, for models skipped as too heavy (filled by SanitizeAll)
local tooHeavy: { [string]: number } = {}

local function source(): Instance?
	return ReplicatedStorage:FindFirstChild("Models") or ServerStorage:FindFirstChild("Models")
end

function Assets.Has(name: string): boolean
	local folder = source()
	return folder ~= nil and folder:FindFirstChild(name) ~= nil and tooHeavy[name] == nil
end

export type Options = {
	Height: number?, -- scale so the model is this tall
	Width: number?, -- or scale so its widest side is this wide
	FitWidth: number?, -- then stretch sideways only to exactly this width (gates)
	Collide: boolean?, -- solid (default false)
	Query: boolean?, -- clickable/raycastable (default true)
}

-- Free models often carry extras: scripts, hidden screen GUIs, remotes, seats, click detectors,
-- NPC humanoids, sounds. Keep only what draws the model; remove everything else.
local VISUAL = {
	"BasePart", "Model", "Folder", "Attachment", "DataModelMesh", "Decal", "Texture",
	"SurfaceAppearance", "Light", "ParticleEmitter", "Fire", "Smoke", "Sparkles", "Beam", "Trail",
	"Highlight", "Accessory", "Shirt", "Pants", "BodyColors", "WrapLayer",
}
local REMOVE_PARTS = { "SpawnLocation", "Terrain" }

local function isVisual(instance: Instance): boolean
	-- text on signs: a SurfaceGui and the UI inside it are fine
	if instance:IsA("SurfaceGui") or (instance:IsA("GuiObject") or instance:IsA("UIComponent")) and instance:FindFirstAncestorWhichIsA("SurfaceGui") then
		return true
	end
	for _, class in REMOVE_PARTS do
		if instance:IsA(class) then
			return false
		end
	end
	for _, class in VISUAL do
		if instance:IsA(class) then
			return true
		end
	end
	return false
end

function Assets.Sanitize(model: Instance): number
	local remove = {}
	for _, d in model:GetDescendants() do
		if not isVisual(d) then
			table.insert(remove, d)
		end
	end
	for _, d in remove do
		pcall(function()
			d:Destroy()
		end)
	end
	-- seats stay as scenery but nobody can sit on them
	for _, d in model:GetDescendants() do
		if d:IsA("Seat") or d:IsA("VehicleSeat") then
			pcall(function()
				(d :: any).Disabled = true
			end)
		end
	end
	return #remove
end

-- Models above this many parts keep their block version (too heavy, especially on phones)
Assets.MaxParts = 1200
Assets.MaxCropParts = 100 -- crops show on every soil tile (up to 100 per garden)

local function countParts(item: Instance): number
	local parts = if item:IsA("BasePart") then 1 else 0
	for _, d in item:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return parts
end

-- Called once at server start: clean every stored model so no extra (scripts, GUIs, remotes)
-- ever reaches players, turn other containers (Accessory, Tool, Folder) into Models, and skip
-- models that are too heavy. Prints a short report to Output.
function Assets.SanitizeAll()
	local folder = source()
	if not folder then
		return
	end
	local used, heavy = 0, 0
	for _, item in folder:GetChildren() do
		if item:IsA("StringValue") then
			continue -- the HowTo note
		end
		local entry: Instance = item
		if not item:IsA("Model") and not item:IsA("BasePart") then
			-- Accessory, Tool, Folder...: move its contents into a plain Model
			local model = Instance.new("Model")
			model.Name = item.Name
			for _, child in item:GetChildren() do
				child.Parent = model
			end
			item:Destroy()
			model.Parent = folder
			entry = model
		end
		local removed = Assets.Sanitize(entry)
		-- Crop models: drop any flat soil / ground plate (the game already has soil tiles)
		if string.sub(entry.Name, 1, 5) == "Crop_" and entry:IsA("Model") then
			local _, size = Assets.Bounds(entry)
			for _, d in entry:GetDescendants() do
				if d:IsA("BasePart") and d.Size.Y < 1.5 and math.min(d.Size.X, d.Size.Z) > math.max(size.X, size.Z) * 0.6 then
					d:Destroy()
					removed += 1
				end
			end
		end
		local parts = countParts(entry)
		-- Crops appear on every soil tile, so they get a much lower part limit
		if string.sub(entry.Name, 1, 5) == "Crop_" and parts > Assets.MaxCropParts then
			heavy += 1
			tooHeavy[entry.Name] = parts
			warn(`[Assets] {entry.Name}: {parts} parts is too heavy for a crop (limit {Assets.MaxCropParts}), using the blocky crop. Please find a simpler model.`)
			continue
		end
		if parts == 0 then
			warn(`[Assets] {entry.Name}: no visible parts, using the block version`)
			tooHeavy[entry.Name] = 0
		elseif parts > Assets.MaxParts then
			heavy += 1
			tooHeavy[entry.Name] = parts
			warn(`[Assets] {entry.Name}: {parts} parts is too heavy (limit {Assets.MaxParts}), using the block version. Please find a lighter model.`)
		else
			used += 1
			print(`[Assets] {entry.Name}: {parts} parts{if removed > 0 then `, removed {removed} extras` else ""}{if parts > 400 then " (heavy-ish)" else ""}`)
		end
	end
	print(`[Assets] {used} models in use, {heavy} skipped as too heavy`)
end

-- World-aligned box around the VISIBLE parts only. Free models often contain invisible
-- collision boxes or root parts much bigger than the model; measuring those made models tiny.
function Assets.Bounds(model: Model): (CFrame, Vector3)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	local any = false
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 and d.Size.Magnitude > 0.05 then
			any = true
			local cf, half = d.CFrame, d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner = cf:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
						minV = minV:Min(corner)
						maxV = maxV:Max(corner)
					end
				end
			end
		end
	end
	if not any then
		return model:GetBoundingBox()
	end
	return CFrame.new((minV + maxV) / 2), maxV - minV
end

-- Stretch a model along the world X axis only (its width once placed facing -Z), keeping height
-- and depth. Used for gates so a door model fills the whole opening without becoming huge.
function Assets.StretchX(model: Model, targetWidth: number)
	local box, size = Assets.Bounds(model)
	if size.X <= 0.01 then
		return
	end
	local k = targetWidth / size.X
	local cx = box.Position.X
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local cf = d.CFrame
			-- which of the part's own axes points most along world X
			local axes = { cf.RightVector, cf.UpVector, -cf.LookVector }
			local best, bestDot = 1, 0
			for i, axis in axes do
				local dot = math.abs(axis.X)
				if dot > bestDot then
					best, bestDot = i, dot
				end
			end
			local stretch = Vector3.new(if best == 1 then k else 1, if best == 2 then k else 1, if best == 3 then k else 1)
			local newPos = Vector3.new(cx + (cf.Position.X - cx) * k, cf.Position.Y, cf.Position.Z)
			d.Size = d.Size * stretch
			d.CFrame = cf.Rotation + newPos
			local mesh = d:FindFirstChildWhichIsA("DataModelMesh")
			if mesh and mesh:IsA("SpecialMesh") then
				mesh.Scale = mesh.Scale * stretch
			end
		elseif d:IsA("Attachment") then
			-- attachments follow their part automatically
		end
	end
end

-- Clone a model by name, scaled and anchored. Returns nil if there is no such model.
function Assets.Clone(name: string, options: Options?): Model?
	local folder = source()
	local original = folder and folder:FindFirstChild(name)
	if tooHeavy[name] then
		return nil
	end
	if not original then
		return nil
	end
	local model: Model
	if original:IsA("Model") then
		model = original:Clone()
	elseif original:IsA("BasePart") then
		model = Instance.new("Model")
		original:Clone().Parent = model
	else
		return nil
	end
	model.Name = name
	-- Keep the model upright exactly as it looked in Studio: reset its pivot to an unrotated one
	-- at the bounding box center (free models often have a tilted pivot).
	local box = Assets.Bounds(model)
	model.WorldPivot = CFrame.new(box.Position)
	-- Per-model turn fix (src/config/ModelFixes.luau) for models whose front faces another way
	local fix = (ModelFixes :: any)[name]
	if fix and fix.Turn and fix.Turn ~= 0 then
		model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(fix.Turn), 0))
		model.WorldPivot = CFrame.new(Assets.Bounds(model).Position)
	end
	Assets.Sanitize(model)
	local collide = options ~= nil and options.Collide == true
	local query = options == nil or options.Query ~= false
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = collide
			d.CanTouch = false
			d.CanQuery = query
		end
	end
	if options and (options.Height or options.Width) then
		local _, size = Assets.Bounds(model)
		local factor = 1
		if options.Height and size.Y > 0 then
			factor = options.Height / size.Y
		elseif options.Width then
			factor = options.Width / math.max(size.X, size.Z, 0.01)
		end
		pcall(function()
			model:ScaleTo(model:GetScale() * factor)
		end)
	end
	local scale = fix and fix.Scale
	if scale and scale ~= 1 then
		pcall(function()
			model:ScaleTo(model:GetScale() * scale)
		end)
	end
	if options and options.FitWidth then
		-- Gates: a gate is always wider than it is deep. Turn the model so its long side runs along
		-- X (along the fence once placed), whatever way the model was built, then stretch it.
		local _, size = Assets.Bounds(model)
		if size.Z > size.X then
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(90), 0))
			model.WorldPivot = CFrame.new(Assets.Bounds(model).Position)
		end
		Assets.StretchX(model, options.FitWidth)
	end
	return model
end

-- Puts a model's bottom-center at `at` (a CFrame: position on the ground + facing).
function Assets.PlaceModel(model: Model, at: CFrame)
	model:PivotTo(at.Rotation + model:GetPivot().Position)
	local box, size = Assets.Bounds(model)
	local bottom = box.Position - Vector3.new(0, size.Y / 2, 0)
	model:TranslateBy(at.Position - bottom)
end

-- Clone + place + parent in one call. Returns nil if there is no model with that name.
function Assets.Place(name: string, at: CFrame, parent: Instance, options: Options?): Model?
	local model = Assets.Clone(name, options)
	if not model then
		return nil
	end
	Assets.PlaceModel(model, at)
	model.Parent = parent
	return model
end

-- For moving characters (creatures, monsters): hides the placeholder shapes and puts the art
-- model inside `model` so it moves with it. `anchor` keeps prompts, name tags and hit boxes.
function Assets.Dress(model: Model, name: string, anchor: BasePart, options: Options?): Model?
	local art = Assets.Clone(name, options)
	if not art then
		return nil
	end
	art.Name = "Art"
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
		end
	end
	local ground = anchor.Position - Vector3.new(0, anchor.Size.Y / 2, 0)
	Assets.PlaceModel(art, anchor.CFrame.Rotation + ground)
	art.Parent = model
	return art
end

-- Fade every part of an art model (for see-through monsters, broken buildings)
function Assets.SetTransparency(art: Instance, value: number)
	for _, d in art:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = value
		end
	end
end

-- Static placeholder → art swap (buildings): hides the code-built parts, keeps them for health
-- bars and lights. Returns the art model or nil.
function Assets.Replace(model: Model, name: string, at: CFrame, options: Options?): Model?
	local art = Assets.Clone(name, options)
	if not art then
		return nil
	end
	art.Name = "Art"
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
		end
	end
	Assets.PlaceModel(art, at)
	art.Parent = model
	return art
end

return Assets
