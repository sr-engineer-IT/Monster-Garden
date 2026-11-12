--!strict
-- Upgrade Station panel (opened by the workbench in your garden): permanent coin upgrades.
-- Display only: the server checks the station distance, Garden Level and coins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Upgrades = require(ConfigFolder:WaitForChild("Upgrades"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("UI"):WaitForChild("Kit"))
local DataController = require(Client:WaitForChild("Controllers"):WaitForChild("DataController"))
local PanelController = require(Client:WaitForChild("Controllers"):WaitForChild("PanelController"))

local C = Kit.Colors

local UpgradesPanel = {}

function UpgradesPanel.Open()
	local data = DataController.Get()
	if not data then
		return
	end
	local list = PanelController.Open("Upgrades", `{Kit.Icons.Upgrades} Upgrade Station`)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	Kit.Label({ Text = "Upgrades last forever, even after a Rebirth.", TextSize = 14, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = nextOrder(), ZIndex = 22, Parent = list })

	for _, upgrade in Upgrades.List do
		local level = GameMath.UpgradeLevel(data, upgrade.Id)
		local maxLevel = #upgrade.Costs
		local nextLevel = level + 1
		local cost = upgrade.Costs[nextLevel]
		local row = Kit.Row(list, nextOrder(), 100)
		Kit.Label({ Text = `{upgrade.Icon} {upgrade.Name}   Lv {level}/{maxLevel}`, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -150, 0, 24), ZIndex = 23, Parent = row })
		local _, fill = Kit.Bar({ Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, -150, 0, 12), ZIndex = 23, Parent = row }, C.Good)
		Kit.SetBar(fill, level / maxLevel)
		Kit.Label({ Text = `Now: {Upgrades.EffectText(upgrade.Id, level)}`, TextSize = 14, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, -150, 0, 18), ZIndex = 23, Parent = row })
		if cost then
			Kit.Label({ Text = `Next: {Upgrades.EffectText(upgrade.Id, nextLevel)}`, TextSize = 14, TextColor3 = C.Coins, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, -150, 0, 18), ZIndex = 23, Parent = row })
			local minLevel = upgrade.MinLevels[nextLevel] or 1
			if data.GardenLevel < minLevel then
				Kit.RowButton(row, 1, `{Kit.Icons.Lock} Lv {minLevel}`, C.Locked, function() end, 134)
			else
				Kit.RowButton(row, 1, `{Kit.Icons.Coins} {Util.FormatNumber(cost)}`, if data.Coins >= cost then C.Good else C.Locked, function()
					Remotes.Get("BuyUpgrade"):FireServer(upgrade.Id)
				end, 134)
			end
		else
			Kit.Chip({ Text = `{Kit.Icons.Check} MAX`, TextSize = 16, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(134, 42), BackgroundColor3 = C.Locked, TextColor3 = C.Good, ZIndex = 23, Parent = row })
		end
	end
end

function UpgradesPanel.Start()
	Remotes.Get("OpenUpgrades").OnClientEvent:Connect(UpgradesPanel.Open)
	-- trailing refresh: always shows the newest snapshot, at most a few times a second
	local pending = false
	DataController.Changed:Connect(function()
		if pending then
			return
		end
		pending = true
		task.delay(0.25, function()
			pending = false
			PanelController.Refresh("Upgrades", UpgradesPanel.Open)
		end)
	end)
end

return UpgradesPanel
