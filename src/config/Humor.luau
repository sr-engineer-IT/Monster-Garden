--!strict
-- All the funny lines in the game. Add, change or remove any line; the game picks at random.
-- Kept kid-friendly (Roblox all ages). {name} is replaced by a creature's name where used.

local Humor = {}

-- Shown in a small "Moon News" card when you join (disappears by itself)
Humor.MoonNews = {
	"Local rabbit eats 47 carrots, refuses to share.",
	"Scientists confirm: the moon is NOT made of cheese. Mice are devastated.",
	"Brute monster tries to knock on a door. Door is now a window.",
	"Swarmers form a band. Their only song is 'Crunch Crunch Crunch'.",
	"Pumpkin wins 'Roundest Vegetable' for the 12th year in a row.",
	"Farmer waters crops so well, crops ask for a towel.",
	"Trickster monster turns invisible, then forgets where it put itself.",
	"Sheep starts a wool sweater business. Sheep is now cold.",
	"Night falls. Nobody knows where it falls to. Investigation continues.",
	"Owl asks 'Who?' for the 900th time. Still no answer.",
	"Corn tells a joke. Everyone says it was a bit corny.",
	"Monster tries to eat a lantern. Now glows from the inside.",
	"Chicken crosses the road. Reason: there is a merchant on the other side.",
	"Moon Melon spotted glowing. Neighbours think it is a tiny moon. It is a melon.",
	"Fox opens a shop called 'Definitely Not Stolen Stuff'.",
	"Radish complains it is always confused with a beet. 'I have feelings too.'",
	"Local cow refuses to make milk on Mondays.",
	"Stalker monster caught tiptoeing. On a trampoline.",
	"Breaking: carrot grows so big it now has its own garden.",
	"Spirit Moth sends a message: 'Please turn off the lanterns, I am trying to sleep.'",
	"Tomato blushes after being called 'the reddest one'.",
	"Boar wins staring contest against a fence. Fence did not blink.",
	"Dog fetches stick. Stick was a tree. Investigation ongoing.",
	"New study: 9 out of 10 monsters prefer crops with ketchup.",
	"Garden gnome missing. Last seen running from a Swarmer.",
	"Merchant raises prices, blames the moon.",
	"The Alpha monster tries yoga. The ground is still shaking.",
	"Glowberry glows so bright, local owls wear sunglasses.",
	"Starfruit falls from the sky. Turns out it was a regular fruit thrown very high.",
	"Scarecrow quits. 'Nobody is scared of me. The crows bring me snacks.'",
	"Bun the rabbit elected Mayor of Moonlit Grove. First law: free carrots.",
	"Monster nest found in the forest. It is very messy. Monsters refuse to clean it.",
	"Weather tonight: 100% chance of monsters, 0% chance of them saying sorry.",
	"Local farmer plants a lightbulb. Hopes to grow a power plant.",
	"Swarmer tries to eat a rock. Rock wins.",
	"Lure Berry so tasty even monsters write thank-you notes.",
	"Sheep counts humans to fall asleep.",
	"Brute takes a selfie. Phone did not survive.",
	"Expert says watering crops 3 times makes them grow faster. Expert is a carrot.",
	"Trickster plays hide and seek. Has been winning since last Tuesday.",
}

