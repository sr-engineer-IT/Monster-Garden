--!strict
-- Training mini-game (Build Spec section 22.1): tap as fast as you can for 10 seconds.
-- The server decides the result and the cooldown; the tap count is only a hint.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))

local player = Players.LocalPlayer
local C = Kit.Colors

local TrainingGame = {}

local running = false

function TrainingGame.Start(creatureId: string, name: string)
	if running then
		return
	end
	running = true
	local gui = Kit.New("ScreenGui", { Name = "Training", ResetOnSpawn = false, DisplayOrder = 10, Parent = player:WaitForChild("PlayerGui") })
	local frame = Kit.New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(320, 300), BackgroundColor3 = C.Panel, Parent = gui }, { Kit.Corner(16), Kit.Padding(12) })
	Kit.Label({ Text = `Train {name}! Tap fast!`, TextSize = 22, Size = UDim2.new(1, 0, 0, 30), Parent = frame })
	local status = Kit.Label({ Text = "", TextSize = 18, TextColor3 = C.Coins, Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 24), Parent = frame })
	local taps = 0
	local seconds = Config.Engagement.TrainingSeconds
	local tapButton = Kit.Button({ Text = "TAP!", TextSize = 36, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(200, 180), BackgroundColor3 = C.Good, Parent = frame }, function()
		taps += 1
	end)
	local started = os.clock()
	while os.clock() - started < seconds do
		status.Text = `{math.ceil(seconds - (os.clock() - started))}s - taps: {taps}`
		task.wait(0.1)
	end
	tapButton.Active = false
	status.Text = `Done! {taps} taps`
	Remotes.Get("TrainCreature"):FireServer(creatureId, math.min(taps, 200))
	task.wait(1.2)
	gui:Destroy()
	running = false
end

return TrainingGame
