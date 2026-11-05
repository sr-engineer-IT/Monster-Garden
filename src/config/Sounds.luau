--!strict
-- Sound effects and music (Build Spec section 19). Paste a sound id ("rbxassetid://123...") into
-- any empty slot to turn it on; empty slots stay silent. Use only sounds you own or are allowed
-- to use (Creator Store audio marked free to use), and record them in Resources/Asset-Log.csv.

local Sounds = {}

Sounds.Volume = {
	Effects = 0.6,
	Music = 0.3,
}

Sounds.Effects = {
	Banner = "rbxasset://sounds/electronicpingshort.wav", -- unlocks, gifts, stage banners
	Harvest = "",
	Sell = "",
	Attack = "",
	LevelUp = "",
	NightWarning = "", -- warning horn
	Mutation = "", -- mutation chime
	Hatch = "",
	Crate = "",
}

Sounds.Music = {
	Day = "", -- day ambience
	Night = "", -- night ambience
	Feast = "", -- Feast Night music
}

return Sounds
