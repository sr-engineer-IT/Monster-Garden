--!strict
-- How to Play guide. Opens by itself the first time a player joins and any time from Help.
-- Controls text matches the device (keyboard or touch). Later systems are explained once they
-- unlock; until then the guide only names the level that unlocks them (no spoilers, no overload).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Stages = require(ConfigFolder:WaitForChild("Stages"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("UI"):WaitForChild("Kit"))
local DataController = require(Client:WaitForChild("Controllers"):WaitForChild("DataController"))
local PanelController = require(Client:WaitForChild("Controllers"):WaitForChild("PanelController"))

local C = Kit.Colors

local GuidePanel = {}

local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Basics everyone sees. {Title, {lines}}
local function basics(touch: boolean): { { any } }
	local use = if touch then "tap the button that pops up" else "press E"
	return {
		{ "Getting started", {
			"Grow your garden by day. Defend it from monsters by night!",
			"This is your private garden. Your goal is always shown at the top of the screen.",
			"A glowing object with a HERE marker shows where to go next.",
			"The line under the goal tells you what to do while you wait.",
		} },
		{ "Moving", {
			if touch then "Use the thumbstick on the left to walk and the button on the right to jump." else "Walk with W A S D, jump with Space, hold right mouse button to turn the camera.",
		} },
		{ "Farming", {
			`Walk onto a brown soil tile and {use} to plant.`,
			"Choose which seed to plant with the seed buttons at the bottom of the screen.",
			`While a crop grows, {use} to water it (3 seconds faster each time, up to 3 times).`,
			`When it says Harvest, {use} to collect it. Some crops grow back several times.`,
			"Don't wait too long: after your first night, ripe crops left in the ground get overripe (only in the day while you play). Overripe crops pay half price.",
		} },
		{ "Selling and buying", {
			`Go to the merchant cart in the corner of your garden and {use} to open the shop.`,
			"Tap Sell all to sell your harvest, then buy more seeds. x5 buys five at once.",
			"More farm land, better soil and creature eggs are sold here as you level up.",
		} },
		{ "Your creatures", {
			if touch then "Walk up to your rabbit and tap Pet or Feed." else "Walk up to your rabbit: E to pet, R to feed it a crop.",
			"Keep them fed. Hungry creatures stop working.",
			"Open Pets (left menu) to see age, traits and roles. Bun is Bonded and can never be lost.",
		} },
		{ "Night and fighting", {
			"The timer at the top shows when night comes. A warning banner appears first.",
			"Monsters come through the four gates in your hedge and go for your crops and creatures.",
			if touch then "Get close and tap the red ATTACK button, or tap a monster." else "Get close and press F, click a monster, or press the ATTACK button.",
			"After each night you get a report, Garden XP and coins. Creatures can earn glowing mutations.",
		} },
		{ "Defenses", {
			`After your first night, stand at a gate and {use} to build a fence. Monsters must break it first.`,
			"Lanterns near the gates slow monsters down and scare small ones away.",
			"Repair damaged defenses in the day (hold the prompt). Traps and stronger fences come later.",
			"Gates upgrade: Wooden, then Reinforced (takes less damage), Iron at Level 20 (spikes hurt monsters), Moon at Level 35 (glows, strongest).",
		} },
		{ "Growing your garden", {
			"Everything you do gives Garden XP. New levels bring new seeds, more farm land and new systems.",
			"Help shows what is coming next. Nothing ever needs Robux.",
			"Open Quests every day: 3 daily quests and a weekly quest give coins, Essence and Season XP.",
			"Daily Puzzles (in Quests, or the notice board in town): a riddle, an odd-one-out and a memory game, with rewards.",
			"At Garden Level 40 you can Rebirth: start again with a permanent coin and XP bonus, keeping your creatures.",
		} },
	}
end

-- One section per later stage, shown in full once unlocked
local STAGE_GUIDES: { [number]: { any } } = {
	[4] = { "Family (breeding)", {
		"Build a nest at the nest spots near your creature area.",
		"In Pets, choose Breed on an adult and pick a partner of the same species and the other sex.",
		"A baby is born after 15 minutes of play. Name it, train it and watch it grow up.",
	} },
	[5] = { "Friends", {
		"Open Friends to visit gardens, help defend them at night and trade.",
		"Your shop stall lets other players buy your goods and creatures.",
		"Build a watchtower to see monsters coming and a shelter to keep 4 creatures safe.",
		"From now on a monster may take one injured creature per night. Guardians and shelters protect them.",
	} },
	[6] = { "Hunger", {
		"Defending well makes the server's monsters hungrier (top right). Hungry nights are harder but pay more.",
		"Grow Lure Berries and tap Lure Berry to feed the monsters and calm them down.",
	} },
	[7] = { "Legacy", {
		"Creatures now age into Elders and, at the end of their life, become Spirits in your Spirit Grove.",
		"Spirits boost their whole bloodline. Lifespans are always shown in Pets.",
		"Stalkers may grab a creature at night: chase and hit them. If one escapes, rescue your creature from the nest outside your west gate.",
	} },
	[8] = { "Explore", {
		"Walk out of the gardens to find the forest and caves. Defeat the guards, then destroy monster nests.",
		"Nests give rewards and eggs you can hatch into tamed monster companions.",
	} },
	[9] = { "Endgame", {
		"When Hunger reaches 100, Feast Night brings the Alpha. Everyone fights it together for big rewards.",
		"Heist Night (weekends): raise your Heist Flag to steal from and defend against other flagged players. Only creatures you put in your Heist Pen can be taken.",
		"Trade with other players from the Friends menu.",
	} },
}

function GuidePanel.Open()
	local data = DataController.Get()
	local list = PanelController.Open("Guide", "How to Play")
	local order = 0
	local function add(text: string, color: Color3?, size: number?)
		order += 1
		Kit.Label({ Text = text, TextSize = size or 15, TextColor3 = color or C.Text, TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -8, 0, 18), LayoutOrder = order, ZIndex = 22, Parent = list })
	end
	local function heading(text: string)
		order += 1
		Kit.Heading(list, text, order)
	end

	for _, section in basics(isTouch()) do
		heading(section[1])
		for _, line in section[2] do
			add("- " .. line)
		end
	end

	local stage = if data then data.Stage else 1
	for stageId = 4, #Stages.List do
		local section = STAGE_GUIDES[stageId]
		if section then
			if stage >= stageId then
				heading(section[1])
				for _, line in section[2] do
					add("- " .. line)
				end
			else
				local trigger = Stages.Get(stageId).Trigger
				heading(section[1])
				add(`Unlocks at Garden Level {trigger.Level or "?"}.`, C.Muted, 14)
			end
		end
	end

	heading("Store, Season and Style")
	add("- Store sells looks and time-savers only. Odds for crates are always shown.", nil, 14)
	add("- Season gives free rewards for playing; Style lets you wear glows, themes and titles.", nil, 14)

	order += 1
	Kit.Button({ Text = "Got it!", Size = UDim2.new(1, -8, 0, 48), BackgroundColor3 = C.Good, LayoutOrder = order, ZIndex = 22, Parent = list }, PanelController.Close)
end

function GuidePanel.Start()
	-- First join: open the guide once and remember it
	local opened = false
	local function check(data: any)
		if not opened and data and data.TutorialDone and not data.TutorialDone.Guide then
			opened = true
			task.wait(2)
			GuidePanel.Open()
			Remotes.Get("MarkTip"):FireServer("Guide")
		end
	end
	DataController.Changed:Connect(check)
	check(DataController.Get())
end

return GuidePanel
