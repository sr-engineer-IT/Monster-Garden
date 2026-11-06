--!strict
-- Monster behavior per frame (Build Spec sections 8, 10.3, 14.1). Straight-line movement:
-- night monsters walk to a gate, break a standing fence (Burrowers skip it once), then pick a
-- crop or creature by weight. Stalkers grab a creature and run; Brutes and Elders can eat an
-- injured creature from stage 5. Guards stay by their nest; the Alpha roams between gardens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Defenses = require(ConfigFolder:WaitForChild("Defenses"))
local Monsters = require(ConfigFolder:WaitForChild("Monsters"))
local Util = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"))

local S = require(script.Parent.Parent.Parent.Registry)
local Assets = require(script.Parent.Parent.Parent.Assets)
local Rig = require(script.Parent.Parent.Parent.Rig)

local AI = {}

local function groundY(size: number): number
	return Config.World.GroundY + 0.2 + size / 2
end

local function flat(a: Vector3, b: Vector3): Vector3
	return Vector3.new(b.X - a.X, 0, b.Z - a.Z)
end

-- Moves toward goal; returns true when within reach
local function moveTo(m: any, goal: Vector3, speed: number, dt: number, reach: number): boolean
	local offset = flat(m.Position, goal)
	local distance = offset.Magnitude
	if distance <= reach then
		return true
	end
	m.Facing = offset.Unit
	local step = math.min(distance - reach * 0.5, speed * dt)
	m.Position = Vector3.new(m.Position.X + m.Facing.X * step, groundY(m.Size), m.Position.Z + m.Facing.Z * step)
	return false
end

