--!strict
-- Garden decorations. Each one sits on a soil tile: that tile becomes garden instead of farm
-- (no crops grow there). Picking a decoration up gives it back and the soil returns.
-- Built by DecorService (real 3D model from assets/models when there is one, shapes otherwise).
-- Decorations are for looks only: they never change monsters, crops or coins.

export type Decor = {
	Id: string,
	Name: string,
	Icon: string,
	Cost: number, -- coins
	Essence: number?, -- extra Essence cost (rare pieces)
	MinLevel: number, -- Garden Level needed to buy it
	Info: string,
}

local Decor = {}

Decor.List = {
	{ Id = "grass", Name = "Grass Patch", Icon = "🌿", Cost = 25, MinLevel = 1, Info = "Turns soil back into soft grass" },
	{ Id = "path", Name = "Stone Path", Icon = "🪨", Cost = 60, MinLevel = 1, Info = "Stepping stones through your garden" },
	{ Id = "flowers", Name = "Flower Bed", Icon = "🌷", Cost = 80, MinLevel = 1, Info = "A bed of colorful flowers" },
	{ Id = "bush", Name = "Berry Bush", Icon = "🌳", Cost = 120, MinLevel = 2, Info = "A round green bush" },
	{ Id = "rock", Name = "Mossy Rock", Icon = "🪨", Cost = 150, MinLevel = 2, Info = "A big old rock" },
	{ Id = "mailbox", Name = "Mailbox", Icon = "📫", Cost = 250, MinLevel = 3, Info = "Every garden needs one" },
	{ Id = "bench", Name = "Garden Bench", Icon = "🪑", Cost = 300, MinLevel = 3, Info = "A place to rest" },
	{ Id = "lamp", Name = "Garden Lamp", Icon = "💡", Cost = 350, MinLevel = 4, Info = "Glows at night (just for looks)" },
	{ Id = "scarecrow", Name = "Scarecrow", Icon = "🎃", Cost = 400, MinLevel = 4, Info = "A friendly straw guard" },
	{ Id = "pond", Name = "Little Pond", Icon = "💧", Cost = 600, MinLevel = 5, Info = "Water with lily pads" },
	{ Id = "oak", Name = "Oak Tree", Icon = "🌳", Cost = 900, MinLevel = 6, Info = "A tall leafy tree" },
	{ Id = "pine", Name = "Pine Tree", Icon = "🌲", Cost = 900, MinLevel = 6, Info = "An evergreen tree" },
	{ Id = "well", Name = "Wishing Well", Icon = "🪣", Cost = 1200, MinLevel = 7, Info = "Make a wish!" },
	{ Id = "fountain", Name = "Fountain", Icon = "⛲", Cost = 3000, MinLevel = 10, Info = "A splashing stone fountain" },
	{ Id = "statue", Name = "Moon Statue", Icon = "🌙", Cost = 8000, Essence = 50, MinLevel = 15, Info = "A glowing moon on a marble stand" },
} :: { Decor }

Decor.ById = {} :: { [string]: Decor }
for _, decor in Decor.List do
	Decor.ById[decor.Id] = decor
end

Decor.PickUpHoldSeconds = 1 -- hold E this long to pick a decoration up (so it never happens by accident)
Decor.MinFarmTiles = 4 -- always keep at least this many soil tiles free for crops
Decor.MaxGardenPieces = 80 -- most decorations on the grass at once (keeps the server fast)

return Decor
