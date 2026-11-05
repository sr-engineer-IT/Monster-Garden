--!strict
-- Player attack input: tap/click a monster, press F, or use the Attack button.
-- The server checks range and cooldown; with no target it hits the nearest monster in range.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local player = Players.LocalPlayer

local CombatController = {}

local lastAttack = 0

function CombatController.Attack(monsterId: string?)
	local now = os.clock()
	if now - lastAttack < Config.PlayerAttack.CooldownSeconds then
		return
	end
	lastAttack = now
	require(script.Parent:WaitForChild("SoundController")).Play("Attack")
	Remotes.Get("PlayerAttack"):FireServer(monsterId)
end

local function monsterAt(screenPosition: Vector3): string?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 250, params)
	local current = result and result.Instance
	while current and current ~= Workspace do
		local id = current:GetAttribute("MonsterId")
		if type(id) == "string" then
			return id
		end
		current = current.Parent
	end
	return nil
end

function CombatController.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F then
			CombatController.Attack(nil)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local id = monsterAt(input.Position)
			if id then
				CombatController.Attack(id)
			end
		end
	end)
end

return CombatController
