--!strict
-- Plays sound effects for game events and loops day / night / Feast music (client only).
-- Respects the player's Sound setting. Sound ids live in Config/Sounds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Sounds"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local DataController = require(script.Parent:WaitForChild("DataController"))

local player = Players.LocalPlayer

local SoundController = {}

local effects: { [string]: Sound } = {}
local music: Sound
local currentTrack = ""
local feastActive = false

local function soundOn(): boolean
	local data = DataController.Get()
	return data == nil or data.Settings == nil or data.Settings.SoundOn ~= false
end

function SoundController.Play(name: string)
	local sound = effects[name]
	if sound and soundOn() then
		sound:Play()
	end
end

local function updateMusic()
	local track = if feastActive then "Feast" elseif player:GetAttribute("Phase") == "Night" then "Night" else "Day"
	local id = (Sounds.Music :: any)[track] or ""
	if not soundOn() then
		id = ""
	end
	if id == currentTrack then
		return
	end
	currentTrack = id
	music:Stop()
	if id ~= "" then
		music.SoundId = id
		music:Play()
	end
end

function SoundController.Start()
	local folder = Instance.new("Folder")
	folder.Name = "GameSounds"
	folder.Parent = SoundService
	for name, id in Sounds.Effects :: any do
		if id ~= "" then
			local sound = Instance.new("Sound")
			sound.Name = name
			sound.SoundId = id
			sound.Volume = Sounds.Volume.Effects
			sound.Parent = folder
			effects[name] = sound
		end
	end
	music = Instance.new("Sound")
	music.Name = "Music"
	music.Looped = true
	music.Volume = Sounds.Volume.Music
	music.Parent = folder

	Remotes.Get("UnlockBanner").OnClientEvent:Connect(function()
		SoundController.Play("Banner")
	end)
	Remotes.Get("NightWarning").OnClientEvent:Connect(function()
		SoundController.Play("NightWarning")
	end)
	Remotes.Get("MutationEarned").OnClientEvent:Connect(function()
		SoundController.Play("Mutation")
	end)
	Remotes.Get("CrateOpened").OnClientEvent:Connect(function()
		SoundController.Play("Crate")
	end)
	Remotes.Get("Notify").OnClientEvent:Connect(function(payload)
		local text = payload and payload.Text or ""
		if string.sub(text, 1, 2) == "+1" then
			SoundController.Play("Harvest")
		elseif string.sub(text, 1, 7) == "Sold fo" then
			SoundController.Play("Sell")
		end
	end)
	Remotes.Get("FeastUpdate").OnClientEvent:Connect(function(payload)
		feastActive = payload ~= nil and payload.Phase == "Active"
		updateMusic()
	end)
	player:GetAttributeChangedSignal("GardenLevel"):Connect(function()
		SoundController.Play("LevelUp")
	end)
	player:GetAttributeChangedSignal("Phase"):Connect(updateMusic)
	DataController.Changed:Connect(updateMusic)
	updateMusic()
end

return SoundController
