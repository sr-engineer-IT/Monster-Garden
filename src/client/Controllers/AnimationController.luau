--!strict
-- Smooth animation for creatures and monsters, on this player's screen only (see server/Rig.luau).
-- The server moves each model's invisible Body a few times a second; here, every frame, the visible
-- part follows it smoothly and plays a simple procedural animation through AnimJoint.Transform:
--   creatures: hop while moving, gentle breathing and sway when idle, a happy jump when petted
--   monsters:  waddle and bob while moving, breathing when idle, shake + white flash when hit
-- Works the same for code-built shapes and imported 3D models. No network traffic.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AnimationController = {}

type Entry = {
	Joint: Motor6D,
	Body: BasePart,
	Model: Instance,
	Kind: string,
	Size: number,
	Smooth: CFrame,
	Speed: number,
	Phase: number,
	Seed: number,
	HitTime: number,
	HappyTime: number,
}

local entries: { [Motor6D]: Entry } = {}
local MAX_DISTANCE = 220 -- studs from the camera; farther models just follow without animating

local function flash(model: Instance)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.25
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	TweenService:Create(highlight, TweenInfo.new(0.22), { FillTransparency = 1 }):Play()
	task.delay(0.25, function()
		highlight:Destroy()
	end)
end

local function register(joint: Motor6D)
	if entries[joint] or joint.Name ~= "AnimJoint" then
		return
	end
	local body = joint.Part0
	local model = joint:FindFirstAncestorOfClass("Model")
	if not body or not model then
		return
	end
	local entry: Entry = {
		Joint = joint,
		Body = body,
		Model = model,
		Kind = model:GetAttribute("AnimKind") or "Creature",
		Size = model:GetAttribute("AnimSize") or body.Size.Y,
		Smooth = body.CFrame,
		Speed = 0,
		Phase = math.random() * 6,
		Seed = math.random() * 100,
		HitTime = -10,
		HappyTime = -10,
	}
	entries[joint] = entry
	model:GetAttributeChangedSignal("HitAt"):Connect(function()
		entry.HitTime = os.clock()
		flash(model)
	end)
	model:GetAttributeChangedSignal("HappyAt"):Connect(function()
		entry.HappyTime = os.clock()
	end)
	joint.Destroying:Connect(function()
		entries[joint] = nil
	end)
end

local function animate(entry: Entry, dt: number, now: number, camPos: Vector3)
	local body = entry.Body
	local target = body.CFrame
	-- Follow the server position smoothly (it only updates a few times a second)
	local gap = (target.Position - entry.Smooth.Position).Magnitude
	local previous = entry.Smooth
	if gap > 25 then
		entry.Smooth = target -- teleported: snap
	else
		entry.Smooth = entry.Smooth:Lerp(target, math.min(1, dt * 12))
	end
	local moved = Vector3.new(entry.Smooth.X - previous.X, 0, entry.Smooth.Z - previous.Z).Magnitude
	entry.Speed += ((if dt > 0 then moved / dt else 0) - entry.Speed) * math.min(1, dt * 6)

	local offset = CFrame.identity
	if (target.Position - camPos).Magnitude < MAX_DISTANCE then
		local s = entry.Size
		local moving = entry.Speed > 1.2
		if entry.Kind == "Monster" then
			if moving then
				entry.Phase += dt * (7 + entry.Speed * 0.3)
				local bob = math.abs(math.sin(entry.Phase)) * s * 0.12
				offset = CFrame.new(0, bob, 0) * CFrame.Angles(math.rad(-6), 0, math.sin(entry.Phase) * 0.16)
			else
				local breathe = math.sin(now * 2.2 + entry.Seed) * s * 0.03
				offset = CFrame.new(0, breathe, 0) * CFrame.Angles(0, math.sin(now * 0.8 + entry.Seed) * 0.08, 0)
			end
			local sinceHit = now - entry.HitTime
			if sinceHit < 0.25 then
				local k = (1 - sinceHit / 0.25) * s * 0.12
				offset = CFrame.new(math.sin(now * 90) * k, 0, math.cos(now * 70) * k) * offset
			end
		else
			if moving then
				entry.Phase += dt * (9 + entry.Speed * 0.35)
				local hop = math.abs(math.sin(entry.Phase)) * math.max(0.4, s * 0.35)
				offset = CFrame.new(0, hop, 0) * CFrame.Angles(math.rad(-8) * math.abs(math.sin(entry.Phase)), 0, 0)
			else
				local breathe = (math.sin(now * 2.6 + entry.Seed) * 0.5 + 0.5) * s * 0.04
				offset = CFrame.new(0, breathe, 0) * CFrame.Angles(0, math.sin(now * 0.6 + entry.Seed) * 0.12, math.sin(now * 1.3 + entry.Seed) * 0.03)
			end
			local sinceHappy = now - entry.HappyTime
			if sinceHappy < 0.6 then
				local k = sinceHappy / 0.6
				offset = CFrame.new(0, math.sin(k * math.pi) * math.max(1, s * 0.8), 0) * CFrame.Angles(0, k * math.pi * 2, 0) * offset
			end
		end
	end
	-- Transform is relative to the Body: place the look at the smoothed position, then animate
	entry.Joint.Transform = target:ToObjectSpace(entry.Smooth) * offset
end

function AnimationController.Start()
	for _, d in Workspace:GetDescendants() do
		if d:IsA("Motor6D") and d.Name == "AnimJoint" then
			register(d)
		end
	end
	Workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Motor6D") and d.Name == "AnimJoint" then
			task.defer(register, d) -- wait until the model's attributes have arrived
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		local camPos = if camera then camera.CFrame.Position else Vector3.zero
		local now = os.clock()
		for joint, entry in entries do
			if joint.Parent and entry.Body.Parent then
				animate(entry, dt, now, camPos)
			else
				entries[joint] = nil
			end
		end
	end)
end

return AnimationController
