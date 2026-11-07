--!strict
-- Daily Puzzles: three optional puzzles every day (UTC), each with a small reward.
--   Riddle      read a riddle, pick the right answer (4 choices)
--   OddOneOut   four things, one does not belong
--   Memory      flip cards and match the pairs
-- Every player gets their own puzzles each day (picked from these lists). Add more any time.

local Puzzles = {}

Puzzles.Reward = { CoinMinutes = 3, SeasonXP = 25 } -- per puzzle (coins scale with level)
Puzzles.AllDoneBonus = { CoinMinutes = 4, SeasonXP = 40 }
Puzzles.MemoryPairs = 6 -- 12 cards
Puzzles.MemoryMinSeconds = 6 -- faster than this is not believable

export type Riddle = { Q: string, Options: { string }, Answer: number }
export type OddOne = { Items: { string }, Answer: number, Why: string }

Puzzles.Riddles = {
	{ Q = "I am orange, I grow underground, and rabbits love me. What am I?", Options = { "Pumpkin", "Carrot", "Corn", "Tomato" }, Answer = 2 },
	{ Q = "I have ears but cannot hear. I grow tall in the field. What am I?", Options = { "Corn", "Rabbit", "Owl", "Radish" }, Answer = 1 },
	{ Q = "I glow at night but I am not a lantern. I hang on a bush. What am I?", Options = { "Moon", "Glowberry", "Firefly", "Star" }, Answer = 2 },
	{ Q = "The more of me you take, the more you leave behind. What am I?", Options = { "Seeds", "Coins", "Footsteps", "Monsters" }, Answer = 3 },
	{ Q = "I come out every night, but I am never late. What am I?", Options = { "The moon", "A monster", "The merchant", "A rabbit" }, Answer = 1 },
	{ Q = "I am round and orange, and people carve faces into me. What am I?", Options = { "Orange", "Carrot", "Pumpkin", "Melon" }, Answer = 3 },
	{ Q = "What has a neck but no head, and keeps water for your crops?", Options = { "A well", "A bottle", "A sheep", "A fence" }, Answer = 2 },
	{ Q = "I say 'Who?' all night long. What am I?", Options = { "Fox", "Owl", "Dog", "Moth" }, Answer = 2 },
	{ Q = "I give you wool but never knit. What am I?", Options = { "Cow", "Sheep", "Chicken", "Boar" }, Answer = 2 },
	{ Q = "I am full of holes but I still hold water. What am I?", Options = { "A sponge", "A bucket", "A fence", "A nest" }, Answer = 1 },
	{ Q = "What gets wetter the more it dries?", Options = { "Soil", "A towel", "Rain", "A crop" }, Answer = 2 },
	{ Q = "I have a face and two hands but no arms or legs. What am I?", Options = { "A scarecrow", "A clock", "A monster", "A cottage" }, Answer = 2 },
	{ Q = "I lay eggs but I am not a bird... wait, yes I am. What am I?", Options = { "Owl", "Chicken", "Moth", "Fox" }, Answer = 2 },
	{ Q = "What can you catch but never throw?", Options = { "A monster", "A cold", "A carrot", "A coin" }, Answer = 2 },
	{ Q = "I am red, I am a fruit, but people think I am a vegetable. What am I?", Options = { "Radish", "Tomato", "Strawberry", "Pepper" }, Answer = 2 },
	{ Q = "I stand in the field all day and scare birds, but I am made of straw. What am I?", Options = { "A farmer", "A scarecrow", "A fence", "A Brute" }, Answer = 2 },
	{ Q = "I have keys but open no doors. What am I?", Options = { "A piano", "A merchant", "A gate", "A map" }, Answer = 1 },
	{ Q = "Monsters come at night. When is the safest time to farm?", Options = { "At night", "During the day", "Never", "At midnight" }, Answer = 2 },
	{ Q = "What goes up but never comes down?", Options = { "A balloon", "Your age", "A rabbit", "The sun" }, Answer = 2 },
	{ Q = "I am green, I grow on the ground, and I am striped on the outside. What am I?", Options = { "Melon", "Carrot", "Corn", "Radish" }, Answer = 1 },
	{ Q = "What has many teeth but cannot bite?", Options = { "A Brute", "A comb", "A fox", "A boar" }, Answer = 2 },
	{ Q = "I am small and pink and white, and I grow under the soil. What am I?", Options = { "Radish", "Pumpkin", "Corn", "Starfruit" }, Answer = 1 },
	{ Q = "If you have me, you want to share me. If you share me, you do not have me. What am I?", Options = { "A secret", "A carrot", "A coin", "A creature" }, Answer = 1 },
	{ Q = "What runs around a garden but never moves?", Options = { "A dog", "A fence", "A monster", "Water" }, Answer = 2 },
	{ Q = "I flutter at night and love the moonlight. What am I?", Options = { "Owl", "Spirit Moth", "Bat", "Fox" }, Answer = 2 },
	{ Q = "What has to be broken before you can use it?", Options = { "An egg", "A fence", "A lantern", "A seed" }, Answer = 1 },
	{ Q = "I am a star you can eat. What am I?", Options = { "Starfruit", "Moon Melon", "Glowberry", "Pumpkin" }, Answer = 1 },
	{ Q = "What belongs to you, but other people use it more than you?", Options = { "Your garden", "Your name", "Your coins", "Your rabbit" }, Answer = 2 },
	{ Q = "I get bigger the more you take away from me. What am I?", Options = { "A hole", "A pumpkin", "A garden", "A monster" }, Answer = 1 },
	{ Q = "Which creature is famous for being sly and clever?", Options = { "Sheep", "Fox", "Cow", "Chicken" }, Answer = 2 },
} :: { Riddle }

