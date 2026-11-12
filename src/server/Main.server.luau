--!strict
-- Server entry point: creates remotes, then boots every service in order.
-- Each service is a ModuleScript in Services exposing Init() and Start().
-- Init: set up state, no yielding. Start: connect events and start loops.
-- Services reach each other through Registry (filled here before Init), so there are no require cycles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Registry = require(script.Parent:WaitForChild("Registry"))

local Services = script.Parent:WaitForChild("Services")

-- Chat window stays at the top left: the menu buttons are at the bottom left and must stay clickable
task.spawn(function()
	pcall(function()
		local window = game:GetService("TextChatService"):WaitForChild("ChatWindowConfiguration", 10) :: any
		if window then
			window.HorizontalAlignment = Enum.HorizontalAlignment.Left
			window.VerticalAlignment = Enum.VerticalAlignment.Top
		end
	end)
end)

local BOOT_ORDER = {
	"DataService",
	"AntiExploit",
	"ProgressionService",
	"WorldService",
	"PlotService",
	"CropService",
	"EconomyService",
	"DecorService",
	"UpgradeService",
	"LifecycleService", -- before CreatureService so saved life stages are fixed before models spawn
	"CreatureService",
	"BreedingService",
	"MutationService",
	"DefenseService",
	"MonsterService",
	"HungerService",
	"FeastService",
	"KidnapService",
	"HeistService",
	"DayNightService",
	"ObjectiveService",
	"PetalService",
	"ShopService",
	"TradeService",
	"SocialService",
	"MonetizationService",
	"SeasonService",
	"ExploreService",
	"QuestService",
	"RebirthService",
	"PuzzleService",
}

Remotes.Setup()

-- Clean imported 3D models (assets/models) before anything uses them
require(script.Parent:WaitForChild("Assets")).SanitizeAll()

type Service = { Init: (() -> ())?, Start: (() -> ())? }
local loaded: { { Name: string, Service: Service } } = {}

for _, name in BOOT_ORDER do
	local module = Services:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local service = require(module) :: any
		Registry[name] = service
		table.insert(loaded, { Name = name, Service = service })
	end
end

for _, child in Services:GetChildren() do
	if child:IsA("ModuleScript") and not table.find(BOOT_ORDER, child.Name) then
		warn(`[Main] {child.Name} is not in BOOT_ORDER and was not started`)
	end
end

for _, entry in loaded do
	if entry.Service.Init then
		entry.Service.Init()
	end
end

for _, entry in loaded do
	if entry.Service.Start then
		entry.Service.Start()
	end
end

if RunService:IsStudio() then
	require(script.Parent:WaitForChild("Dev"):WaitForChild("DevCommands")).Start()
end

print(`[Main] Server started with {#loaded} services`)
