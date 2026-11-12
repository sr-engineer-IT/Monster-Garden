--!strict
-- Upgrade Station (one workbench in every garden). Permanent player upgrades bought with coins.
-- Kept through Rebirth. Effects:
--   Grow:  crops grow PerLevel faster per level (stacks with soil level)
--   Speed: walk speed +PerLevel studs/second per level (Roblox default is 16)
--   Yield: PerLevel chance per level to get 1 extra crop on each harvest

export type Upgrade = {
	Id: string,
	Name: string,
	Icon: string,
	PerLevel: number,
	Costs: { number }, -- coins for level 1, 2, 3, ...
	MinLevels: { number }, -- Garden Level needed for level 1, 2, 3, ...
}

local Upgrades = {}

Upgrades.List = {
	{ Id = "Grow", Name = "Green Thumb", Icon = "🌱", PerLevel = 0.06, Costs = { 300, 900, 2500, 6000, 15000 }, MinLevels = { 2, 4, 7, 10, 15 } },
	{ Id = "Speed", Name = "Swift Boots", Icon = "👟", PerLevel = 2, Costs = { 200, 600, 1500, 4000, 10000 }, MinLevels = { 1, 3, 6, 9, 12 } },
	{ Id = "Yield", Name = "Big Harvest", Icon = "🧺", PerLevel = 0.08, Costs = { 400, 1200, 3500, 8000, 20000 }, MinLevels = { 3, 5, 8, 12, 18 } },
} :: { Upgrade }

Upgrades.ById = {} :: { [string]: Upgrade }
for _, upgrade in Upgrades.List do
	Upgrades.ById[upgrade.Id] = upgrade
end

Upgrades.BaseWalkSpeed = 16

-- Short text for what a level does ("Crops grow 12% faster")
function Upgrades.EffectText(id: string, level: number): string
	local upgrade = Upgrades.ById[id]
	if not upgrade or level <= 0 then
		return "No bonus yet"
	end
	if id == "Grow" then
		return `Crops grow {math.floor(upgrade.PerLevel * level * 100 + 0.5)}% faster`
	elseif id == "Speed" then
		return `Walk speed {Upgrades.BaseWalkSpeed + upgrade.PerLevel * level} (normal {Upgrades.BaseWalkSpeed})`
	end
	return `{math.floor(upgrade.PerLevel * level * 100 + 0.5)}% chance of +1 crop per harvest`
end

return Upgrades
