--!strict
-- Tutorial pointer (Build Spec section 4: every goal shows "one highlighted object"). The object
-- the current goal needs (a soil tile, the merchant cart, your creature, a gate...) glows and gets
-- a "HERE" marker. Can be turned off in Help. Client-only display.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Objectives = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Objectives"))

local DataController = require(script.Parent:WaitForChild("DataController"))

local player = Players.LocalPlayer

local GuideController = {}

local highlight: Highlight
local marker: BillboardGui
local current: Instance? = nil

local MERCHANT_EVENTS = { Sell = true, BuySeed = true, Expand = true, Soil = true, BuyEgg = true }

local function myPlot(): Instance?
	local index = player:GetAttribute("PlotIndex")
	local plots = Workspace:FindFirstChild("Plots")
	return if plots and index then plots:FindFirstChild(`Plot{index}`) else nil
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

-- Nearest tile whose prompt currently offers one of the given actions
local function tileWith(plot: Instance, actions: { string }): Instance?
	local tiles = plot:FindFirstChild("Tiles")
	local from = rootPosition()
	local best, bestDistance = nil, math.huge
	for _, tile in tiles and tiles:GetChildren() or {} do
		local prompt = tile:FindFirstChildOfClass("ProximityPrompt")
		if prompt and tile:IsA("BasePart") and prompt:GetAttribute("Hidden") ~= true then
			for _, action in actions do
				if string.sub(prompt.ActionText, 1, #action) == action then
					local distance = if from then (tile.Position - from).Magnitude else 0
					if distance < bestDistance then
						best, bestDistance = tile, distance
					end
				end
			end
		end
	end
	return best
end

local function firstCreature(plot: Instance): Instance?
	local creatures = plot:FindFirstChild("Creatures")
	for _, model in creatures and creatures:GetChildren() or {} do
		if model:IsA("Model") and model:FindFirstChild("Body") then
			return model
		end
	end
	return nil
end

local function findTarget(): Instance?
	local data = DataController.Get()
	if not data or (data.Settings and data.Settings.GuideArrow == false) then
		return nil
	end
	local objective = Objectives.List[data.ObjectiveIndex]
	local plot = myPlot()
	if not objective or not plot or not objective.Event then
		return nil
	end
	local event = objective.Event :: string
	local buildings = plot:FindFirstChild("Buildings")

	if event == "Plant" then
		return tileWith(plot, { "Plant" })
	elseif event == "Harvest" then
		return tileWith(plot, { "Harvest" }) or tileWith(plot, { "Water" }) or tileWith(plot, { "Plant" })
	elseif MERCHANT_EVENTS[event] then
		return plot:FindFirstChild("MerchantCart")
	elseif event == "Pet" or event == "Feed" then
		return firstCreature(plot)
	elseif event == "Build:wood_fence" or event == "Build:reinforced_fence" then
		return buildings and buildings:FindFirstChild("gate_S")
	elseif event == "Build:lantern" then
		return buildings and buildings:FindFirstChild("post_3")
	elseif event == "Build:nest" then
		return buildings and buildings:FindFirstChild("nest_1")
	elseif event == "Petal" then
		local petals = plot:FindFirstChild("Petals")
		return petals and petals:GetChildren()[1]
	elseif string.sub(event, 1, 5) == "Kill:" then
		local monsters = plot:FindFirstChild("Monsters")
		return monsters and monsters:GetChildren()[1]
	end
	return nil
end

local function adorneePart(target: Instance): BasePart?
	if target:IsA("BasePart") then
		return target
	elseif target:IsA("Model") then
		return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

function GuideController.Start()
	highlight = Instance.new("Highlight")
	highlight.Name = "GuideHighlight"
	highlight.FillColor = Color3.fromRGB(255, 230, 90)
	highlight.FillTransparency = 0.65
	highlight.OutlineColor = Color3.fromRGB(255, 240, 150)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = Workspace

	marker = Instance.new("BillboardGui")
	marker.Name = "GuideMarker"
	marker.AlwaysOnTop = true
	marker.Size = UDim2.fromOffset(90, 46)
	marker.StudsOffset = Vector3.new(0, 5, 0)
	marker.Enabled = false
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 230, 90)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(90, 60, 0)
	label.Text = "HERE\n▼"
	label.Parent = marker
	marker.Parent = player:WaitForChild("PlayerGui")

	-- Gentle bounce so the marker catches the eye
	task.spawn(function()
		while true do
			local t = os.clock() * 3
			marker.StudsOffset = Vector3.new(0, 5 + math.sin(t) * 0.6, 0)
			task.wait(1 / 30)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.4)
			local target = findTarget()
			if target ~= current then
				current = target
				local part = target and adorneePart(target)
				highlight.Adornee = target
				highlight.Enabled = target ~= nil
				marker.Adornee = part
				marker.Enabled = part ~= nil
			end
		end
	end)
end

return GuideController
