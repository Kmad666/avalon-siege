# Avalon Siege

A low-poly isometric fantasy action RPG made in **Godot 4.7**, playable in the browser — nothing to download.

**Play:** https://kmad666.github.io/avalon-siege/

Leave Camelot in the corner of the realm, fight your way through a living labyrinth, gather gold, timber and mana crystals, haul them home to build up your castle — and break the Dread Citadel in the far corner before its army breaks you.

## How to play
- **Move** by clicking and holding (Diablo style) or with **WASD / arrow keys**. Your weapons **attack on their own** (Vampire Survivors style).
- **Gather** by standing next to a **golden oak** (timber), a **gold-veined boulder** (gold) or a **mana crystal** (crystal). Your pack holds a limited amount.
- **Return to Camelot** to bank your pack automatically, refill potions and heal fast. While home, build upgrades with **1–8** or by clicking:
  Stone Walls · Archer Towers · Barracks (knights that escort you) · Forge · Armory · Mage Tower (castle lightning) · Stables · Shrine
- **Waves**: every minute or so the Dread Army marches out of the Citadel through the maze toward Camelot. Every 5th wave is led by a Dark Knight. If Camelot falls, you lose.
- **Level up** from soul gems dropped by slain foes and pick one of three blessings: new weapons (Excalibur, Arcane Bolts, Fireball, Holy Nova, Whirling Axes, Chain Lightning) or passives (Might, Haste, Vigor, Swiftness, Magnetism, Woodsman).
- **Win** by destroying the **Dread Citadel**. It shoots back and summons guards when you get close.
- If you fall, you respawn at Camelot after a few seconds — but your pack is lost.

**Keys:** SPACE / Q potion · M map · mouse wheel zoom · P pause · F fullscreen · G graphics quality · N sound

## The realm
- The maze is generated fresh each game: a braided labyrinth with loops, open glades and a few long avenues.
- It changes as you go: green pine forests near Camelot, mossy stone walls in the middle, and ashen ruins with obsidian spikes and ember cracks near the Citadel. Enemies and resources get richer the further you go.
- Monster camps guard the glades: goblins, orcs, skeleton archers and ogres, sometimes led by a tougher elite.

## Performance
Built for laptops with integrated graphics:
- **GL Compatibility** renderer, no real-time shadows (blob shadows instead), per-vertex lighting.
- All art is generated in code as flat-shaded, vertex-coloured low-poly meshes sharing one material.
- Every enemy type, knight, projectile, particle, pickup and resource type is drawn with a **single MultiMesh** — a busy fight with 200+ enemies is still only ~100 draw calls.
- No physics engine: movement uses grid collision and Dijkstra **flow fields**, so hundreds of enemies path through the maze cheaply. Enemies "think" ~8× per second, staggered, and push apart every other frame.
- **Graphics quality** drops automatically if the game runs below ~42 FPS (Low renders 3D at 66% resolution and halves particles). Press **G** to cycle Low / Medium / High.
- Sound effects are synthesised at startup — there are no asset files at all.

## How it's built
- `scripts/` — everything: `maze.gd` (generation, flow fields, collision, world meshes), `models.gd` (all low-poly models), `horde.gd` (enemies & knights), `hero.gd`, `castle.gd`, `nodes.gd` (resources), `fx.gd` (projectiles, particles, pickups), `hud.gd`, `sfx.gd`.
- `.github/workflows/deploy.yml` exports the web build on every push to `main` and publishes it to the `gh-pages` branch, which GitHub Pages serves.
- Exported without threads, so it runs on GitHub Pages without special headers.

### Test hooks
Run the project with `-- --shots=DIR` to play on autopilot and save screenshots, `-- --defend` for a castle-defence test, or `-- --stress` to spawn 230 enemies and print per-system timings.
