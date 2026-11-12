--!strict
-- Remote registry (Build Spec section 17). The server creates every remote at boot;
-- clients wait for them. Only RemoteEvents are used: the server never invokes a client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Remotes = {}

-- Client to server requests. Server checks live in each service's handler.
Remotes.ClientToServer = {
	-- Farming and economy
	"SelectSeed", -- cropId: seed used by the Plant prompt
	"BuyItem", -- itemId, qty
	"SellItems", -- none: sell all goods
	"PlaceSoil", -- cellId: place a soil tile on a build-grid square (up to the plot size allowance)
	"RemoveSoil", -- cellId: take a soil tile away (no crop growing on it)
	"PlaceDecorAt", -- decorId, cellId, turns: place on a grass build-grid square (shared/GardenGrid)
	"RemoveDecor", -- cellId or tileId: decoration back to storage
	"MoveItem", -- fromCellId, toCellId, turns?: move a decoration or soil tile (with its crop)
	"BuyUpgrade", -- upgradeId: next level at the Upgrade Station
	"RequestSync", -- none: client asks for a fresh data snapshot
	"VeteranSkip", -- none: "I know this game" (first session only)
	"MarkTip", -- tipId: a tutorial tip or the guide was seen
	"SetSetting", -- key, bool: SoundOn or GuideArrow
	-- Creatures and breeding
	"SetRole", -- creatureId, role
	"StartBreeding", -- motherId, fatherId
	"RenameCreature", -- creatureId, name
	"TrainCreature", -- creatureId, taps
	"SetShelter", -- creatureId, bool
	"RerollMutation", -- creatureId
	"RecolorCreature", -- creatureId, colorIndex
	-- Night
	"PlayerAttack", -- targetId?
	"ThrowLureBerry", -- none
	"FeastSupply", -- none: give 5 crops to the Feast Night defense
	-- Social
	"VisitGarden", -- userId (0 = home)
	"SetVisitsOpen", -- bool
	"RequestLeaderboards", -- none
	"ListShopItem", -- kind, key, qty, price
	"UnlistShopItem", -- listingId
	"OpenStall", -- ownerUserId
	"QuestClaim", -- kind ("Daily" | "Weekly" | "Bonus"), index
	"Rebirth", -- none: rebirth now (server checks the level)
	"PuzzleBegin", -- kind: a memory game started (for the time check)
	"PuzzleSolve", -- kind, answer
	"OpenPuzzles", -- server -> client: open the Daily Puzzles panel
	"BuyShopItem", -- ownerUserId, listingId
	"TradeRequest", -- userId
	"TradeRespond", -- accept bool
	"TradeOffer", -- offer table
	"TradeAccept", -- none
	"TradeCancel", -- none
	-- Heist Night
	"SetHeistFlag", -- bool
	"SetPen", -- creatureId, bool
	"LockPen", -- none
	"StealBack", -- creatureId
	-- Store and style
	"PurchaseRequest", -- productId or passId
	"EquipCosmetic", -- kind, id (or nil to remove)
	"SeasonClaim", -- tier, premium bool
}

-- Server to client messages. Display only.
Remotes.ServerToClient = {
	"DataSync",
	"UnlockBanner",
	"NightWarning",
	"NightReport",
	"HungerUpdate",
	"MutationEarned",
	"Notify",
	"MerchantOpen", -- offers for the merchant panel
	"OpenUpgrades", -- open the Upgrade Station panel
	"StallOpen", -- stall listings
	"LeaderboardUpdate", -- boards
	"TradeUpdate", -- trade state
	"FeastUpdate", -- Feast Night state
	"NeighborAlert", -- big attack nearby
	"PlayersUpdate", -- who is in the server (for visits and trades)
	"CrateOpened", -- cosmetic won
}

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder :: Folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

-- Server only: create all remotes once at boot.
function Remotes.Setup()
	assert(RunService:IsServer(), "Remotes.Setup is server only")
	local folder = getFolder()
	for _, list in { Remotes.ClientToServer, Remotes.ServerToClient } do
		for _, name in list do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
		end
	end
end

function Remotes.Get(name: string): RemoteEvent
	local folder = getFolder()
	local remote = if RunService:IsServer() then folder:FindFirstChild(name) else folder:WaitForChild(name, 10)
	assert(remote and remote:IsA("RemoteEvent"), `Unknown remote: {name}`)
	return remote
end

return Remotes
