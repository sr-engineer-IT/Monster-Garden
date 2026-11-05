--!strict
-- Creatures menu (Build Spec section 18): a card per creature with species, sex, life stage, an
-- age bar with the lifespan (never hidden), traits, role, mutations and parents, plus actions:
-- role, breed, train, name, shelter, Heist Pen, recolor and Essence re-roll. Also eggs, nests
-- and the Spirit Grove.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Creatures = require(ConfigFolder:WaitForChild("Creatures"))
local Mutations = require(ConfigFolder:WaitForChild("Mutations"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("UI"):WaitForChild("Kit"))
local DataController = require(Client:WaitForChild("Controllers"):WaitForChild("DataController"))
local PanelController = require(Client:WaitForChild("Controllers"):WaitForChild("PanelController"))
local TrainingGame = require(script.Parent:WaitForChild("TrainingGame"))

local C = Kit.Colors

local CreaturesPanel = {}

local function label(parent: Instance, text: string, order: number, color: Color3?, size: number?)
	return Kit.Label({ Text = text, TextSize = size or 15, TextColor3 = color or C.Text, TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = order, ZIndex = 23, Parent = parent })
end

local function bar(parent: Instance, share: number, color: Color3, order: number)
	local back = Kit.New("Frame", { Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = C.Panel, LayoutOrder = order, ZIndex = 23, Parent = parent }, { Kit.Corner(4) })
	Kit.New("Frame", { Size = UDim2.fromScale(math.clamp(share, 0, 1), 1), BackgroundColor3 = color, ZIndex = 24, Parent = back }, { Kit.Corner(4) })
end

local function hasShelter(data: any): boolean
	for _, record in data.Plot.Buildings do
		if record.Type == "shelter" and record.Health > 0 then
			return true
		end
	end
	return false
end

local function availableRoles(data: any, creature: any): { string }
	local roles = {}
	local species = Creatures.ById[creature.Species]
	if not data.Unlocks.Jobs or not species or creature.Stage == "Baby" then
		return roles
	end
	for _, role in Creatures.RoleOrder do
		local config = (Creatures.Roles :: any)[role]
		if table.find(species.Roles, role) and config.Stage <= data.Stage then
			table.insert(roles, role)
		end
	end
	return roles
end

local function nameOf(data: any, id: string?): string
	local creature = id and data.Creatures[id]
	return if creature then GameMath.CreatureName(creature) else "-"
end

-- Sub-panels ------------------------------------------------------------------------------------------

local function openBreed(creatureId: string)
	local data = DataController.Get()
	local creature = data and data.Creatures[creatureId]
	if not creature then
		return
	end
	local list = PanelController.Open("Breed", `Pair {GameMath.CreatureName(creature)} with...`)
	local order = 0
	for id, other in data.Creatures do
		local ok = id ~= creatureId and other.Species == creature.Species and other.Sex ~= creature.Sex and other.Stage == "Adult" and not other.CaptiveAt
		if ok then
			order += 1
			local row = Kit.Row(list, order, 56)
			Kit.Label({ Text = `{GameMath.CreatureName(other)} ({other.Sex}) Str {other.Traits.Str} Int {other.Traits.Int} End {other.Traits.End}`, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -90, 1, 0), ZIndex = 23, Parent = row })
			Kit.RowButton(row, 1, "Pair", C.Good, function()
				Remotes.Get("StartBreeding"):FireServer(creatureId, id)
				CreaturesPanel.Open()
			end)
		end
	end
	if order == 0 then
		label(list, "No partner yet: you need an Adult of the same species and the other sex.", 1, C.Muted)
	end
	order += 1
	Kit.Button({ Text = "Back", Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = C.PanelLight, LayoutOrder = order + 1, ZIndex = 22, Parent = list }, CreaturesPanel.Open)
end

local function openName(creatureId: string)
	local data = DataController.Get()
	local creature = data and data.Creatures[creatureId]
	if not creature then
		return
	end
	local list = PanelController.Open("Name", `Name {GameMath.CreatureName(creature)}`)
	local free = creature.Name == nil and creature.Stage == "Baby"
	label(list, if free then "Naming a new baby is free." else `Uses 1 Rename token (you have {data.Inventory.Items.rename or 0}).`, 1, C.Muted)
	local row = Kit.Row(list, 2, 56)
	local input = Kit.Input({ PlaceholderText = "New name", Size = UDim2.new(1, -96, 0, 40), Position = UDim2.fromOffset(0, 0), Parent = row })
	Kit.RowButton(row, 1, "Save", C.Good, function()
		if input.Text ~= "" then
			Remotes.Get("RenameCreature"):FireServer(creatureId, string.sub(input.Text, 1, Creatures.MaxNameLength))
			CreaturesPanel.Open()
		end
	end)
	Kit.Button({ Text = "Back", Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = C.PanelLight, LayoutOrder = 3, ZIndex = 22, Parent = list }, CreaturesPanel.Open)