-- Added to the night report after each night
Humor.NightQuips = {
	"The Swarmers left a 1-star review of your fence.",
	"A Brute was seen crying because your lanterns were too bright.",
	"One monster asked for your carrot recipe. You said no.",
	"The monsters say you cheated. You did not. You just won.",
	"Your creatures are now telling everyone how brave they were.",
	"A Trickster stole nothing and left a sticky note: 'next time'.",
	"Monsters are filing a complaint about your excellent defense.",
	"Somewhere in the forest, a monster is practising its scary face.",
	"Your fence would like a raise.",
	"The moon gives your defense a solid 10 out of 10.",
	"Monsters went home hungry. Their mums are disappointed.",
	"Your scarecrow saw everything and is still shaking.",
	"One Swarmer got lost and asked a carrot for directions.",
	"The monsters say they will be back. They always say that.",
	"Your garden survived! Even the weeds are proud.",
	"A Brute tripped on a pumpkin. Nobody saw. Except everybody.",
	"Monsters are now selling 'I survived Moonlit Grove' T-shirts.",
	"The night is over. Your crops can stop holding their breath.",
	"A monster tried to hide behind a radish. It did not work.",
	"Bun says it was not scared. Bun was hiding under a leaf.",
	"Monster count: defeated. Snack count: still yours.",
	"The forest is quiet. Too quiet. Just kidding, it is breakfast time.",
	"You have unlocked: a good night's sleep. Probably.",
	"A Stalker left its sock behind. Gross.",
	"Monsters voted your garden 'Hardest Garden to Snack On'.",
}

-- Speech bubbles over monsters at night, by monster type
Humor.MonsterQuips = {
	swarmer = {
		"Crunch crunch?",
		"Is that a carrot?? MINE.",
		"We are many. We are hungry.",
		"Snack time snack time snack time!",
		"I just want ONE radish.",
		"Do not look at me. I am a bush.",
		"Who left the lantern on?!",
		"Tiny but hungry!",
	},
	brute = {
		"BRUTE HUNGRY.",
		"Fence look tasty.",
		"Me knock. Fence fall.",
		"Why tiny human so strong?",
		"BRUTE WANT PUMPKIN.",
		"Me not scared. Me just... leaving.",
		"Smash first, think never.",
		"This garden too clean.",
	},
	trickster = {
		"You cannot see me. Probably.",
		"Hehehe... boo!",
		"I am not here. Wait, yes I am.",
		"Guess which crop I am taking!",
		"Now you see me...",
		"I swear I am invisible right now.",
		"Tricks? Me? Never.",
		"Psst. Your fence is untied.",
	},
	stalker = {
		"Just... looking.",
		"Nice creature you have there.",
		"I am not following you. We are just going the same way.",
		"Shhh. I am sneaking.",
		"Your bunny looks very... huggable.",
		"Do not mind me.",
		"Tip-toe, tip-toe...",
	},
	alpha = {
		"I AM THE FEAST!",
		"Bring me ALL the pumpkins!",
		"You dare defend this tiny garden?",
		"The moon is MINE tonight!",
		"I have eaten bigger farmers than you. Okay, no, I have not.",
		"Is this all you have?!",
	},
}

-- Speech bubbles over your creatures when you pet them
Humor.CreatureQuips = {
	"More carrots or I riot.",
	"Pet me again. I dare you.",
	"I am basically a hero.",
	"Did you see me last night? So brave.",
	"Best farmer ever!",
	"I would protect you. From a distance.",
	"Is it snack time? It is always snack time.",
	"I love you more than radishes. Almost.",
	"Five stars. Would be petted again.",
	"I am not fluffy. I am majestic.",
	"Who is a good creature? Me. It is me.",
	"I did not eat that crop. It was the moon.",
	"Tell the monsters I said hi. Actually, do not.",
	"My hair looks amazing today.",
	"Can we buy more eggs? I want a friend.",
}

-- Mixed into the Moon News card as tips (funny but useful)
Humor.Tips = {
	"Tip: Brutes cannot read. 'Keep Out' signs do nothing.",
	"Tip: Lanterns scare small monsters. Small monsters scare easily.",
	"Tip: Watered crops grow faster. Thirsty crops grow sulky.",
	"Tip: Survive the night to earn glowing mutations. Glowing = rich.",
	"Tip: Visit a friend at night. Monsters hate teamwork.",
	"Tip: Daily Puzzles give free coins. Free is the best price.",
	"Tip: Quests reset every day. So does your excuse for not doing them.",
	"Tip: A full bag sells for more coins than an empty bag. Science.",
	"Tip: Feed your creatures. Hungry creatures stop working and start complaining.",
	"Tip: Fences break. Repair them in the day, before the monsters notice.",
}

return Humor
