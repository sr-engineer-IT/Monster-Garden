--!strict
-- Holds the latest profile snapshot sent by the server. Display only: changing it does nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))

local DataController = {}

DataController.Changed = Signal.new() :: Signal.Signal<any>

local snapshot: any = nil

function DataController.Start()
	Remotes.Get("DataSync").OnClientEvent:Connect(function(data)
		snapshot = data
		DataController.Changed:Fire(data)
	end)
	-- Ask for a fresh copy in case the first sync arrived before we listened
	Remotes.Get("RequestSync"):FireServer()
end

function DataController.Get(): any
	return snapshot
end

return DataController
