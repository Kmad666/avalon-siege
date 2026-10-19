# Avalon Siege

A low-poly isometric fantasy action RPG made in **Godot 4.7**, playable in the browser — nothing to download.

**Play:** https://kmad666.github.io/avalon-siege/

You are **Merlin**. Leave Camelot in the corner of the realm, venture into a living labyrinth, mine gold, hunt for ancient spellbooks and monstrous mini-bosses — and while Camelot's armies clash with the Dread Army mid-maze, break the Dread Citadel in the far corner.

## How to play
- **Move** by clicking and holding (Diablo style) or with **WASD / arrow keys**. Merlin's **spells cast on their own** (Vampire Survivors style), led by **Chain Lightning**.
- **Gold** is the only currency. Mine **gold-veined boulders** by standing next to them and carry the ore home. **Coins** dropped by slain foes go straight to the treasury.
- **At Camelot**, bank your ore, refill potions, heal fast, and build with **1–9**:
  Stone Walls · Archer Tower · **Miners** (peasants who mine gold for you) · **War Camp** (stronger, bigger counter-waves) · Barracks (knights that escort Merlin) · Forge · Armory · Mage Tower · Shrine
- **The war**: every ~2 minutes the Dread Army marches from the Citadel — and Camelot sends out a **mirrored host** (footmen, swordsmen, archers, paladins, a champion). The armies meet in the middle of the maze. Tip the balance with your spells and upgrades. If Camelot falls, you lose.
- **Spellbooks** glow on pedestals in hidden dead ends: each lets Merlin learn or upgrade a spell — Chain Lightning, Arcane Missiles, Fireball, Arcane Nova, Spell Orbs, Healing Light.
- **Six mini-bosses** lair in the glades — Gorm the Goblin King, Urzag the Warlord, the Bone Lich, Grukk the Troll King, the Ogre Magus and the Black Knight. Each drops a **relic** with a permanent bonus.
- **Level up** from soul gems and pick spells or blessings (Might, Haste, Vigor, Swiftness, Magnetism, Prospector).
- **Win** by destroying the **Dread Citadel**. It shoots back, regenerates, and summons guards.
- Lair monsters leave your soldiers and miners alone unless provoked — but they'll fight Merlin and his escort.

**Keys:** SPACE / Q potion · M map · mouse wheel zoom · P pause · F fullscreen · G graphics quality · N sound

## The realm
- The maze is generated fresh each game: a braided labyrinth with loops, open glades and a few long avenues.
- Green pine forests near Camelot, mossy stone walls in the middle, ashen ruins with obsidian spikes and ember cracks near the Citadel. Gold veins get richer the further you go.

## Performance
Built for laptops with integrated graphics:
- **GL Compatibility** renderer, no real-time shadows (blob shadows instead), per-vertex lighting.
- All art is generated in code as flat-shaded, vertex-coloured low-poly meshes sharing one material.
- Every unit type (both armies, miners, knights), projectile, particle, pickup and resource type is drawn with a **single MultiMesh** — a busy fight with 200+ enemies is still only ~100 draw calls.
- No physics engine: movement uses grid collision and Dijkstra **flow fields**, so hundreds of enemies path through the maze cheaply. Enemies "think" ~8× per second, staggered, and push apart every other frame.
- **Graphics quality** drops automatically if the game runs below ~42 FPS (Low renders 3D at 66% resolution and halves particles). Press **G** to cycle Low / Medium / High.
- Sound effects are synthesised at startup — there are no asset files at all.

## How it's built
- `scripts/` — everything: `maze.gd` (generation, flow fields, collision, world meshes), `models.gd` (all low-poly models), `horde.gd` (enemies & knights), `hero.gd`, `castle.gd`, `nodes.gd` (resources), `fx.gd` (projectiles, particles, pickups), `hud.gd`, `sfx.gd`.
- `.github/workflows/deploy.yml` exports the web build on every push to `main` and publishes it to the `gh-pages` branch, which GitHub Pages serves.
- Exported without threads, so it runs on GitHub Pages without special headers.

### Test hooks
Run the project with `-- --shots=DIR` to play on autopilot and save screenshots, `-- --defend` for a castle-defence test, or `-- --stress` to spawn 230 enemies and print per-system timings.
