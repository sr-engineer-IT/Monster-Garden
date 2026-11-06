# Moonlit Grove: Launch Checklist

Work from top to bottom. Tick a box by changing `[ ]` to `[x]`.
After every code or model change: close the place **without saving**, run `build-place.bat`,
open `MonsterGarden.rbxlx`, test, then **File → Publish to Roblox** again.

---

## 1. Publish (do first, about 10 minutes)

- [ ] In Studio: **File → Publish to Roblox** → **Create new experience** → name it "Moonlit Grove".
- [ ] Keep it **Private** for now: Creator Dashboard → your game → **Settings** → Privacy.
- [ ] **Game Settings → Security** → turn on **Enable Studio Access to API Services** → Save. Saving progress needs this.
- [ ] **Game Settings → Places → Max Players = 8** → Save. Each player needs their own garden.
- [ ] Press Play in Studio. Output should show no `ProfileStore API unavailable` warning anymore.
- [ ] Play, leave, play again. Your coins and level should be the same (saving works).
      Note: Studio uses its own test save, separate from the live game. Live players start fresh.

---

## 2. Robux items (about 1 hour)

Website: **create.roblox.com/dashboard/creations** → your game → **Monetization**.

**Passes:** Monetization → **Passes** → Create a Pass → image + name → Create.
Then open the pass → **Sales** → turn on **Item for Sale** → set the price → copy the **ID**.

| Done | Code id | Name | Price | Paste ID here |
|---|---|---|---|---|
| [ ] | `pass_plot` | Extra Plot | 199 | |
| [ ] | `pass_nest` | Extra Nest Slot | 149 | |
| [ ] | `pass_inventory` | Bigger Inventory | 149 | |
| [ ] | `pass_autoharvest` | Auto-Harvest | 399 | |
| [ ] | `pass_founder` | Founder Pass | 499 | |
| [ ] | `pass_shoptheme` | Shop Stall Themes | 149 | |
| [ ] | `pass_grovetheme` | Spirit Grove Themes | 199 | |
| [ ] | `pass_vipflair` | Premium Flair | 99 | |
| [ ] | `pass_season` | Moon Season Premium | 599 | |

**Developer Products:** Monetization → **Developer Products** → Create → name + price → copy the **ID**.

| Done | Code id | Name | Price | Paste ID here |
|---|---|---|---|---|
| [ ] | `dp_rename` | Rename Token | 25 | |
| [ ] | `dp_recolor` | Recolor Token | 49 | |
| [ ] | `dp_crate1` | Cosmetic Crate | 49 | |
| [ ] | `dp_crate10` | Cosmetic Crate x10 | 399 | |
| [ ] | `dp_growth` | Growth Boost | 49 | |
| [ ] | `dp_coin_s` | Small Coin Pack | 49 | |
| [ ] | `dp_coin_m` | Medium Coin Pack | 99 | |
| [ ] | `dp_coin_l` | Large Coin Pack | 149 | |
| [ ] | `dp_tierskip` | Season Tier Skip | 49 | |

- [ ] Put every ID into `src/config/Products.luau`: change `AssetId = 0` to `AssetId = <the ID>`.
      (Or send the filled table to Claude and ask it to do this.)
- [ ] Rebuild and publish. In the Store, buttons now show prices instead of "Soon".
- [ ] Buy one pass and one product in Studio (test purchases there are free) and check you received them.
- [ ] Later (optional): Garden Club subscription. It needs Roblox subscription eligibility, then put the ID in `Products.Club.SubscriptionId`.

---

## 3. Sounds (about 30 minutes)

In Studio: **Toolbox → Audio**. Pick a sound, copy its ID, and paste it into `src/config/Sounds.luau`
as `"rbxassetid://<ID>"`. Only use audio that is free to use (made by Roblox or marked as public).

| Done | Slot | What it is |
|---|---|---|
| [x] | `Banner` | Unlocks and gifts (already set) |
| [ ] | `Harvest` | Picking a crop (short "pop") |
| [ ] | `Sell` | Coins (cash register / coin jingle) |
| [ ] | `Attack` | Hitting a monster (swoosh / bonk) |
| [ ] | `LevelUp` | Level up (happy fanfare) |
| [ ] | `NightWarning` | Monsters coming (horn) |
| [ ] | `Mutation` | Creature mutation (magic chime) |
| [ ] | `Hatch` | Egg hatching / baby born |
| [ ] | `Crate` | Opening a crate |
| [ ] | `Day` | Daytime music / birds (loop) |
| [ ] | `Night` | Night music (calm but spooky, loop) |
| [ ] | `Feast` | Feast Night boss music (loop) |

