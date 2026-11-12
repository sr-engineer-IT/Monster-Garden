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
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
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
				-- tell the owner, so it does not look like a bug
				Remotes.Get("Notify"):FireClient(owner, { Text = "An Elder Burrower dug UNDER your gate! Elders can do that once." })
			end
			m.State = if blocked then "Breach" else "Seek"
			m.Timer = 0
		end
	elseif state == "Breach" then
		local damage = m.Damage * (def.FenceDamageMult or 1) * ctx.HowlMult(m) * dt
		if S.DefenseService.DamageGate(owner, m.Gate, damage) then
			m.State, m.Timer = "Seek", 0
		else
			-- Iron / Moon Gate spikes hurt the monster while it breaks the gate (applied once a second)
			local thorns = S.DefenseService.GateThorns(owner, m.Gate)
			if thorns > 0 then
				m.ThornTimer = (m.ThornTimer or 0) + dt
				if m.ThornTimer >= 1 then
					m.ThornTimer -= 1
					S.MonsterService.DamageMonster(m.Id, thorns, nil)
				end
			end
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
		-- a little extra reach once attacking, so being nudged by a neighbor does not make it twitch
		local reach = m.Size / 2 + 2 + (if m.State == "Attack" then 2.5 else 0)
		if not moveTo(m, goal, speed, dt, reach) then
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

-- Studio /parade: walk in a slow circle around a point (to check which way monster models face)
local function updateParade(m: any, dt: number)
	m.Phase = (m.Phase or 0) + dt * 0.3
	local goal = m.Anchor + Vector3.new(math.cos(m.Phase), 0, math.sin(m.Phase)) * (m.Radius or 16)
	moveTo(m, goal, m.Speed * 0.6, dt, 0.3)
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
	if m.Kind == "Parade" then
		updateParade(m, dt)
	elseif m.Kind == "Guard" then
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
		-- turn smoothly instead of snapping to each new direction
		local look = (m.Look or m.Facing):Lerp(m.Facing, math.min(1, dt * 8))
		if look.Magnitude < 0.05 then
			look = m.Facing
		end
		m.Look = look.Unit
		local position = m.Position
		m.Model:PivotTo(CFrame.lookAt(position, position + m.Look))
	end
end

-- Half the visible width of a monster (3D models can be longer than the round hit box)
local function footprint(m: any): number
	if m.Footprint == nil then
		local art = m.Model:FindFirstChild("Art")
		local width = m.Size * 0.6
		if art and art:IsA("Model") then
			local ok, _, size = pcall(Assets.Bounds, art)
			if ok and size then
				width = math.max(width, math.max(size.X, size.Z) * 0.45)
			end
		end
		m.Footprint = width
	end
	return m.Footprint
end

local SETTLED = { Breach = true, Attack = true }

-- Keep monsters in the same garden from melting into one blob (run once per frame after Update).
-- Monsters busy at a gate or target are pushed less, so walkers flow around them.
function AI.Separate(list: { [string]: any }, dt: number)
	local byOwner: { [any]: { any } } = {}
	for _, m in list do
		if m.Owner and m.Kind == "Night" and m.State ~= "Escape" then
			local group = byOwner[m.Owner]
			if not group then
				group = {}
				byOwner[m.Owner] = group
			end
			table.insert(group, m)
		end
	end
	for _, group in byOwner do
		for i = 1, #group do
			local a = group[i]
			for j = i + 1, #group do
				local b = group[j]
				local away = Vector3.new(a.Position.X - b.Position.X, 0, a.Position.Z - b.Position.Z)
				local need = footprint(a) + footprint(b) + 0.5
				local gap = away.Magnitude
				if gap < need then
					local dir = if gap > 0.05 then away.Unit else Vector3.new(math.cos(i + j), 0, math.sin(i + j))
					local push = math.min(need - gap, 10 * dt)
					local aSettled, bSettled = SETTLED[a.State] == true, SETTLED[b.State] == true
					local aShare = if aSettled == bSettled then 0.5 elseif aSettled then 0.2 else 0.8
					a.Position += dir * push * aShare
					b.Position -= dir * push * (1 - aShare)
				end
			end
		end
	end
end

return AI
