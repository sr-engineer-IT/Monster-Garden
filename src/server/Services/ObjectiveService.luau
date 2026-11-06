--!strict
-- ObjectiveService: the goal chain shown at the top of the screen (design doc section 6,
-- Build Spec section 22). Event goals count events; Stat goals read a profile number.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Objectives = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Objectives"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local S = require(script.Parent.Parent.Registry)

local ObjectiveService = {}

local function check(player: Player, data: any)
	while true do
		local objective = Objectives.List[data.ObjectiveIndex]
		if objective == nil then
			break
		end
		if objective.Stat then
			data.ObjectiveProgress = data[objective.Stat] or 0
		end
		if data.ObjectiveProgress < objective.Count then
			break
		end
		-- Advance before rewarding: the reward can level up and re-enter check()
		data.ObjectiveIndex += 1
		data.ObjectiveProgress = 0
		Remotes.Get("Notify"):FireClient(player, { Text = `Goal complete: {objective.Text} (+{objective.XP} XP)`, Kind = "Goal" })
		S.ProgressionService.AddXP(player, objective.XP, "Objective")
	end
	S.DataService.MarkChanged(player)
end

function ObjectiveService.Progress(player: Player, event: string, amount: number?)
	S.QuestService.Progress(player, event, amount) -- daily / weekly quests count the same events
	local data = S.DataService.GetData(player)
	local objective = data and Objectives.List[data.ObjectiveIndex]
	if not data or not objective or objective.Event ~= event then
		return
	end
	data.ObjectiveProgress += amount or 1
	check(player, data)
end

-- Re-check Stat goals (after level ups and nights)
function ObjectiveService.Refresh(player: Player)
	local data = S.DataService.GetData(player)
	if data then
		check(player, data)
	end
end

function ObjectiveService.Init() end

function ObjectiveService.Start()
	S.DataService.ProfileLoaded:Connect(function(player: Player, data: any)
		check(player, data)
	end)
end

return ObjectiveService
