--!strict
-- DefenseService: fences at the 4 gates, lantern posts, traps inside the gates, a watchtower and a
-- shelter, built, repaired and reinforced through prompts on fixed slots (Build Spec section 9).
-- Saved as data.Plot.Buildings[slotId] = { Type = defenseId, Health = number }.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Defenses = require(ConfigFolder:WaitForChild("Defenses"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local S = require(script.Parent.Parent.Registry)
local Build = require(script.Parent.Parent.Build)
local Assets = require(script.Parent.Parent.Assets)

type Kind = "Gate" | "Post" | "Trap" | "Tower" | "Shelter"

type Slot = {
	Id: string,
	Kind: Kind,
	Gate: string?,
	Position: Vector3,
	Anchor: BasePart,
	Prompt: ProximityPrompt,
	Model: Model?,
	HealthBar: Frame?,
	Light: PointLight?,
}

local DefenseService = {}

local slots: { [Player]: { [string]: Slot } } = {}
local lightsOn: { [Player]: boolean } = {}

local DEFAULT_TYPE: { [string]: string } = { Gate = "wood_fence", Post = "lantern", Trap = "trap", Tower = "watchtower", Shelter = "shelter" }
local GATE_NAMES = { N = "north", E = "east", S = "south", W = "west" }

local function notify(player: Player, text: string)
	Remotes.Get("Notify"):FireClient(player, { Text = text })
end

local function costOf(defense: Defenses.Defense, share: number): { Coins: number?, Essence: number? }
	return {
		Coins = if defense.Cost.Coins then math.ceil(defense.Cost.Coins * share) else nil,
		Essence = if defense.Cost.Essence then math.ceil(defense.Cost.Essence * share) else nil,
	}
end

local function countBuildings(data: any): number
	local count = 0
	for _ in data.Plot.Buildings do
		count += 1
	end
	return count
end

-- What the slot prompt does right now: "build", "repair", "reinforce" or nil
local function actionFor(data: any, slot: Slot): (string?, string?)
	local record = data.Plot.Buildings[slot.Id]
	if record == nil then
		local defenseId = DEFAULT_TYPE[slot.Kind]
		local defense = Defenses.ById[defenseId]
		if data.Unlocks[defense.Feature] then
			return "build", defenseId
		end
		return nil, nil
	end
	local defense = Defenses.ById[record.Type]
	if defense.Health and record.Health < defense.Health then
		return "repair", record.Type
	end
	if record.Type == "wood_fence" and data.Unlocks.ReinforcedFence then
		return "reinforce", "reinforced_fence"
	end
	return nil, nil
end

local function buildVisual(player: Player, slot: Slot, record: any?)
	if slot.Model then
		slot.Model:Destroy()
		slot.Model = nil
		slot.HealthBar = nil
		slot.Light = nil
	end
	if record == nil then
		return
	end
	local defense = Defenses.ById[record.Type]
	local broken = defense.Health ~= nil and record.Health <= 0
	local fade = if broken then 0.65 else 0
	local model = Instance.new("Model")
	model.Name = record.Type
	local main: BasePart
	local p = slot.Position

	if slot.Kind == "Gate" then
		local alongX = slot.Gate == "N" or slot.Gate == "S"
		local width = Config.World.GateWidth
		local reinforced = record.Type == "reinforced_fence"
		local thickness = if reinforced then 1.6 else 0.8
		main = Build.Part({
			Size = if alongX then Vector3.new(width, 4, thickness) else Vector3.new(thickness, 4, width),
			Position = p + Vector3.new(0, 2, 0),
			Color = if reinforced then Color3.fromRGB(130, 130, 140) else Color3.fromRGB(160, 110, 60),
			Material = if reinforced then Enum.Material.Slate else Enum.Material.WoodPlanks,
			Transparency = fade,
			Parent = model,
		})
	elseif slot.Kind == "Post" then
		Build.Part({ Size = Vector3.new(0.5, 7, 0.5), Position = p + Vector3.new(0, 3.5, 0), Color = Color3.fromRGB(50, 45, 40), Transparency = fade, Parent = model })
		main = Build.Ball({ Size = Vector3.one * 1.8, Position = p + Vector3.new(0, 7.4, 0), Color = if broken then Color3.fromRGB(80, 80, 80) else Color3.fromRGB(255, 220, 120), Material = if broken then Enum.Material.SmoothPlastic else Enum.Material.Neon, Parent = model })
		if not broken then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 210, 130)
			light.Range = 20
			light.Brightness = 2
			light.Enabled = lightsOn[player] == true
			light.Parent = main
			slot.Light = light
		end
	elseif slot.Kind == "Trap" then
		main = Build.Part({ Size = Vector3.new(3, 0.3, 3), Position = p + Vector3.new(0, 0.35, 0), Color = Color3.fromRGB(110, 110, 120), Material = Enum.Material.DiamondPlate, Parent = model })
		for i = -1, 1 do
			Build.Part({ Size = Vector3.new(0.3, 0.8, 0.3), Position = p + Vector3.new(i * 0.9, 0.8, 0), Color = Color3.fromRGB(200, 200, 210), Parent = model })
		end
	elseif slot.Kind == "Tower" then
		for _, corner in { Vector3.new(-2, 0, -2), Vector3.new(2, 0, -2), Vector3.new(-2, 0, 2), Vector3.new(2, 0, 2) } do
			Build.Part({ Size = Vector3.new(0.6, 12, 0.6), Position = p + corner + Vector3.new(0, 6, 0), Color = Color3.fromRGB(140, 100, 60), Transparency = fade, Parent = model })
		end
		main = Build.Part({ Size = Vector3.new(6, 0.6, 6), Position = p + Vector3.new(0, 12, 0), Color = Color3.fromRGB(160, 110, 70), Material = Enum.Material.WoodPlanks, Transparency = fade, Parent = model })
		Build.Part({ Size = Vector3.new(6.6, 0.4, 6.6), Position = p + Vector3.new(0, 15, 0), Color = Color3.fromRGB(200, 80, 70), Parent = model })
	else
		main = Build.Part({ Size = Vector3.new(7, 4, 7), Position = p + Vector3.new(0, 2, 0), Color = Color3.fromRGB(170, 140, 100), Material = Enum.Material.WoodPlanks, Transparency = fade, Parent = model })
		Build.Part({ Size = Vector3.new(8, 0.6, 8), Position = p + Vector3.new(0, 4.3, 0), Color = Color3.fromRGB(110, 80, 60), Parent = model })
	end

	if defense.Health and not defense.OneUse then
		local gui = Build.Billboard(main, 90, 10, 3.5)
		local fill = Build.Bar(gui, Color3.fromRGB(110, 220, 90), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
		fill.Size = UDim2.fromScale(math.max(0, record.Health / defense.Health), 1)
		gui.Enabled = record.Health < defense.Health
		slot.HealthBar = fill
	end
	-- Real 3D model (assets/models/Building_<type>.rbxm) replaces the shapes if present
	local facing = CFrame.new(p)
	local options: Assets.Options = { Height = if slot.Kind == "Tower" then 16 elseif slot.Kind == "Post" then 8 elseif slot.Kind == "Trap" then 1.2 else 5, Collide = slot.Kind == "Gate" }
	if slot.Kind == "Gate" then
		local outwardDir = ((Config.World.Gates :: any)[slot.Gate or "N"] :: Vector3).Unit
		facing = CFrame.lookAt(p, p + outwardDir)
		options = { Height = 7, Collide = true } -- a bit taller than the 4-stud fence
	end
	local art = Assets.Replace(model, `Building_{record.Type}`, facing, options)
	if art and broken then
		Assets.SetTransparency(art, 0.6)
	end
	model.Parent = slot.Anchor
	slot.Model = model
end

local function costText(cost: any): string
	return S.EconomyService.CostText(cost)
end

local function refreshPrompt(data: any, slot: Slot)
	local action, defenseId = actionFor(data, slot)
	if action == nil or defenseId == nil then
		Build.SetPrompt(slot.Prompt, nil)
		return
	end
	local defense = Defenses.ById[defenseId]
	if action == "build" then
		Build.SetPrompt(slot.Prompt, `Build {defense.Name}`, costText(costOf(defense, 1)), 0.5)
	elseif action == "repair" then
		Build.SetPrompt(slot.Prompt, "Repair", costText(costOf(defense, Defenses.RepairCostShare)), Defenses.RepairSeconds)
	else
		Build.SetPrompt(slot.Prompt, "Reinforce", costText(costOf(defense, 1)), 0.5)
	end
end

local function act(player: Player, slotId: string)
	local data = S.DataService.GetData(player)
	local slot = slots[player] and slots[player][slotId]
	if not data or not slot or not S.AntiExploit.WithinDistance(player, slot.Position, Config.Distance.Interact) then
		return
	end
	local action, defenseId = actionFor(data, slot)
	if action == nil or defenseId == nil then
		return
	end
	local defense = Defenses.ById[defenseId]

	if action == "build" then
		local maxSlots = GameMath.DefenseSlots(data.GardenLevel)
		if countBuildings(data) >= maxSlots then
			notify(player, `All {maxSlots} defense slots used. Level up for more.`)
			return
		end
		if not S.EconomyService.Spend(player, costOf(defense, 1)) then
			return
		end
		data.Plot.Buildings[slotId] = { Type = defenseId, Health = defense.Health or 1 }
		notify(player, `{defense.Name} built!`)
		S.ObjectiveService.Progress(player, "Build:" .. defenseId)
	elseif action == "repair" then
		if not S.EconomyService.Spend(player, costOf(defense, Defenses.RepairCostShare)) then
			return
		end
		data.Plot.Buildings[slotId].Health = defense.Health
		notify(player, `{defense.Name} repaired!`)
	else
		if not S.EconomyService.Spend(player, costOf(defense, 1)) then
			return
		end
		data.Plot.Buildings[slotId] = { Type = defenseId, Health = defense.Health }
		notify(player, "Fence reinforced!")
		S.ObjectiveService.Progress(player, "Build:" .. defenseId)
	end
	buildVisual(player, slot, data.Plot.Buildings[slotId])
	refreshPrompt(data, slot)
	player:SetAttribute("HasWatchtower", DefenseService.HasBuilding(player, "watchtower"))
	S.DataService.MarkChanged(player)
end

local function createSlots(player: Player, data: any)
	local plot = S.PlotService.GetPlot(player)
	if not plot then
		return
	end
	local list: { [string]: Slot } = {}
	slots[player] = list

	local function add(id: string, kind: Kind, position: Vector3, gate: string?)
		local anchor = Build.Part({ Name = id, Size = Vector3.new(1, 1, 1), Position = position + Vector3.new(0, 2, 0), Transparency = 1, Parent = plot.Folders.Buildings })
		local prompt = Build.Prompt(anchor, "Build", "", { Distance = 11 })
		prompt.Triggered:Connect(function(who)
			if who == player then
				act(player, id)
			end
		end)
		local slot: Slot = { Id = id, Kind = kind, Gate = gate, Position = position, Anchor = anchor, Prompt = prompt }
		list[id] = slot
		buildVisual(player, slot, data.Plot.Buildings[id])
		refreshPrompt(data, slot)
	end

	for gate, offset in Config.World.Gates do
		add("gate_" .. gate, "Gate", plot.Center + offset, gate)
	end
	for index, offset in Config.World.LanternPosts do
		add("post_" .. index, "Post", plot.Center + offset)
	end
	for index, offset in Config.World.TrapSpots do
		add("trap_" .. index, "Trap", plot.Center + offset)
	end
	add("tower", "Tower", plot.Center + Config.World.TowerSpot)
	add("shelter", "Shelter", plot.Center + Config.World.ShelterSpot)
	player:SetAttribute("HasWatchtower", DefenseService.HasBuilding(player, "watchtower"))
end

-- Queries -----------------------------------------------------------------------------------------------

function DefenseService.HasBuilding(player: Player, defenseId: string): boolean
	local data = S.DataService.GetData(player)
	if not data then
		return false
	end
	for _, record in data.Plot.Buildings do
		if record.Type == defenseId and record.Health > 0 then
			return true
		end
	end
	return false
end

function DefenseService.GetGatePosition(player: Player, gate: string): Vector3?
	local slot = slots[player] and slots[player]["gate_" .. gate]
	return if slot then slot.Position else nil
end

-- True while a fence still stands at this gate
function DefenseService.IsGateBlocked(player: Player, gate: string): boolean
	local data = S.DataService.GetData(player)
	local record = data and data.Plot.Buildings["gate_" .. gate]
	return record ~= nil and record.Health > 0
end

-- Returns true when this hit broke the fence (or there was none)
function DefenseService.DamageGate(player: Player, gate: string, amount: number): boolean
	local data = S.DataService.GetData(player)
	local slotId = "gate_" .. gate
	local record = data and data.Plot.Buildings[slotId]
	local slot = slots[player] and slots[player][slotId]
	if not record or not slot or record.Health <= 0 then
		return true
	end
	local defense = Defenses.ById[record.Type]
	record.Health = math.max(0, record.Health - amount)
	if record.Health <= 0 then
		buildVisual(player, slot, record)
		notify(player, `Your {GATE_NAMES[gate]} fence broke! Repair it in the day.`)
		S.DataService.MarkChanged(player)
		return true
	end
	if slot.HealthBar and defense.Health then
		slot.HealthBar.Size = UDim2.fromScale(record.Health / defense.Health, 1)
		local gui = slot.HealthBar.Parent and slot.HealthBar.Parent.Parent
		if gui and gui:IsA("BillboardGui") then
			gui.Enabled = true
		end
	end
	S.DataService.MarkChanged(player)
	return false
end

-- Lantern light: monsters inside move slower; Swarmers may flee
function DefenseService.IsLit(player: Player?, position: Vector3): boolean
	local data = player and S.DataService.GetData(player)
	if not player or not data then
		return false
	end
	local radius = Defenses.ById.lantern.LightRadius or 0
	for slotId, slot in slots[player] or {} do
		local record = data.Plot.Buildings[slotId]
		if record and record.Type == "lantern" and record.Health > 0 then
			local offset = position - slot.Position
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius then
				return true
			end
		end
	end
	return false
end

-- Armed traps whose area contains the position
function DefenseService.TrapsNear(player: Player?, position: Vector3): { { SlotId: string, Position: Vector3 } }
	local result = {}
	local data = player and S.DataService.GetData(player)
	if not player or not data then
		return result
	end
	local radius = Defenses.ById.trap.AreaRadius or 6
	for slotId, slot in slots[player] or {} do
		local record = data.Plot.Buildings[slotId]
		if record and record.Type == "trap" then
			local offset = position - slot.Position
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius then
				table.insert(result, { SlotId = slotId, Position = slot.Position })
			end
		end
	end
	return result
end

-- Fires a one-use trap; returns its area damage and radius
function DefenseService.ConsumeTrap(player: Player, slotId: string): (number, number)
	local data = S.DataService.GetData(player)
	local slot = slots[player] and slots[player][slotId]
	if not data or not slot or not data.Plot.Buildings[slotId] then
		return 0, 0
	end
	data.Plot.Buildings[slotId] = nil
	buildVisual(player, slot, nil)
	refreshPrompt(data, slot)
	S.DataService.MarkChanged(player)
	local trap = Defenses.ById.trap
	return trap.AreaDamage or 0, trap.AreaRadius or 0
end

function DefenseService.SetLights(player: Player, on: boolean)
	lightsOn[player] = on
	for _, slot in slots[player] or {} do
		if slot.Light then
			slot.Light.Enabled = on
		end
	end
end

function DefenseService.Init() end

function DefenseService.Start()
	S.DataService.ProfileLoaded:Connect(createSlots)
	Players.PlayerRemoving:Connect(function(player)
		slots[player] = nil
		lightsOn[player] = nil
	end)

	-- Prompts follow unlocks and Essence changes
	task.spawn(function()
		while true do
			task.wait(1)
			for player, list in slots do
				local data = S.DataService.GetData(player)
				if data then
					for _, slot in list do
						refreshPrompt(data, slot)
					end
				end
			end
		end
	end)
end

return DefenseService
