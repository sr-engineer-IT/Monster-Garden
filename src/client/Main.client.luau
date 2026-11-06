--!strict
-- Client entry point: boots controllers in order, then panel modules. Each exposes optional
-- Init() and Start(). The client only displays state and sends requests; the server decides.

local Controllers = script.Parent:WaitForChild("Controllers")
local Panels = script.Parent:WaitForChild("Panels")

local BOOT_ORDER = {
	"DataController",
	"PromptController",
	"LightingController",
	"CombatController",
	"HUDController",
	"PanelController",
	"MonsterMarkerController",
	"SoundController",
	"GuideController",
	"AnimationController",
}

local PANELS = { "CreaturesPanel", "SocialPanel", "StorePanel", "StallPanel", "TradePanel", "GuidePanel", "QuestsPanel" }

type Module = { Init: (() -> ())?, Start: (() -> ())? }
local loaded: { Module } = {}

for _, name in BOOT_ORDER do
	local module = Controllers:WaitForChild(name, 10)
	if module and module:IsA("ModuleScript") then
		table.insert(loaded, require(module) :: any)
	else
		warn(`[Client] Missing controller {name}`)
	end
end
for _, name in PANELS do
	local module = Panels:WaitForChild(name, 10)
	if module and module:IsA("ModuleScript") then
		table.insert(loaded, require(module) :: any)
	else
		warn(`[Client] Missing panel {name}`)
	end
end

for _, module in loaded do
	if module.Init then
		module.Init()
	end
end

-- DataController.Start fires RequestSync, so start it last to make sure every listener is connected
for index = 2, #loaded do
	local module = loaded[index]
	if module.Start then
		task.spawn(module.Start)
	end
end
if loaded[1] and loaded[1].Start then
	loaded[1].Start()
end
