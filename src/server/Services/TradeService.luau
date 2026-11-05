--!strict
-- TradeService: player-to-player trading (Build Spec section 15, stage 9). Both players build an
-- offer (coins, goods, creatures), both accept, then a short countdown (longer for rare items)
-- lets either side back out. The swap re-checks everything and runs in one step with no yields.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Config"))
local Creatures = require(ConfigFolder:WaitForChild("Creatures"))
local Mutations = require(ConfigFolder:WaitForChild("Mutations"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared:WaitForChild("GameMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local S = require(script.Parent.Parent.Registry)

type Offer = { Coins: number, Goods: { [string]: number }, Creatures: { string } }
type Session = { A: Player, B: Player, Offers: { [Player]: Offer }, Accepted: { [Player]: boolean }, ConfirmAt: number? }

local TradeService = {}

local TRADE = Config.Trade
local sessions: { [Player]: Session } = {}
local requests: { [Player]: { From: Player, At: number } } = {} -- by target

local function notify(player: Player, text: string)
	Remotes.Get("Notify"):FireClient(player, { Text = text })
end

local function emptyOffer(): Offer
	return { Coins = 0, Goods = {}, Creatures = {} }
end

local function canTrade(player: Player): boolean
	local data = S.DataService.GetData(player)
	return data ~= nil and data.Unlocks.Trading == true and not Config.KillSwitches.Trading
end

local function describe(owner: Player, offer: Offer): any
	local data = S.DataService.GetData(owner)
	local goods, creatures = {}, {}
	for key, qty in offer.Goods do
		table.insert(goods, { Key = key, Name = GameMath.GoodsName(key), Qty = qty })
	end
	for _, id in offer.Creatures do
		local creature = data and data.Creatures[id]
		if creature then
			table.insert(creatures, { Id = id, Name = GameMath.CreatureName(creature), Info = `{creature.Species}, {creature.Stage}, {#creature.Mutations} mutation(s)` })
		end
	end
	return { Coins = offer.Coins, Goods = goods, Creatures = creatures }
end

local function send(session: Session)
	for _, me in { session.A, session.B } do
		local partner = if me == session.A then session.B else session.A
		Remotes.Get("TradeUpdate"):FireClient(me, {
			Kind = "Session",
			Partner = partner.DisplayName,
			Mine = describe(me, session.Offers[me]),
			Theirs = describe(partner, session.Offers[partner]),
			AcceptedMine = session.Accepted[me] == true,
			AcceptedTheirs = session.Accepted[partner] == true,
			ConfirmAt = session.ConfirmAt,
		})
	end
end

local function close(session: Session, reason: string?)
	for _, player in { session.A, session.B } do
		sessions[player] = nil
		if player.Parent then
			Remotes.Get("TradeUpdate"):FireClient(player, { Kind = "Closed", Reason = reason })
		end
	end
end

-- Full check of one side's offer against their current data
local function validOffer(player: Player, offer: Offer): boolean
	local data = S.DataService.GetData(player)
	if not data or offer.Coins > data.Coins then
		return false
	end
	for key, qty in offer.Goods do
		if (data.Inventory.Goods[key] or 0) < qty then
			return false
		end
	end
	for _, id in offer.Creatures do
		local creature = data.Creatures[id]
		if not creature or not S.ShopService.CanTradeCreature(data, creature) then
			return false
		end
	end
	return true
end

local function isRare(player: Player, offer: Offer): boolean
	local data = S.DataService.GetData(player)
	for _, id in offer.Creatures do
		local creature = data and data.Creatures[id]
		local species = creature and Creatures.ById[creature.Species]
		if species and species.RareEgg then
			return true
		end
		for _, mutationId in creature and creature.Mutations or {} do
			local mutation = Mutations.ById[mutationId]
			if mutation and mutation.Rarity ~= "Common" and mutation.Rarity ~= "Uncommon" then
				return true
			end
		end
	end
	return false
end

local function execute(session: Session)
	local a, b = session.A, session.B
	local dataA, dataB = S.DataService.GetData(a), S.DataService.GetData(b)
	local offerA, offerB = session.Offers[a], session.Offers[b]
	if not dataA or not dataB or not validOffer(a, offerA) or not validOffer(b, offerB) then
		close(session, "Something changed, so the trade was cancelled.")
		return
	end
	local function goodsCount(offer: Offer): number
		local n = 0
		for _, qty in offer.Goods do
			n += qty
		end
		return n
	end
	if GameMath.GoodsCount(dataA) - goodsCount(offerA) + goodsCount(offerB) > GameMath.InventoryCapacity(dataA)
		or GameMath.GoodsCount(dataB) - goodsCount(offerB) + goodsCount(offerA) > GameMath.InventoryCapacity(dataB)
		or S.CreatureService.CountAll(dataA) - #offerA.Creatures + #offerB.Creatures > Config.MaxCreatures
		or S.CreatureService.CountAll(dataB) - #offerB.Creatures + #offerA.Creatures > Config.MaxCreatures
	then
		close(session, "A bag or garden would be too full.")
		return
	end

	-- Atomic swap (no yields)
	local function move(from: Player, fromData: any, to: Player, toData: any, offer: Offer)
		fromData.Coins -= offer.Coins
		toData.Coins += offer.Coins
		for key, qty in offer.Goods do
			fromData.Inventory.Goods[key] -= qty
			if fromData.Inventory.Goods[key] <= 0 then
				fromData.Inventory.Goods[key] = nil
			end
			toData.Inventory.Goods[key] = (toData.Inventory.Goods[key] or 0) + qty
		end
		for _, id in offer.Creatures do
			local record = S.CreatureService.RemoveCreature(from, id)
			if record then
				S.CreatureService.AddCreature(to, record)
			end
		end
	end
	move(a, dataA, b, dataB, offerA)
	move(b, dataB, a, dataA, offerB)
	for _, player in { a, b } do
		S.ObjectiveService.Progress(player, "Trade")
		S.DataService.MarkChanged(player)
	end
	close(session, "Trade complete!")
end

-- Remotes ------------------------------------------------------------------------------------------------

local function onRequest(player: Player, data: any, userId: any)
	local target = type(userId) == "number" and Players:GetPlayerByUserId(userId)
	if not target or target == player or not canTrade(player) then
		return
	end
	if not canTrade(target) then
		notify(player, `{target.DisplayName} has not unlocked trading yet.`)
		return
	end
	if sessions[player] or sessions[target] then
		notify(player, "One of you is already trading.")
		return
	end
	if not S.AntiExploit.TryCooldown(player, "TradeRequest", 5) then
		return
	end
	requests[target] = { From = player, At = os.clock() }
	Remotes.Get("TradeUpdate"):FireClient(target, { Kind = "Request", From = player.DisplayName })
	notify(player, `Trade request sent to {target.DisplayName}.`)
end

local function onRespond(player: Player, data: any, accept: any)
	local request = requests[player]
	requests[player] = nil
	if not request or type(accept) ~= "boolean" then
		return
	end
	local from = request.From
	if not accept or not from.Parent or os.clock() - request.At > TRADE.RequestTimeoutSeconds then
		if from.Parent then
			notify(from, `{player.DisplayName} declined the trade.`)
		end
		return
	end
	if sessions[from] or sessions[player] then
		return
	end
	local session: Session = { A = from, B = player, Offers = { [from] = emptyOffer(), [player] = emptyOffer() }, Accepted = {} }
	sessions[from], sessions[player] = session, session
	send(session)
end

local function onOffer(player: Player, data: any, offer: any)
	local session = sessions[player]
	if not session or type(offer) ~= "table" then
		return
	end
	local clean = emptyOffer()
	if S.AntiExploit.IsInteger(offer.Coins, 0, TRADE.MaxCoins) then
		clean.Coins = offer.Coins
	end
	if type(offer.Goods) == "table" then
		local kinds = 0
		for key, qty in offer.Goods do
			if kinds < TRADE.MaxGoodsKinds and type(key) == "string" and GameMath.IsKnownGoods(key) and S.AntiExploit.IsInteger(qty, 1, 999) then
				clean.Goods[key] = qty
				kinds += 1
			end
		end
	end
	if type(offer.Creatures) == "table" then
		local seen = {}
		for _, id in offer.Creatures do
			if #clean.Creatures < TRADE.MaxCreatures and type(id) == "string" and not seen[id] then
				seen[id] = true
				table.insert(clean.Creatures, id)
			end
		end
	end
	if not validOffer(player, clean) then
		notify(player, "You can't offer that (protected, Hot, busy or not owned).")
		return
	end
	session.Offers[player] = clean
	session.Accepted = {}
	session.ConfirmAt = nil
	send(session)
end

local function onAccept(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	session.Accepted[player] = true
	if session.Accepted[session.A] and session.Accepted[session.B] then
		local rare = isRare(session.A, session.Offers[session.A]) or isRare(session.B, session.Offers[session.B])
		session.ConfirmAt = os.time() + (if rare then TRADE.RareConfirmSeconds else TRADE.ConfirmSeconds)
	end
	send(session)
end

local function onCancel(player: Player)
	local session = sessions[player]
	if session then
		close(session, `{player.DisplayName} cancelled the trade.`)
	end
end

function TradeService.Init() end

function TradeService.Start()
	S.AntiExploit.Bind("TradeRequest", onRequest, { KillSwitch = "Trading" })
	S.AntiExploit.Bind("TradeRespond", onRespond, { KillSwitch = "Trading" })
	S.AntiExploit.Bind("TradeOffer", onOffer, { KillSwitch = "Trading" })
	S.AntiExploit.Bind("TradeAccept", onAccept, { KillSwitch = "Trading" })
	S.AntiExploit.Bind("TradeCancel", onCancel)
	Players.PlayerRemoving:Connect(function(player)
		requests[player] = nil
		local session = sessions[player]
		if session then
			close(session, "The other player left.")
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			local done = {}
			for _, session in sessions do
				if session.ConfirmAt and os.time() >= session.ConfirmAt and not done[session] then
					done[session] = true
					execute(session)
				end
			end
		end
	end)
end

return TradeService
