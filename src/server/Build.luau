--!strict
-- Small helpers for building placeholder models, prompts and billboards on the server.

local Build = {}

-- Anchored, non-colliding smooth part. Parent is applied last.
function Build.Part(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

function Build.Ball(props: { [string]: any }): Part
	props.Shape = Enum.PartType.Ball
	return Build.Part(props)
end

export type PromptOptions = { Distance: number?, Hold: number? }

function Build.Prompt(parent: Instance, actionText: string, objectText: string, options: PromptOptions?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.MaxActivationDistance = if options and options.Distance then options.Distance else 10
	prompt.HoldDuration = if options and options.Hold then options.Hold else 0
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = parent
	return prompt
end

-- Hidden prompts stay in place; the client's PromptController hides them locally.
function Build.SetPrompt(prompt: ProximityPrompt, actionText: string?, objectText: string?, hold: number?)
	prompt:SetAttribute("Hidden", actionText == nil)
	if actionText then
		prompt.ActionText = actionText
	end
	if objectText then
		prompt.ObjectText = objectText
	end
	if hold then
		prompt.HoldDuration = hold
	end
end

function Build.Billboard(parent: Instance, width: number, height: number, offsetY: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(width, height)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Parent = parent
	return gui
end

function Build.Label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = text
	if props then
		for key, value in props do
			(label :: any)[key] = value
		end
	end
	label.Parent = parent
	return label
end

-- Background + fill frame; returns the fill (set Size.X.Scale to show progress)
function Build.Bar(parent: Instance, color: Color3, position: UDim2, size: UDim2): Frame
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.BackgroundTransparency = 0.3
	back.BorderSizePixel = 0
	back.Position = position
	back.Size = size
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	return fill
end

return Build