end

local function openRecolor(creatureId: string)
	local list = PanelController.Open("Recolor", "Pick a color")
	for index, color in Creatures.RecolorPalette do
		local row = Kit.Row(list, index, 52)
		Kit.New("Frame", { Size = UDim2.fromOffset(36, 36), BackgroundColor3 = color, ZIndex = 23, Parent = row }, { Kit.Corner(18) })
		Kit.RowButton(row, 1, "Use", C.Good, function()
			Remotes.Get("RecolorCreature"):FireServer(creatureId, index)
			CreaturesPanel.Open()
		end)
	end
end

-- Cards -----------------------------------------------------------------------------------------------------

local function card(list: Instance, data: any, id: string, creature: any, order: number)
	local frame = Kit.New("Frame", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.PanelLight, LayoutOrder = order, ZIndex = 22, Parent = list }, {
		Kit.Corner(12),
		Kit.Padding(8),
		Kit.New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local species = Creatures.ById[creature.Species]
	local flags = {}
	if creature.Bonded then
		table.insert(flags, "Bonded")
	end
	if creature.CaptiveAt then
		table.insert(flags, "KIDNAPPED")
	end
	if (creature.HotUntil or 0) > Workspace:GetServerTimeNow() then
		table.insert(flags, "Hot")
	end
	local flagText = if #flags > 0 then "  [" .. table.concat(flags, ", ") .. "]" else ""
	label(frame, `{GameMath.CreatureName(creature)} - {species and species.Name or creature.Species}, {creature.Sex}, {creature.Stage}{flagText}`, 1, C.Coins, 17)

	local lifespan = GameMath.Lifespan(creature)
	local elderNote = if data.Unlocks.Elder then "" else " (aging pauses at Adult until stage 7)"
	label(frame, `Age {math.floor(creature.AgeMinutes)} / {math.floor(lifespan)} play min{elderNote}`, 2, C.Muted, 13)
	bar(frame, creature.AgeMinutes / lifespan, if creature.AgeMinutes / lifespan > Config.Lifecycle.WarnAtShare then C.Bad else C.Accent, 3)

	if data.Unlocks.Traits then
		local t = creature.Traits
		label(frame, `Strength {t.Str}   Intelligence {t.Int}   Endurance {t.End}`, 4)
		bar(frame, t.Str / 100, Color3.fromRGB(235, 110, 90), 5)
		bar(frame, t.Int / 100, Color3.fromRGB(110, 170, 255), 6)
		bar(frame, t.End / 100, Color3.fromRGB(110, 220, 120), 7)
	else
		label(frame, "Traits unlock at stage 4 (Family).", 4, C.Muted, 13)
	end

	local mutationNames = {}
	for _, mutationId in creature.Mutations do
		local mutation = Mutations.ById[mutationId]
		table.insert(mutationNames, if mutation then `{mutation.Name} ({mutation.Rarity})` else mutationId)
	end
	for _, power in creature.Powers or {} do
		table.insert(mutationNames, `Power: {power}`)
	end
	label(frame, `Role: {creature.Role or "none"}   Fed {math.floor(creature.Fed)}%   Mutations: {if #mutationNames > 0 then table.concat(mutationNames, ", ") else "none"}`, 8, C.Text, 13)
	label(frame, `Parents: {nameOf(data, creature.ParentA)} & {nameOf(data, creature.ParentB)}   Generation {creature.Generation or 1}`, 9, C.Muted, 13)

	local buttons = Kit.New("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 10, ZIndex = 23, Parent = frame }, {
		Kit.New("UIGridLayout", { CellSize = UDim2.fromOffset(96, 40), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local buttonOrder = 0
	local function button(text: string, color: Color3?, onClick: () -> ())
		buttonOrder += 1
		Kit.Button({ Text = text, TextSize = 14, BackgroundColor3 = color or C.Accent, LayoutOrder = buttonOrder, ZIndex = 24, Parent = buttons }, onClick)
	end

	if creature.CaptiveAt then
		label(frame, "Rescue it from the nest outside your west gate!", 11, C.Bad, 14)
		return
	end
	local roles = availableRoles(data, creature)
	if #roles > 0 then
		button(`Role: {creature.Role or "none"}`, C.Accent, function()
			local index = table.find(roles, creature.Role or "") or 0
			local nextRole = roles[index + 1]
			Remotes.Get("SetRole"):FireServer(id, nextRole or "")
		end)
	end
	if data.Unlocks.Breeding and creature.Stage == "Adult" then
		button("Breed", C.Good, function()
			openBreed(id)
		end)
	end
	if data.Unlocks.Training and (creature.Stage == "Young" or creature.Stage == "Baby") then
		button("Train", C.Good, function()
			PanelController.Close()
			TrainingGame.Start(id, GameMath.CreatureName(creature))
		end)
	end
	if (creature.Name == nil and creature.Stage == "Baby") or (data.Inventory.Items.rename or 0) > 0 then
		button("Name", C.PanelLight, function()
			openName(id)
		end)
	end
	if hasShelter(data) then
		button(if creature.InShelter then "Leave shelter" else "Shelter", C.PanelLight, function()
			Remotes.Get("SetShelter"):FireServer(id, not creature.InShelter)
		end)
	end
	if data.HeistFlag and not GameMath.IsProtected(creature) then
		button(if creature.InPen then "Out of pen" else "Heist Pen", Color3.fromRGB(150, 80, 170), function()
			Remotes.Get("SetPen"):FireServer(id, not creature.InPen)
		end)
	end
	if (data.Inventory.Items.recolor or 0) > 0 then
		button("Recolor", C.PanelLight, function()
			openRecolor(id)
		end)
	end
	if data.Unlocks.Essence and data.Essence >= Config.EssenceRerollCost then
		button(`Re-roll ({Config.EssenceRerollCost}E)`, C.Essence, function()
			Remotes.Get("RerollMutation"):FireServer(id)
		end)
	end
end

function CreaturesPanel.Open()
	local data = DataController.Get()
	if not data then
		return
	end
	local list = PanelController.Open("Creatures", "Creatures")
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local ids = {}
	for id in data.Creatures do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return GameMath.CreatureName(data.Creatures[a]) < GameMath.CreatureName(data.Creatures[b])
	end)
	Kit.Heading(list, `Your creatures ({#ids}/{Config.MaxCreatures})`, nextOrder())
	for _, id in ids do
		card(list, data, id, data.Creatures[id], nextOrder())
	end

	if next(data.Eggs) then
		Kit.Heading(list, "Eggs", nextOrder())
		for _, egg in data.Eggs do
			local species = Creatures.ById[egg.Species]
			local left = math.max(0, math.floor(egg.HatchAt - Workspace:GetServerTimeNow()))
			label(list, `{species and species.Name or egg.Species} egg - hatches in {left}s`, nextOrder())
		end
	end

	if data.Unlocks.Nests then
		Kit.Heading(list, `Nests ({GameMath.NestSlots(data)} slots)`, nextOrder())
		local any = false
		for _, nest in data.Nests do
			any = true
			if nest.MotherId then
				local left = math.max(0, Config.Breeding.GestationPlaySeconds - (data.PlaySeconds - (nest.StartedAt or 0)))
				label(list, `{nameOf(data, nest.MotherId)} + {nameOf(data, nest.FatherId)}: baby in {math.ceil(left / 60)} min`, nextOrder())
			else
				label(list, "Empty nest", nextOrder(), C.Muted)
			end
		end
		if not any then
			label(list, "Build a nest at the nest spots near your creature area.", nextOrder(), C.Muted)
		end
	end

	if data.Unlocks.Spirit then
		Kit.Heading(list, "Spirit Grove", nextOrder())
		local any = false
		for _, spirit in data.Spirits do
			any = true
			label(list, `{spirit.Name} - Legacy Trait {spirit.LegacyTrait}`, nextOrder())
		end
		if not any then
			label(list, "Creatures that pass on of old age become Spirits here and boost their bloodline.", nextOrder(), C.Muted)
		end
	end
end

function CreaturesPanel.Start()
	local last = 0
	DataController.Changed:Connect(function()
		if PanelController.IsOpen("Creatures") and os.clock() - last > 2 then
			last = os.clock()
			PanelController.Refresh("Creatures", CreaturesPanel.Open)
		end
	end)
end

return CreaturesPanel
