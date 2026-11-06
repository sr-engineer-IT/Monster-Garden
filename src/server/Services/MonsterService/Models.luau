--!strict
-- Placeholder monster models (cute and non-graphic, section 23.5). Elders are bigger and darker.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monsters = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Monsters"))

local Build = require(script.Parent.Parent.Parent.Build)
local Assets = require(script.Parent.Parent.Parent.Assets)
local Rig = require(script.Parent.Parent.Parent.Rig)

local Models = {}

function Models.Build(lookId: string, name: string, id: string, elder: boolean, parent: Instance): (Model, BasePart, Frame, number)
	local look = Monsters.Looks[lookId] or Monsters.Looks.swarmer
	local size = look.Size * (if elder then Monsters.ElderScale else 1)
	local bodyColor = if elder then look.Body:Lerp(Monsters.ElderTint, 0.5) else look.Body
	local model = Instance.new("Model")
	model.Name = if elder then "Elder " .. name else name
	model:SetAttribute("MonsterId", id)
	local body = Build.Ball({ Name = "Body", Size = Vector3.one * size, Position = Vector3.zero, Color = bodyColor, CanQuery = true, Parent = model })
	for _, side in { -1, 1 } do
		Build.Ball({ Size = Vector3.one * size * 0.28, Position = Vector3.new(side * size * 0.2, size * 0.15, -size * 0.38), Color = look.Eyes, Material = Enum.Material.Neon, CanQuery = true, Parent = model })
		if lookId == "brute" or lookId == "alpha" or elder then
			Build.Part({ Size = Vector3.new(size * 0.12, size * 0.35, size * 0.12), Position = Vector3.new(side * size * 0.3, size * 0.5, -size * 0.1), Color = Color3.fromRGB(240, 230, 200), CanQuery = true, Parent = model })
		end
	end
	if lookId == "alpha" then
		local light = Instance.new("PointLight")
		light.Color = look.Eyes
		light.Range = 24
		light.Brightness = 3
		light.Parent = body
	end
	model.PrimaryPart = body
	-- Real 3D model (assets/models/Monster_<look>.rbxm) replaces the shapes if present.
	-- The invisible Body stays as the hit box, so clicking and attacking work the same.
	local art = Assets.Dress(model, `Monster_{lookId}`, body, { Height = size * 1.3, AlignLength = true })
	if art and elder then
		local highlight = Instance.new("Highlight")
		highlight.FillColor = Monsters.ElderTint
		highlight.FillTransparency = 0.55
		highlight.OutlineColor = look.Eyes
		highlight.Parent = art
	end
	local gui = Build.Billboard(body, if lookId == "alpha" then 220 else 70, if lookId == "alpha" then 16 else 8, size * 0.5 + 1)
	if lookId == "alpha" then
		gui.MaxDistance = 400
		gui.AlwaysOnTop = true
	end
	local fill = Build.Bar(gui, Color3.fromRGB(240, 70, 70), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
	-- Smooth waddle / lunge / hit-shake animation on each player's screen (see Rig.luau)
	Rig.Attach(model, body, "Monster")
	model.Parent = parent
	return model, body, fill, size
end

-- Small glowing bundle a Stalker carries (the kidnapped creature)
function Models.AddCarry(model: Model, size: number): BasePart
	local bundle = Build.Ball({ Name = "Carry", Size = Vector3.one * 1.6, Position = model:GetPivot().Position + Vector3.new(0, size * 0.6, 0), Color = Color3.fromRGB(255, 240, 150), Material = Enum.Material.Neon, Parent = model })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 240, 150)
	light.Range = 16
	light.Parent = bundle
	return bundle
end

return Models