- [ ] Rebuild, play, and check the volume feels right (Help → Sound ON/OFF should work).

---

## 4. Test everything (a few days, with 2-3 friends)

Invite friends to the private game: Creator Dashboard → your game → **Collaborators** or **Private servers**.
Send every red error from Output (F9 in a live game) to Claude.

**Alone (Studio chat commands help: `/level 13`, `/night`, `/coins 5000`, `/age 120`, `/test`)**
- [ ] `/test` in chat: Output says all tests passed (10 tests).
- [ ] New player: the guide opens, the HERE arrow points to the right things.
- [ ] Plant, water, harvest, sell, buy seeds (E acts on the tile under you).
- [ ] First night: monsters come through the gates, Attack works, night report shows.
- [ ] Build fence, lantern, trap, watchtower, shelter; repair after a night.
- [ ] Buy plot expansions and soil upgrades.
- [ ] Creature eggs, feeding, petting, Farmer/Producer jobs.
- [ ] Level 10: breeding, babies, naming, training mini-game.
- [ ] Level 25: Elders, Spirit Grove, kidnapping and rescue.
- [ ] Level 30+: Whisper Forest, Echo Caves nests, taming eggs.
- [ ] Town Square shops open the merchant.
- [ ] Season: claim rewards, Claim all.
- [ ] Style: equip glows, themes, titles.
- [ ] Leave and rejoin: everything saved.
- [ ] Play on a **phone** (Studio: Test → Device emulator, and on a real phone): buttons fit, no lag.

**With friends (needs 2-3 players in one server)**
- [ ] Visit a friend's garden and help defend at night.
- [ ] Shop stalls: sell to each other.
- [ ] Trading.
- [ ] Hunger meter rises; Lure Berries lower it.
- [ ] Feast Night: everyone fights the Alpha together.
- [ ] Heist Night (weekends): raise flags, steal from the Heist Pen, steal back.
- [ ] Leaderboards show everyone.

---

## 5. Balance (after testing)

- [ ] First 10 minutes feel fun: not too slow, not too fast.
- [ ] First night is easy; later nights get harder but never feel unfair.
- [ ] Prices feel fair (all numbers are in `src/config/`; ask Claude to change them).
- [ ] Nobody gets stuck: there is always a clear next goal.

---

## 6. Store page (before going public)

Creator Dashboard → your game:
- [ ] **Icon** (512×512): bright, a cute creature + garden at night.
- [ ] **Thumbnails** (at least 3, 1920×1080): garden by day, monsters at night, Town Square.
- [ ] **Description**: what the game is, in 3-4 short lines. Mention "free to play, nothing needs Robux".
- [ ] **Genre**, **devices** (Computer, Phone, Tablet, Console).
- [ ] **Maturity / Experience Questionnaire**: fill it in honestly (cartoon monsters, no blood).
- [ ] If you used CC-BY models: credit their authors in the description (see `Resources/Asset-Log.csv`).

---

## 7. Launch day

- [ ] Final rebuild + publish.
- [ ] Settings → Privacy → **Public**.
- [ ] Join from a phone and a PC to check the live game.
- [ ] Watch **Developer Console (F9) → Server** for red errors in the first hour.
- [ ] Share the link with friends and in communities.

---

## 8. After launch (keep doing)

- [ ] Every day for the first week: check Creator Dashboard → **Analytics** (players, retention, errors).
- [ ] Fix errors players hit. If a feature breaks, turn it off in `Config.KillSwitches` and republish.
- [ ] Update regularly: new crops, cosmetics, events. Change the Season in `Config.Season`.
- [ ] Replace heavy models with lighter ones (Cottage, Shop_Sell) if phones lag.
- [ ] Ask Claude to add walk animations once you have animated creature models.
- [ ] Back up the project folder (or push it to GitHub) before big changes.

---

## Already done by code (no action needed)

- [x] All 9 stages of the design document.
- [x] Saving (ProfileStore), anti-cheat checks, idempotent purchases, daily caps.
- [x] UI, guide, HERE arrow, sounds system, settings.
- [x] World: 8 gardens, Town Square, forest, lake, explore areas, mountains, day/night lighting.
- [x] All 40 3D models loaded, cleaned of scripts, heavy models blocked.
- [x] Paid random items check (crates follow Roblox country rules automatically).
- [x] 8 players per server.
- [x] Coin packs (Small / Medium / Large) from the start, exact amount shown, daily limits, "+" button by your coins.
- [x] Studio testing uses a separate save and leaderboard, so it never touches live players.
