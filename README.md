# Monster Garden (Moonlit Grove)

Roblox game built with Rojo from the *Complete AI Build Spec*. The world, plots, creatures, monsters,
forest regions and UI are all built by code, so there is nothing to place by hand in Studio.

## Run it

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder (installs Rojo 7.7.1).
2. Install the Rojo plugin in Roblox Studio.
3. Run `rojo serve`, open an empty Baseplate place in Studio and click **Connect** in the Rojo plugin.
4. Press **Play**.
5. For saving: publish the place, then turn on **Game Settings > Security > Enable Studio Access to API Services**.
6. To launch: **File > Publish to Roblox**, set Max Players to 8 (one garden each), make the experience public.
7. Robux items: create each pass/product on the Creator Dashboard and paste its id into `src/config/Products.luau`
   (`AssetId = 0` shows "Coming soon"). Garden Club needs a subscription id in `Products.Club.SubscriptionId`.

## All 9 stages

| Stage | Unlocks at | What is in it |
|---|---|---|
| 1 Seeds | start | Plant, water, harvest, sell; starter rabbit Bun; first night after 3.5 min |
| 2 Defense | night 1 | Fences, lanterns, Essence, Moon Petals, Moonlit mutation, friend visits, chicken egg gift |
| 3 Growth | Level 5 | Bigger plots, soil upgrades, creature eggs, Farmer/Producer jobs, traps, reinforced fences, Brutes, rare restock |
| 4 Family | Level 10 + 2 adults | Traits, nests, breeding, babies, life stages, rare powers, training mini-game, naming |
| 5 Friends | Level 13 | Public visits, player shop stalls, leaderboards, Scout/Guardian/Hunter roles, watchtower, shelter, Tricksters, creatures can be eaten (max 1 per night) |
| 6 Hunger | Level 17 | Server Hunger Meter, Lure Berries, Starving, Star-Touched, Rare Companions |
| 7 Legacy | Level 25 | Elders, death of old age, Spirits and Spirit Grove, Legacy Traits, Stalker kidnapping and rescue, Elder monsters |
| 8 Explore | Level 30 | Whisper Forest and Echo Caves (Level 33) nests, taming monster eggs, forest nest population |
| 9 Endgame | Level 40 | Feast Night Alpha boss, Heist Night (weekend event), trading, Monster Territories, Ancient Moonlands (Level 45) |

Store: game passes, developer products with daily caps and idempotent receipts, cosmetic crates with
shown odds and a pity rule, Garden Club, Moon Season pass (free and premium tracks). No paid power.

## Player help, sounds and settings

- New players see a **How to Play** guide on first join; it is always in **Help → Full guide**.
- The current goal's target glows with a **HERE** marker (Help → Goal arrow on/off).
- Sounds: paste sound ids into `src/config/Sounds.luau` (empty slots stay silent). Help → Sound on/off.

## World

8 gardens sit in a ring around the Town Square (fountain, Seed Shop, Sell Stand, Egg Hatchery,
notice board, park). Each garden has a picket fence, a homestead (cottage, shed, well, mailbox,
scarecrow) and trees. Around the gardens: forest hills, a lake, four themed explore areas and a
ring of mountains. All of it is built by code (`WorldService`, `PlotService`, `Props`).

## Adding 3D models

Save a model as `assets/models/<Name>.rbxm` and rebuild. It replaces the block-built version
automatically. Names are listed in [Resources/Model-Names.md](Resources/Model-Names.md).

## Testing without live sync

If `rojo serve` does not work on your PC, double-click `build-place.bat`, then open `MonsterGarden.rbxlx` in Studio.
Rebuild after every code change.

## Studio test commands (chat, Studio only)

| Command | Does |
|---|---|
| `/data` | Print your profile summary |
| `/coins 500`, `/essence 50`, `/xp 1000` | Add currency or XP |
| `/level 13` | Jump to a Garden Level (stages unlock normally) |
| `/night` | Start the night warning now |
| `/age 120` | Age all your creatures by 120 play minutes |
| `/hunger 95` | Set the server Hunger Meter |
| `/feast` | Start Feast Night now (needs stage 9) |
| `/test` | Run the formula unit tests (results in Output) |
| `/resetdata` | Reset your profile (then stop and play again) |

In Studio, server-wide systems (Hunger, Feast Night) need only 1 player instead of 3, and Heist Night is always on.

## Layout

| Path | In Studio | Contents |
|---|---|---|
| `src/shared` | ReplicatedStorage.Shared | Types, Util, Signal, Remotes, GameMath |
| `src/config` | ReplicatedStorage.Config | All tunable numbers (Config, Stages, Crops, Creatures, Monsters, Defenses, Mutations, Shop, Products, Objectives, Explore) |
| `src/server` | ServerScriptService.Server | `Main.server` boots `Services/*`; `Registry`, `Build` helpers; `Packages/ProfileStore`; `Dev/` |
| `src/client` | StarterPlayerScripts.Client | `Main.client` boots `Controllers/*` and `Panels/*`; `UI/Kit` |

Rules: the server owns every decision, all numbers live in `src/config`, and services call each other through `Registry`.

Third-party code: `src/server/Packages/ProfileStore.luau` by loleris (MadStudioRoblox/ProfileStore).
