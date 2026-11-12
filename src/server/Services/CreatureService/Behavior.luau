--!strict
-- Creature movement and jobs, run 10 times a second by CreatureService:
-- injured creatures rest, sheltered and penned creatures stay put, Guardians and Monster Hunters
-- fight nearby monsters, Farmers walk to ready crops and harvest them, others follow the owner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Creatures = require(ConfigFolder:WaitForChild("Creatures"))
local GameMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameMath"))

local S = require(script.Parent.Parent.Parent.Registry)

local Behavior = {}

local FIGHT_SEARCH_RADIUS = 30

function Behavior.GroundY(size: number): number
	return Config.World.GroundY + 0.2 + size / 2
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Damage multiplier from nearby Guardians (section 7.4) and Guardian Instinct (section 12.3)
function Behavior.GuardianReduction(data: any, list: { [string]: any }, targetId: string, position: Vector3): number
	local mult = 1
	local guardian, instinct = false, false
	local range = Creatures.Roles.Guardian.Range or 15
	for id, runtime in list do
		local other = data.Creatures[id]
		if id ~= targetId and other and other.InjuredUntil == 0 and flatDistance(runtime.Position, position) <= range then
			if other.Role == "Guardian" then
				guardian = true
			end
			if table.find(other.Mutations, "GuardianInstinct") then
				instinct = true
			end
		end
	end
	if guardian then
		mult *= 1 - (Creatures.Roles.Guardian.DamageReduction or 0)
	end
	if instinct then
		mult *= 0.85
	end
	return mult
end

local function fight(player: Player, data: any, creature: any, runtime: any, dt: number): Vector3?
	if not Creatures.FighterRoles[creature.Role or ""] or creature.Stage == "Baby" then
		return nil
	end
	local monsterId, monsterPosition = S.MonsterService.FindNearest(player, runtime.Position, FIGHT_SEARCH_RADIUS)
	if not monsterId or not monsterPosition then
		return nil
	end
	runtime.AttackTimer -= dt
	if runtime.AttackTimer <= 0 and flatDistance(runtime.Position, monsterPosition) <= Config.CreatureAutoAttack.Range then
		runtime.AttackTimer = Config.CreatureAutoAttack.IntervalSeconds
		local damage = GameMath.CreatureAttack(creature) * (if creature.Stage == "Elder" then Config.Lifecycle.ElderDefenseMult else 1)
		local killed = S.MonsterService.DamageMonster(monsterId, damage, nil)
		if killed then
			creature.Kills = (creature.Kills or 0) + 1
			creature.Repelled = (creature.Repelled or 0) + 1
		end
	end
	return monsterPosition
end

local function farm(player: Player, data: any, creature: any, runtime: any, dt: number): Vector3?
	if creature.Role ~= "Farmer" or creature.Stage == "Baby" or creature.Fed < Config.Fed.StopWorkBelow then
		return nil
	end
	local tileId, tilePosition = S.CropService.FindReadyTile(player, runtime.Position)
	if not tileId or not tilePosition then
		return nil
	end
	local farmer = Creatures.Roles.Farmer
	runtime.FarmTimer -= dt
	if runtime.FarmTimer <= 0 and flatDistance(runtime.Position, tilePosition) <= (farmer.Range or 12) then
		local efficiency = 1 + creature.Traits.Int / Creatures.TraitEffects.JobEfficiencyIntDivisor
		runtime.FarmTimer = (farmer.IntervalSeconds or 10) / efficiency
		S.CropService.AutoHarvest(player, tileId)
	end
	return tilePosition
end

