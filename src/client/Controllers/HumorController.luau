--!strict
-- Humor on this player's screen (lines in config/Humor.luau):
--   * a "Moon News" card when you join (funny news or a funny tip), disappears by itself
--   * speech bubbles over monsters at night ("Is that a carrot?? MINE.")
--   * speech bubbles over your creatures when you pet them ("More carrots or I riot.")
-- Never blocks play: no buttons to press, everything fades away on its own.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Humor = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Humor"))

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("UI"):WaitForChild("Kit"))
local DataController = require(script.Parent:WaitForChild("DataController"))

local player = Players.LocalPlayer
local C = Kit.Colors

local HumorController = {}

local function pick(list: { string }): string
	return list[math.random(1, #list)]
end

-- Moon News card -----------------------------------------------------------------------------------

local function showNews()
	local useTip = math.random() < 0.3
	local text = if useTip then pick(Humor.Tips) else pick(Humor.MoonNews)
	local gui = Kit.New("ScreenGui", { Name = "MoonNews", ResetOnSpawn = false, DisplayOrder = 4, Parent = player:WaitForChild("PlayerGui") })
	local card = Kit.Pill({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.fromOffset(460, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = gui }, {
		Kit.Padding(12, 16),
		Kit.New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local scale = Kit.New("UIScale", { Scale = 0.6, Parent = card })
	Kit.Label({ Text = if useTip then "💡 Moon Tip" else "📰 Moon News", TextSize = 18, TextColor3 = C.Coins, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Parent = card })
	Kit.Label({ Text = text, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 2, Parent = card })
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = math.clamp(math.min(viewport.Y / 760, viewport.X / 1100), 0.6, 1) }):Play()
	task.delay(8, function()
		TweenService:Create(scale, TweenInfo.new(0.25), { Scale = 0 }):Play()
		task.wait(0.3)
		gui:Destroy()
	end)
end

-- Speech bubbles ------------------------------------------------------------------------------------

local function bubble(model: Instance, text: string, seconds: number)
	local body = model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") or model:FindFirstChild("Speech") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Speech"
	gui.Adornee = body
	gui.Size = UDim2.fromScale(7, 1.6) -- studs
	gui.StudsOffset = Vector3.new(0, body.Size.Y * 0.6 + 3.4, 0)
	gui.MaxDistance = 80
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local frame = Kit.New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 255), Parent = gui }, { Kit.Corner(10), Kit.Stroke(C.Stroke, 2) })
	local label = Kit.New("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), Font = Kit.Fonts.Title, TextScaled = true, TextColor3 = C.Stroke, Text = text, Parent = frame })
	gui.Parent = model
	task.delay(seconds, function()
		TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		local stroke = frame:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end
		task.wait(0.35)
		gui:Destroy()
	end)
end

local function watchCreature(model: Instance)
	if model:GetAttribute("AnimKind") ~= "Creature" then
		return
	end
	model:GetAttributeChangedSignal("HappyAt"):Connect(function()
		bubble(model, pick(Humor.CreatureQuips), 3)
	end)
end

function HumorController.Start()
	-- Moon News once per join (not on the very first join, when the How to Play guide opens)
	task.spawn(function()
		local data = DataController.Get()
		while not data do
			task.wait(0.5)
			data = DataController.Get()
		end
		if data.TutorialDone and data.TutorialDone.Guide then
			task.wait(4)
			showNews()
		end
	end)

	-- Creature pet bubbles
	for _, d in Workspace:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("AnimKind") then
			watchCreature(d)
		end
	end
	Workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Model") then
			task.defer(watchCreature, d)
		end
	end)

	-- Monster bubbles: now and then a nearby monster says something
	task.spawn(function()
		while true do
			task.wait(1.5)
			local camera = Workspace.CurrentCamera
			local plots = Workspace:FindFirstChild("Plots")
			if camera and plots then
				for _, plot in plots:GetChildren() do
					local monsters = plot:FindFirstChild("Monsters")
					for _, monster in monsters and monsters:GetChildren() or {} do
						local look = monster:GetAttribute("Look")
						local body = monster:FindFirstChild("Body")
						if type(look) == "string" and body and body:IsA("BasePart") and (body.Position - camera.CFrame.Position).Magnitude < 70 and math.random() < 0.07 then
							local lines = (Humor.MonsterQuips :: any)[look] or Humor.MonsterQuips.swarmer
							bubble(monster, pick(lines), 2.8)
						end
					end
				end
			end
		end
	end)
end

return HumorController
