--!strict
-- Shows prompts only where they apply: prompts inside a garden show for its owner (or for everyone
-- when marked Public, like shop stalls and Heist Pens); prompts the server marked Hidden stay off.
-- This is display only: the server checks every trigger anyway.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local PromptController = {}

local function plotOf(instance: Instance): Instance?
	local current = instance.Parent
	while current and current ~= Workspace do
		if current:GetAttribute("PlotIndex") ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function update(prompt: ProximityPrompt)
	local plot = plotOf(prompt)
	local allowed = true
	if plot and prompt:GetAttribute("Public") ~= true then
		allowed = plot:GetAttribute("OwnerUserId") == player.UserId
	end
	prompt.Enabled = allowed and prompt:GetAttribute("Hidden") ~= true
end

local function watch(prompt: ProximityPrompt)
	prompt:GetAttributeChangedSignal("Hidden"):Connect(function()
		update(prompt)
	end)
	prompt:GetAttributeChangedSignal("Public"):Connect(function()
		update(prompt)
	end)
	update(prompt)
end

function PromptController.Start()
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			watch(descendant)
		end
	end
	Workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			watch(descendant)
		end
	end)
	local plots = Workspace:WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			for _, descendant in plot:GetDescendants() do
				if descendant:IsA("ProximityPrompt") then
					update(descendant)
				end
			end
		end)
	end
end

return PromptController