function Behavior.Tick(player: Player, data: any, plot: any, list: { [string]: any }, dt: number, clock: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local ownerPos = if root and S.PlotService.IsInside(plot, root.Position) then root.Position else nil
	-- While the owner works the crops, followers wait off the field so they never block harvesting
	local ownerOnField = ownerPos ~= nil and S.PlotService.IsOnField(plot, ownerPos, 2)

	local index = 0
	for id, runtime in list do
		index += 1
		local creature = data.Creatures[id]
		if creature then
			local angle = index * 2.1
			local ring = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local goal: Vector3 = runtime.Position
			local speed = Config.CreatureMove.Speed * (if creature.Stage == "Baby" then 0.6 else 1)

			if player:GetAttribute("DevFollow") and root then
				-- Studio /follow: every creature walks after you in rows of 3 (to check which way models face)
				local row, col = (index - 1) // 3, (index - 1) % 3
				local back = root.CFrame.LookVector * Vector3.new(1, 0, 1)
				local side = root.CFrame.RightVector * Vector3.new(1, 0, 1)
				goal = root.Position - back * (7 + row * 7) + side * ((col - 1) * 7)
			elseif creature.InjuredUntil ~= 0 then
				goal = runtime.Position
			elseif creature.InShelter then
				goal = plot.Center + Config.World.ShelterSpot + ring * 1.5
			elseif creature.InPen then
				goal = S.HeistService.GetPenPosition(player, id) or runtime.Position
			elseif S.BreedingService.GetNestPosition(player, id) then
				goal = S.BreedingService.GetNestPosition(player, id) :: Vector3
			else
				local fightGoal = fight(player, data, creature, runtime, dt)
				local farmGoal = if fightGoal then nil else farm(player, data, creature, runtime, dt)
				if fightGoal then
					goal = fightGoal
				elseif farmGoal then
					goal = farmGoal
				elseif ownerOnField then
					-- step off the soil if standing on it, otherwise wait where it is
					goal = if S.PlotService.IsOnField(plot, runtime.Position, 1) then plot.Center + Config.World.CreatureHome + ring * 4 else runtime.Position
				elseif ownerPos and flatDistance(ownerPos, runtime.Position) < Config.CreatureMove.FollowRadius then
					-- Walk after the owner, but stay put once close so the owner can walk up and pet it
					goal = if flatDistance(ownerPos, runtime.Position) > Config.CreatureMove.FollowStartDistance then ownerPos + ring * Config.CreatureMove.FollowOffset else runtime.Position
				else
					goal = plot.Center + Config.World.CreatureHome + ring * 4
				end
			end

			local flat = Vector3.new(goal.X - runtime.Position.X, 0, goal.Z - runtime.Position.Z)
			local moving = flat.Magnitude > 1.5
			local position = runtime.Position
			if moving then
				runtime.Facing = flat.Unit
				position += flat.Unit * math.min(flat.Magnitude - 1, speed * dt)
			end
			-- Keep a little space between creatures so they never melt into one blob
			if not creature.InShelter and not creature.InPen then
				for otherId, other in list do
					if otherId ~= id then
						local away = Vector3.new(position.X - other.Position.X, 0, position.Z - other.Position.Z)
						-- use the size of what you SEE (3D models are often much longer than the hit box)
						local need = (runtime.Footprint or runtime.Size * 0.6) + (other.Footprint or other.Size * 0.6) + 0.6
						local gap = away.Magnitude
						if gap < need then
							local push = if gap > 0.05 then away.Unit else Vector3.new(math.cos(index), 0, math.sin(index))
							position += push * math.min(need - gap, speed * dt) * 0.5
						end
					end
				end
			end
			-- Settle back to the ground (hopping is animated smoothly on each player's screen)
			local targetY = Behavior.GroundY(runtime.Size)
			position = Vector3.new(position.X, position.Y + (targetY - position.Y) * math.min(1, dt * 8), position.Z)
			runtime.Position = position

			local cf = CFrame.lookAt(position, position + runtime.Facing)
			if creature.InjuredUntil ~= 0 then
				cf *= CFrame.Angles(0, 0, math.rad(80)) -- lying down
			end
			runtime.Model:PivotTo(cf)
		end
	end
end

return Behavior
