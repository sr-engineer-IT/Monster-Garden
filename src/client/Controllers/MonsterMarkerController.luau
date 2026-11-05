--!strict
-- Watchtower effect (Build Spec section 9): with a watchtower built, monsters in your garden get
-- a marker you can see through walls, so you always know where they are coming from.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local MonsterMarkerController = {}

local function myMonstersFolder(): Instance?
	local index = player:GetAttribute("PlotIndex")
	local plots = Workspace:FindFirstChild("Plots")
	local plot = plots and index and plots:FindFirstChild(`Plot{index}`)
	return plot and plot:FindFirstChild("Monsters")
end

local function mark(model: Instance)
	if not model:IsA("Model") or model:FindFirstChild("Marker") or not player:GetAttribute("HasWatchtower") then
		return
	end
	local body = model:FindFirstChild("Body")
	if not body then
		return
	end
	local marker = Instance.new("BillboardGui")
	marker.Name = "Marker"
	marker.AlwaysOnTop = true
	marker.Size = UDim2.fromOffset(18, 18)
	marker.StudsOffset = Vector3.new(0, 4, 0)
	marker.Adornee = body :: BasePart
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromScale(1, 1)
	dot.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	dot.Parent = marker
	marker.Parent = model
end

function MonsterMarkerController.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			local folder = myMonstersFolder()
			if folder then
				for _, model in folder:GetChildren() do
					mark(model)
				end
			end
		end
	end)
end

return MonsterMarkerController