local function pickTarget(m: any): boolean
	local candidates = {}
	local weights: { [number]: number } = {}
	local isStalker = m.Def.Grabs == true
	if not isStalker then
		for _, crop in S.CropService.GetTargets(m.Owner) do
			table.insert(candidates, { Kind = "Crop", Id = crop.TileId })
			weights[#candidates] = crop.Weight
		end
	end
	local options = { ForStalker = isStalker, IncludeEdible = m.CanEat == true }
	for _, creature in S.CreatureService.GetTargets(m.Owner, options) do
		table.insert(candidates, { Kind = "Creature", Id = creature.Id })
		weights[#candidates] = creature.Weight
	end
	local index = Util.WeightedPick(weights)
	if index == nil then
		return false
	end
	m.TargetKind = candidates[index].Kind
	m.TargetId = candidates[index].Id
	return true
end

local function targetPosition(m: any): Vector3?
	local owner, id = m.Owner, m.TargetId
	if m.TargetKind == "Crop" then
		if not S.CropService.HasCrop(owner, id) then
			return nil
		end
		local tile = S.PlotService.GetTilePart(owner, id)
		return if tile then tile.Position else nil
	end
	return S.CreatureService.GetPosition(owner, id)
end

local function checkTraps(m: any, ctx: any)
	for _, trap in S.DefenseService.TrapsNear(m.Owner, m.Position) do
		if not m.TrapChecked[trap.SlotId] then
			m.TrapChecked[trap.SlotId] = true
			local avoid = math.max(m.Def.TrapAvoidChance or 0, m.Int / Monsters.Traits.Divisor)
			if not Util.Chance(avoid) then
				local damage, radius = S.DefenseService.ConsumeTrap(m.Owner, trap.SlotId)
				if damage > 0 then
					ctx.AreaDamage(m.Owner, trap.Position, radius, damage)
				end
			end
		end
	end
end

local function updateNight(m: any, night: any, dt: number, ctx: any)
	local owner = m.Owner
	local def = m.Def
	local speed = m.Speed
	local lit = S.DefenseService.IsLit(owner, m.Position)
	if lit then
		speed *= Defenses.ById.lantern.MonsterSpeedMult or 1
		if not m.LightChecked and m.State ~= "Retreat" and m.State ~= "Escape" then
			m.LightChecked = true
			if def.LanternRetreatChance and Util.Chance(def.LanternRetreatChance) then
				m.State = "Retreat"
				ctx.DrivenAway(m, night)
			end
		end
	end
	if m.Ability == "Shadowed" then
		local transparency = if lit then 0 else 0.85
		local art = m.Model:FindFirstChild("Art")
		if art then
			-- with a real model the Body is an invisible hit box; fade the art instead
			local first = art:FindFirstChildWhichIsA("BasePart", true)
			if first and first.Transparency ~= transparency then
				Assets.SetTransparency(art, transparency)
			end
		else
			local look = Rig.Look(m.Model, m.Body)
			if look ~= m.Body and look.Transparency ~= transparency then
				look.Transparency = transparency
			end
		end
	end
	if S.PlotService.IsInsideOwnerPlot(owner, m.Position) then
		checkTraps(m, ctx)
		if m.Health <= 0 then
			return
		end
	end

	local state = m.State
	if state == "Retreat" then
		if moveTo(m, m.Spawn, speed * 1.3, dt, 1) then
			ctx.Despawn(m)
		end
	elseif state == "Escape" then
		local goal = if m.EscapeStep == 1 then (S.DefenseService.GetGatePosition(owner, m.Gate) or m.Spawn) else m.Spawn
		if moveTo(m, goal, def.CarrySpeed or speed, dt, 1.5) then
			if m.EscapeStep == 1 then
				m.EscapeStep = 2
			else
				ctx.Escaped(m)
			end
		end
	elseif state == "Approach" then
		local gatePosition = S.DefenseService.GetGatePosition(owner, m.Gate)
		if not gatePosition or moveTo(m, gatePosition, speed, dt, 2 + m.Size / 2) then
			local blocked = S.DefenseService.IsGateBlocked(owner, m.Gate)
			if blocked and m.Ability == "Burrower" and not m.BurrowUsed then
				m.BurrowUsed = true
				blocked = false
			end
			m.State = if blocked then "Breach" else "Seek"
			m.Timer = 0
		end
	elseif state == "Breach" then
		local damage = m.Damage * (def.FenceDamageMult or 1) * ctx.HowlMult(m) * dt
		if S.DefenseService.DamageGate(owner, m.Gate, damage) then
			m.State, m.Timer = "Seek", 0
		end
	elseif state == "Seek" or state == "Idle" then
		m.Timer -= dt
		if m.Timer <= 0 then
			m.Timer = 1
			m.State = if pickTarget(m) then "Move" else "Idle"
		end
		if m.State == "Idle" then
			local plot = S.PlotService.GetPlot(owner)
			if plot then
				moveTo(m, plot.Center, speed * 0.5, dt, 6)
			end
		end
	elseif state == "Move" or state == "Attack" then
		local goal = targetPosition(m)
		if goal == nil then
			m.State, m.Timer = "Seek", 0
			return
		end
		if not moveTo(m, goal, speed, dt, m.Size / 2 + 2) then
			m.State = "Move"
			return
		end
		if m.State ~= "Attack" then
			m.State, m.Timer = "Attack", 0
		end
		if m.TargetKind == "Crop" then
			m.Timer += dt
			if m.Timer >= Config.MonsterEatSeconds then
				S.CropService.EatCrop(owner, m.TargetId)
				m.Ate = true
				night.Ate += 1
				m.State, m.Timer = "Seek", 0
			end
		elseif def.Grabs then
			ctx.Grab(m, m.TargetId)
		elseif S.CreatureService.IsInjured(owner, m.TargetId) then
			-- Only reached when the creature is edible (see GetTargets)
			m.Timer += dt
			if m.Timer >= Config.MonsterEatSeconds then
				ctx.EatCreature(m, night, m.TargetId)
				m.State, m.Timer = "Seek", 0
			end
		elseif S.CreatureService.Damage(owner, m.TargetId, m.Damage * ctx.HowlMult(m) * dt) and not m.CanEat then
			m.State, m.Timer = "Seek", 0
		end
	end
end

local function updateGuard(m: any, dt: number, clock: number)
	-- Wander slowly around the nest
	if (m.WanderGoal == nil) or flat(m.Position, m.WanderGoal).Magnitude < 1 then
		local angle = math.random() * math.pi * 2
		m.WanderGoal = m.Anchor + Vector3.new(math.cos(angle), 0, math.sin(angle)) * math.random(2, 7)
	end
	moveTo(m, m.WanderGoal, m.Speed * 0.3, dt, 0.5)
end

local function updateAlpha(m: any, dt: number, ctx: any)
	local alpha = Monsters.Alpha
	local plot = m.TargetPlot
	if not plot then
		return
	end
	if not moveTo(m, plot.Center, m.Speed, dt, 8) then
		return
	end
	m.Timer -= dt
	if m.Timer > 0 then
		return
	end
	m.Timer = 1
	local owner = plot.Owner
	if not owner then
		return
	end
	m.Owner = owner
	-- Smash a gate fence and injure creatures nearby
	S.DefenseService.DamageGate(owner, ({ "N", "E", "S", "W" })[math.random(1, 4)], alpha.DamagePerSecond)
	for _, target in S.CreatureService.GetTargets(owner) do
		if flat(m.Position, target.Position).Magnitude <= alpha.AttackRadius then
			S.CreatureService.Damage(owner, target.Id, alpha.DamagePerSecond)
		end
	end
	ctx.AlphaTick(m)
end

function AI.Update(m: any, night: any, dt: number, clock: number, ctx: any)
	if m.Kind == "Guard" then
		updateGuard(m, dt, clock)
	elseif m.Kind == "Alpha" then
		updateAlpha(m, dt, ctx)
	elseif night or m.State == "Retreat" or m.State == "Escape" then
		updateNight(m, night or { Ate = 0, Repelled = 0 }, dt, ctx)
	else
		m.State = "Retreat"
	end

	if m.Model.Parent then
		-- waddle and bob are animated smoothly on each player's screen (AnimationController)
		local position = m.Position
		m.Model:PivotTo(CFrame.lookAt(position, position + m.Facing))
	end
end

return AI
