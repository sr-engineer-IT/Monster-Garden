--!strict
-- Rig: prepares a creature or monster model for smooth animation on the players' computers.
--
-- The server moves the anchored, invisible Body (hit box, prompts, name tag) a few times a second.
-- Everything you SEE (the 3D model, or the code-built shapes) is welded to an invisible
-- "VisualRoot" that hangs off the Body by a Motor6D called "AnimJoint". Each client sets
-- AnimJoint.Transform every frame (client/Controllers/AnimationController): hops, waddles,
-- breathing, lunges and hit shakes. Transform is local to each player, so animation costs no
-- network traffic and never fights with the server's movement.

local Rig = {}

-- model: the creature/monster model; body: its anchored root part (Name "Body")
function Rig.Attach(model: Model, body: BasePart, kind: string)
	local root = Instance.new("Part")
	root.Name = "VisualRoot"
	root.Size = Vector3.one * 0.2
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.Anchored = false
	root.CFrame = body.CFrame
	root.Parent = model

	-- The placeholder body ball is part of the look: show a copy on the animated side instead
	if body.Transparency < 1 then
		local look = Instance.new("Part")
		look.Name = "BodyLook"
		look.Shape = (body :: any).Shape or Enum.PartType.Block
		look.Size = body.Size
		look.Color = body.Color
		look.Material = body.Material
		look.TopSurface = Enum.SurfaceType.Smooth
		look.BottomSurface = Enum.SurfaceType.Smooth
		look.CFrame = body.CFrame
		look.CanCollide = false
		look.CanTouch = false
		look.CanQuery = body.CanQuery -- monsters stay clickable through their look
		look.Massless = true
		look.Anchored = false
		look.Parent = model
		body.Transparency = 1
	end

	-- Weld every visible part to the root
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= body and d ~= root and d.Transparency < 1 then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		end
	end

	local joint = Instance.new("Motor6D")
	joint.Name = "AnimJoint"
	joint.Part0 = body
	joint.Part1 = root
	joint.Parent = body

	model:SetAttribute("AnimKind", kind) -- "Creature" or "Monster": which animation set to play
	model:SetAttribute("AnimSize", body.Size.Y)
end

-- The part to recolor / fade for effects (hit flash, see-through): the visible body if any
function Rig.Look(model: Model, body: BasePart): BasePart
	local look = model:FindFirstChild("BodyLook")
	return if look and look:IsA("BasePart") then look else body
end

-- Tell clients to play the hit shake (they read the attribute change)
function Rig.Hit(model: Model)
	model:SetAttribute("HitAt", os.clock())
end

return Rig
