--!strict
-- Local sky and lighting follow your own garden's phase (Build Spec section 4.2): each player can
-- be in day or night independently, so lighting is a client-only effect.
-- Night is a bright moonlit blue (spooky but readable), and your character carries a soft light so
-- crops, creatures and monsters near you are always visible.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Config"))

local player = Players.LocalPlayer

local LightingController = {}

local correction: ColorCorrectionEffect
local phaseNow: string = "Day"

type Look = {
	ClockTime: number,
	Brightness: number,
	OutdoorAmbient: Color3,
	Ambient: Color3,
	Exposure: number,
	Tint: Color3,
	Saturation: number,
	CarryLight: number, -- brightness of the light around your character
}

local LOOKS: { [string]: Look } = {
	Day = { ClockTime = 14, Brightness = 2.4, OutdoorAmbient = Color3.fromRGB(150, 150, 150), Ambient = Color3.fromRGB(90, 90, 100), Exposure = 0, Tint = Color3.new(1, 1, 1), Saturation = 0.12, CarryLight = 0 },
	Warning = { ClockTime = 18.2, Brightness = 1.8, OutdoorAmbient = Color3.fromRGB(150, 120, 130), Ambient = Color3.fromRGB(90, 80, 95), Exposure = 0, Tint = Color3.fromRGB(255, 225, 205), Saturation = 0.05, CarryLight = 0.6 },
	Night = { ClockTime = 21.5, Brightness = 1.2, OutdoorAmbient = Color3.fromRGB(120, 130, 185), Ambient = Color3.fromRGB(85, 90, 130), Exposure = 0.35, Tint = Color3.fromRGB(205, 215, 255), Saturation = -0.05, CarryLight = 1.4 },
}

local function carryLight(): PointLight?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local light = root:FindFirstChild("MoonGlow") :: PointLight?
	if not light then
		local new = Instance.new("PointLight")
		new.Name = "MoonGlow"
		new.Color = Color3.fromRGB(205, 220, 255)
		new.Range = 42
		new.Brightness = 0
		new.Shadows = false
		new.Parent = root
		light = new
	end
	return light
end

local function apply(phase: string?)
	phaseNow = phase or "Day"
	local look = LOOKS[phaseNow] or LOOKS.Day
	local seconds = if phase == "Warning" then Config.Night.WarningSeconds else 3
	if phase == "Day" and Lighting.ClockTime > 18 then
		Lighting.ClockTime = 6 -- sunrise, then brighten
	end
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, {
		ClockTime = look.ClockTime,
		Brightness = look.Brightness,
		OutdoorAmbient = look.OutdoorAmbient,
		Ambient = look.Ambient,
		ExposureCompensation = look.Exposure,
	}):Play()
	TweenService:Create(correction, info, { TintColor = look.Tint, Saturation = look.Saturation }):Play()
	local light = carryLight()
	if light then
		TweenService:Create(light, info, { Brightness = look.CarryLight }):Play()
	end
end

function LightingController.Start()
	correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "PhaseCorrection"
	correction.Parent = Lighting
	player:GetAttributeChangedSignal("Phase"):Connect(function()
		apply(player:GetAttribute("Phase"))
	end)
	-- new character after a respawn: give it the light for the current phase
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		local light = carryLight()
		if light then
			light.Brightness = (LOOKS[phaseNow] or LOOKS.Day).CarryLight
		end
	end)
	apply(player:GetAttribute("Phase"))
end

return LightingController
