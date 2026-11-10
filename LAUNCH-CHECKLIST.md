# What to do next

Do these in order. When one is done, change `[ ]` to `[x]`.

---

### 1. Test (15 minutes)
Close the place without saving → run `build-place.bat` → open `MonsterGarden.rbxlx` → press **Play**.

- [ ] Type `/test` in chat. Output says **14 passed** (all tests, 0 failed).
- [ ] Overripe: after your first night, plant a carrot and leave it ripe for 2 minutes in the day. The prompt says "overripe in …s!", then the carrot turns brownish and says "half price". Harvest it: you get 8 coins and nothing goes in your bag.
- [ ] You hear music. Harvest = pop sound. Sell = coin sound.
- [ ] Crops look like real plants (carrot patch, corn, tomatoes...) and grow in 3 steps. Watering splashes, harvesting sparkles.
- [ ] Type `/night`. Monsters come. Attack works.
- [ ] Creatures hop when they walk and breathe when they stand. Pet one: it does a happy jump.
- [ ] Monsters waddle when they walk. Hit one: it shakes and flashes white.
- [ ] Open **Quests**. Claim works.
- [ ] Quests → **Daily Puzzles**: solve the riddle, odd one out and memory game. Coins go up each time.
- [ ] Funny lines: "Moon News" card when you join (second join), monster speech bubbles at night, creature bubbles when you pet them, a joke at the end of the night report.
- [ ] New player (`/resetdata`, Stop, Play): survive the first night. A big "LUCKY!" screen with confetti shows Bun turning Moonlit, and one crop glows.
- [ ] Open **Store**. Prices show (no "Soon").
- [ ] No **red** text in Output. (Yellow text is OK.)

If you see red text: send a screenshot to Claude.

---

### 2. Publish (2 minutes)
- [ ] **File → Publish**

---

### 3. Website (5 minutes)
Go to **create.roblox.com** → **Creations** → **Moonlit Grove**.

- [ ] **Publish settings → Game details** → upload `Resources\Images\icon.png` (Icon)
- [ ] Same page → upload `Resources\Images\thumbnail-1.png` (Thumbnail)
- [ ] Same page → **Description**: copy and paste the text from `Resources\Description.txt`
- [ ] **Monetization → Passes** → there are exactly **9** passes
- [ ] **Open Cloud → API Keys** → delete the key. Delete the file `.roblox-api-key.txt`.

---

### 3b. Money settings 💰 (10 minutes)
**New Robux items** (Starter Pack and Support stay hidden in the store until you do this):
- [ ] create.roblox.com → Moonlit Grove → **Monetization → Developer Products → Create**:
  - **Starter Pack**, price **99**, description: `One time only: 1 hour of coins, 3 cosmetic crates, a Growth Boost, a Rename Token and the Early Bird title`
  - **Support the Developer**, price **49**, description: `Supporter title. Thank you for helping Moonlit Grove grow!`
- [ ] Copy each new product's **ID** into `src\config\Products.luau` (replace `AssetId = 0` on the `dp_starter` and `dp_support` lines). Or run `tools\create-robux-items.ps1` again with a new API key (it skips items that already exist).
- [ ] Rebuild, Play, open **Store**: the Starter Pack is at the top (after the first night), Support at the bottom.

**Settings that earn with no code:**
- [ ] **Monetization → Private Servers**: turn on, price **100 Robux/month**. Friends love a garden server of their own.
- [ ] **Monetization → Immersive Ads** (and **Rewarded Video Ads** if your account has them): turn on.
- [ ] Nothing to do for **Premium Payouts**: Roblox pays you for the time Premium members play. The game now gives them +30 bag space and shows non-members a "Get Premium" button in the Store.
- [ ] In Studio, Output may show yellow `[Store] ... Roblox price is R$ X` lines. That means a price on the website differs from `Products.luau`. The store already shows the website price; update `Products.luau` to match.

---

### 4. Launch 🚀 (1 minute)
- [ ] In Studio: **File → Manage Audience → Release publicly → Continue**

---

### 5. After launch
- [ ] Play the live game on your PC and your phone.
- [ ] Press **F9 → Server**. If you see red text, send it to Claude.
- [ ] Every day: open **UPDATES.md** and do the daily check (players, errors, feedback).
