# Moonlit Grove: Update Plan

Open this file every day. Do the daily check, then pick **one** idea and ask Claude to build it.
Tick a box by changing `[ ]` to `[x]`. Add your own ideas at the bottom.

---

## Every day (10 minutes)

- [ ] create.roblox.com → Moonlit Grove → **Analytics**: how many players today? How many came back (Day 1 retention)?
- [ ] Play the live game 5 minutes. Press **F9 → Server**: any red text? Send it to Claude.
- [ ] Read player comments / reviews. Write the common complaints in "Player feedback" below.

## Every week

- [ ] Fix the top player complaint.
- [ ] Add one small new thing (a crop, a cosmetic, a joke, a puzzle).

## Every 2-4 weeks: a bigger update

- [ ] Pick one idea from the lists below, build it, test it, publish it.
- [ ] Tell players: update the game description ("🆕 UPDATE: ...") and the thumbnail.

---

## Player feedback (write here)

- [x] Creatures follow me onto the farm and get in the way of harvesting. (Fixed: creatures wait off the field while you farm, and their Pet button hides when a tile can be worked.)
- [x] Monsters move weirdly and overlap in some spots. (Fixed: monsters keep space between each other and turn smoothly.)
- [x] More decorations for the garden, not just the lamp and the fence. (Added: 🪴 Decor menu, 15 decorations. A decoration takes one soil tile, so players trade farm land for a prettier garden. Pick it up to get the soil back. Prices in `src/config/Decor.luau`.)
- [x] An upgrade station: faster growing, faster walking, more crops per harvest. (Added: 🔧 Upgrade Station workbench in every garden with Green Thumb, Swift Boots and Big Harvest, 5 levels each. Prices in `src/config/Upgrades.luau`.)

---

## Quick wins: more players and more players coming back (do these first)
More players = Roblox shows the game to more people = more Robux. These are small and work best right after launch.

- [x] **Login streak**: the daily gift grows for 7 days in a row, Day 7 gives a crate.
- [x] **Friend bonus**: +10% coins on selling for each friend in your server (max +30%).
- [ ] **Badges** 🏅: "Welcome", "First Night", "First Moonlit", "Level 10", "First Rebirth". Players love badges and they show on their profile, so their friends see your game. Create them on the website (Engagement → Badges), then ask Claude to award them.
- [ ] **Codes** 🎟️: a "Codes" box in the menu. Post codes on your Discord/YouTube/TikTok (`LAUNCH` = 500 coins). Very popular on Roblox and brings players back.
- [ ] **Group reward** 👥: make a Roblox group; members get a "Grove Member" title and +10% Essence. Group members get your update news.
- [ ] **Like and favorite reminder** 👍: after a player's 3rd night, one small friendly message: "Enjoying Moonlit Grove? Tap 👍 and ⭐ to help!" (only once, never again).
- [ ] **Experience Notifications** 🔔: Roblox lets games send "Your crops are ready!" notifications to players who opted in. Brings players back.
- [ ] **Invite reward**: when a friend you invited joins for the first time, you both get a crate.
- [ ] **Weekend event** 🎉: "Double Moonlit Weekend" every Saturday-Sunday (one number in Config). Players learn to come back on weekends.
- [ ] **Limited-time offer**: a cosmetic sold only this week (Halloween hat, winter glow). Makes players buy now instead of "later".
- [ ] **Overripe tuning**: after a week, read the comments. If players hate Overripe, raise `Config.Spoil.FreshMult`. If nobody notices it, lower it.

---

## Big ideas (in a good order)

### 1. Collection Book 📖 (first update, recommended)
A book in the menu with a page for every crop, creature, glow (mutation) and monster.
- [ ] Empty slots show a "?" until you find it (keeps players curious).
- [ ] Each page gives a reward when complete (coins, Essence, a title like "Master Farmer").
- [ ] Rare finds show where to get them ("Hint: survive a Starving night").
- [ ] A % complete counter ("Collection: 47%") and a leaderboard for it.

### 2. New monsters 👹
Each gives a new reason to build or fight differently.
| Done | Monster | Idea | When |
|---|---|---|---|
| [ ] | **Moon Moth Swarm** | Many tiny flying monsters, ignore fences, scared by lanterns | Level 15+ |
| [ ] | **Mud Golem** | Very slow, very tough, splits into 2 small golems when defeated | Level 22+ |
| [ ] | **Night Thief** | Does not attack, steals 1 harvested crop and runs away (chase it!) | Level 18+ |
| [ ] | **Frost Wisp** | Freezes one crop so it stops growing until morning | Level 28+ |
| [ ] | **Pumpkin King** | A Halloween boss with a pumpkin head, drops a special cosmetic | Halloween event |
| [ ] | **Eclipse Dragon** | A second Feast Night boss, only during an Eclipse event | Level 45+ |

### 3. New creatures 🐾
| Done | Creature | Job / power |
|---|---|---|
| [ ] | Hedgehog | Guardian: spikes hurt monsters that touch it |
| [ ] | Bee | Producer: makes Honey (sells well), helps crops grow faster |
| [ ] | Turtle | Very slow, very tough Guardian, lives a very long time |
| [ ] | Firefly | Glows at night like a small lantern |
| [ ] | Baby Dragon | Rare egg from the Moonlands, breathes fire on monsters |

### 4. New crops 🌱
| Done | Crop | Special |
|---|---|---|
| [ ] | Sunflower | Gives extra coins in the day |
| [ ] | Mushroom | Grows only at night |
| [ ] | Crystal Carrot | Very rare seed from monster nests |
| [ ] | Rainbow Corn | Random color each harvest, sells for more |
| [ ] | Ghost Pepper | Monsters avoid the tile it grows on |

### 5. Events 🎉 (players come back for these)
| Done | Event | When | Idea |
|---|---|---|---|
| [ ] | Harvest Moon Week | any time | Crops grow 2x faster, Moonlit chance doubled |
| [ ] | Halloween Night | October | Pumpkin King boss, spooky garden theme, candy crop |
| [ ] | Winter Garden | December | Snow on the map, Frost Wisps, gift boxes, snowman cosmetic |
| [ ] | Eclipse Weekend | any weekend | Eclipse glow chance x10, Eclipse Dragon boss |
| [ ] | Spring Bloom | March-April | Flower crops, bunny event, egg hunt in the forest |

### 6. Seasons 🌕
- [ ] Season 2: new name, new 50 tiers of rewards (change `Config.Season`).
- [ ] New premium cosmetics for each Season.

### 7. Polish (from our review)
- [ ] Better **music**: replace day and night music with real tracks from the Creator Store (Toolbox → Audio).
- [ ] **Characters** in one style: pick one creator's animal pack so all creatures match.
- [ ] **Named characters**: give Bun and the main monsters a clear personality and look.
- [ ] Animated creature models (walking legs), then ask Claude to play the animations.
- [ ] Lighter Cottage and Shop_Sell models if phones lag.
- [ ] Remove the Sound inside the Scarecrow model (harmless warning).
- [ ] "Start Over" button for players who want a full fresh start (keeps Robux items).

---

## Already in the game (for reference)

- Super-rare glows: **Celestial** (1 in 5,000) and **Eclipse** (1 in 50,000), with a big celebration and a server-wide message.
- Harder Rebirths: each rebirth makes nights 25% harder and pays 25% more.
- Daily quests, weekly quest, Daily Puzzles, Moon News, Season pass, Rebirth.

---

## My own ideas (write here)

- 
- 