Puzzles.OddOneOut = {
	{ Items = { "🥕 Carrot", "🍅 Tomato", "🌽 Corn", "🐑 Sheep" }, Answer = 4, Why = "The sheep is an animal, the rest are crops." },
	{ Items = { "🐰 Rabbit", "🐔 Chicken", "🎃 Pumpkin", "🐮 Cow" }, Answer = 3, Why = "The pumpkin is a crop, the rest are creatures." },
	{ Items = { "☀️ Sun", "🌙 Moon", "⭐ Star", "🥕 Carrot" }, Answer = 4, Why = "The carrot is not in the sky." },
	{ Items = { "🔴 Red", "🔵 Blue", "🟢 Green", "🐟 Fish" }, Answer = 4, Why = "A fish is not a color." },
	{ Items = { "🦉 Owl", "🦋 Moth", "🐔 Chicken", "🐶 Dog" }, Answer = 4, Why = "The dog cannot fly (the chicken can flap a little!)." },
	{ Items = { "🍎 Apple", "🍌 Banana", "🍇 Grapes", "🥔 Potato" }, Answer = 4, Why = "The potato is a vegetable, the rest are fruits." },
	{ Items = { "❄️ Snow", "🔥 Fire", "🧊 Ice", "⛄ Snowman" }, Answer = 2, Why = "Fire is hot, the rest are cold." },
	{ Items = { "2", "4", "7", "8" }, Answer = 3, Why = "7 is odd, the rest are even." },
	{ Items = { "🐮 Cow", "🐑 Sheep", "🐔 Chicken", "🦊 Fox" }, Answer = 4, Why = "The fox does not make goods (milk, wool, eggs)." },
	{ Items = { "🌧️ Rain", "💧 Water", "🌊 Wave", "🪨 Rock" }, Answer = 4, Why = "A rock is not wet." },
	{ Items = { "🎃 Pumpkin", "🍊 Orange", "🥕 Carrot", "🍆 Eggplant" }, Answer = 4, Why = "The eggplant is purple, the rest are orange." },
	{ Items = { "🏠 House", "🏚️ Shed", "🏰 Castle", "🌳 Tree" }, Answer = 4, Why = "A tree is not a building." },
	{ Items = { "10", "20", "30", "35" }, Answer = 4, Why = "35 does not end in 0." },
	{ Items = { "🐝 Bee", "🦋 Butterfly", "🐞 Ladybug", "🐸 Frog" }, Answer = 4, Why = "The frog is not an insect." },
	{ Items = { "🍓 Strawberry", "🍒 Cherry", "🍅 Tomato", "🍋 Lemon" }, Answer = 4, Why = "The lemon is yellow, the rest are red." },
	{ Items = { "🌻 Sunflower", "🌹 Rose", "🌷 Tulip", "🌽 Corn" }, Answer = 4, Why = "Corn is a crop, the rest are flowers." },
	{ Items = { "Monday", "Friday", "Sunday", "March" }, Answer = 4, Why = "March is a month, the rest are days." },
	{ Items = { "🦁 Lion", "🐯 Tiger", "🐱 Cat", "🐶 Dog" }, Answer = 4, Why = "The dog is not a cat." },
	{ Items = { "⚽ Ball", "🏀 Ball", "🎾 Ball", "📦 Box" }, Answer = 4, Why = "A box is not round." },
	{ Items = { "🌙 Night", "🦉 Owl", "🦇 Bat", "🐓 Rooster" }, Answer = 4, Why = "The rooster wakes up in the morning, the rest love the night." },
} :: { OddOne }

-- Card pictures for Memory (any emoji works)
Puzzles.MemoryIcons = { "🥕", "🍅", "🌽", "🎃", "🍓", "🍇", "🐰", "🐔", "🐑", "🐮", "🦊", "🦉", "🌙", "⭐", "🍄", "🌻" }

return Puzzles
