--!strict
-- Player shop stall panel (stage 5). Owners list goods or creatures within the allowed price band
-- and take them back; visitors buy. The server checks everything again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("UI"):WaitForChild("Kit"))
local PanelController = require(Client:WaitForChild("Controllers"):WaitForChild("PanelController"))

local C = Kit.Colors

local StallPanel = {}

local current: any = nil

local function priceRange(payload: any, value: number): (number, number)
	return math.max(1, math.floor(value * payload.MinPriceMult)), math.max(1, math.ceil(value * payload.MaxPriceMult))
end

local function render()
	local payload = current
	if not payload then
		return
	end
	local list = PanelController.Open("Stall", `{payload.OwnerName}'s Shop`)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	Kit.Heading(list, if payload.IsOwner then `Your listings ({#payload.Listings}/{payload.MaxListings})` else "For sale", nextOrder())
	if #payload.Listings == 0 then
		Kit.Label({ Text = "Nothing listed.", TextSize = 15, TextColor3 = C.Muted, LayoutOrder = nextOrder(), ZIndex = 22, Parent = list })
	end
	for _, listing in payload.Listings do
		local row = Kit.Row(list, nextOrder(), 64)
		local qtyText = if listing.Kind == "Goods" then ` x{listing.Qty}` else ""
		Kit.Label({ Text = `{listing.Name}{qtyText} - {listing.Price} coins each`, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -170, 0, 22), ZIndex = 23, Parent = row })
		Kit.Label({ Text = listing.Info, TextSize = 12, Font = Enum.Font.Gotham, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -170, 0, 22), ZIndex = 23, Parent = row })
		if payload.IsOwner then
			Kit.RowButton(row, 1, "Unlist", C.Bad, function()
				Remotes.Get("UnlistShopItem"):FireServer(listing.Id)
			end)
		else
			Kit.RowButton(row, 1, "Buy 1", C.Good, function()
				Remotes.Get("BuyShopItem"):FireServer(payload.OwnerUserId, listing.Id, 1)
			end)
			if listing.Kind == "Goods" and listing.Qty > 1 then
				Kit.RowButton(row, 2, "Buy all", C.Accent, function()
					Remotes.Get("BuyShopItem"):FireServer(payload.OwnerUserId, listing.Id, listing.Qty)
				end)
			end
		end
	end

	if not payload.IsOwner or not payload.Listable then
		return
	end
	Kit.Label({ Text = `A {math.floor(payload.FeeShare * 100)}% stall fee is taken from each sale.`, TextSize = 13, TextColor3 = C.Muted, LayoutOrder = nextOrder(), ZIndex = 22, Parent = list })

	Kit.Heading(list, "List goods", nextOrder())
	for _, goods in payload.Listable.Goods do
		local low, high = priceRange(payload, goods.Value)
		local row = Kit.Row(list, nextOrder(), 64)
		Kit.Label({ Text = `{goods.Name} (have {goods.Count}) price {low}-{high}`, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -250, 1, 0), ZIndex = 23, Parent = row })
		local qty = Kit.Input({ PlaceholderText = "Qty", Text = tostring(goods.Count), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -168, 0.5, 0), Size = UDim2.fromOffset(70, 40), Parent = row })
		local price = Kit.Input({ PlaceholderText = "Price", Text = tostring(goods.Value), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -84, 0.5, 0), Size = UDim2.fromOffset(78, 40), Parent = row })
		Kit.RowButton(row, 1, "List", C.Good, function()
			local q, p = tonumber(qty.Text), tonumber(price.Text)
			if q and p then
				Remotes.Get("ListShopItem"):FireServer("Goods", goods.Key, math.floor(q), math.floor(p))
			end
		end, 76)
	end

	Kit.Heading(list, "List creatures", nextOrder())
	for _, creature in payload.Listable.Creatures do
		local low, high = priceRange(payload, creature.Value)
		local row = Kit.Row(list, nextOrder(), 64)
		Kit.Label({ Text = `{creature.Name} price {low}-{high}`, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -170, 1, 0), ZIndex = 23, Parent = row })
		local price = Kit.Input({ PlaceholderText = "Price", Text = tostring(creature.Value), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -84, 0.5, 0), Size = UDim2.fromOffset(78, 40), Parent = row })
		Kit.RowButton(row, 1, "List", C.Good, function()
			local p = tonumber(price.Text)
			if p then
				Remotes.Get("ListShopItem"):FireServer("Creature", creature.Id, 1, math.floor(p))
			end
		end, 76)
	end
end

function StallPanel.Start()
	Remotes.Get("StallOpen").OnClientEvent:Connect(function(payload)
		current = payload
		render()
	end)
end

return StallPanel
