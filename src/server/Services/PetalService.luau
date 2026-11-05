--!strict
-- PetalService: glowing Moon Petals appear in the garden while you wait (Build Spec section 22.1).
-- One every MoonPetalIntervalSeconds (max MoonPetalMaxActive); tap to collect Essence.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Config"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local S = require(script.Parent.Parent.Registry)
local Build = require(script.Parent.Parent.Build)

type Garden = { Petals: { [string]: BasePart }, Timer: number }

local PetalService = {}

local gardens: { [Player]: Garden } = {}
local rng = Random.new()

local function collect(player: Player, petalId: string)
	local garden = gardens[player]
	local petal = garden and garden.Petals[petalId]
	if not garden or not petal or not S.AntiExploit.WithinDistance(player, petal.Position, Config.Distance.Interact) then
		return
	end
	garden.Petals[petalId] = nil
	petal:Destroy()
	local amount = Config.Engagement.MoonPetalEssence
	S.EconomyService.AddEssence(player, amount)
	Remotes.Get("Notify"):FireClient(player, { Text = `+{amount} Essence` })
	S.ObjectiveService.Progress(player, "Petal")
end

local function spawnPetal(player: Player, garden: Garden)
	local plot = S.PlotService.GetPlot(player)
	if not plot then
		return
	end
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(Config.World.PetalRingMin, Config.World.PetalRingMax)
	local position = plot.Center + Vector3.new(math.cos(angle) * radius, 1.6, math.sin(angle) * radius)
	local petalId = Util.NewId()
	local petal = Build.Part({ Name = "MoonPetal", Size = Vector3.new(1.4, 0.3, 1.4), CFrame = CFrame.new(position) * CFrame.Angles(0, angle, math.rad(20)), Color = Color3.fromRGB(255, 200, 240), Material = Enum.Material.Neon, Parent = plot.Folders.Petals })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 240)
	light.Range = 8
	light.Parent = petal
	local prompt = Build.Prompt(petal, "Collect", "Moon Petal", { Distance = 9 })
	prompt.Triggered:Connect(function(who)
		if who == player then
			collect(player, petalId)
		end
	end)
	garden.Petals[petalId] = petal
end

function PetalService.Init() end

function PetalService.Start()
	Players.PlayerRemoving:Connect(function(player)
		gardens[player] = nil -- parts are cleared with the plot
	end)

	task.spawn(function()
		while true do
			local dt = task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = S.DataService.GetData(player)
				if data and data.Unlocks.Essence then
					local garden = gardens[player]
					if garden == nil then
						garden = { Petals = {}, Timer = 0 }
						gardens[player] = garden
					end
					garden.Timer += dt
					if garden.Timer >= Config.Engagement.MoonPetalIntervalSeconds then
						garden.Timer = 0
						if Util.CountKeys(garden.Petals) < Config.Engagement.MoonPetalMaxActive then
							spawnPetal(player, garden)
						end
					end
				end
			end
		end
	end)
end

return PetalService
