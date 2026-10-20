# Avalon Siege

A low-poly isometric fantasy action RPG made in **Godot 4.7**, playable in the browser — nothing to download.

**Play:** https://kmad666.github.io/avalon-siege/

You are **Merlin**. Leave Camelot in the corner of the realm, venture into a living labyrinth, mine gold, hunt for ancient spellbooks and monstrous mini-bosses — and while Camelot's armies clash with the Dread Army mid-maze, break the Dread Citadel in the far corner.

## How to play
- **Pick a difficulty** on the title screen: Squire, Knight or Legend.
- **Move** by clicking and holding (Diablo style) or with **WASD / arrow keys**. Merlin's **spells cast on their own** (Vampire Survivors style), led by **Chain Lightning**.
- **Gold** is the only currency. Mine **gold-veined boulders** and carry the ore home; **coins** from slain foes go straight to the treasury.
- **Camelot builds itself.** Its steward spends the treasury automatically — Miners, Archer Towers, War Camp, Forge, Stone Walls (first when Camelot is hurt), Barracks, Mage Tower, Armory, Shrine — and the HUD shows what it's saving for.
- **Loot equips itself.** Items drop in five slots (staff, hat, robe, amulet, ring) and four rarities with random affixes. Walk over one: if it's better than what Merlin wears he puts it on, otherwise it's melted down for gold.
- **The war**: every ~2 minutes the Dread Army marches from the Citadel and Camelot sends out a mirrored host. The Dread grows through eras — wolf riders, orcs and healing shamans, skeletons and necromancers who raise the dead, ogres and Dark Knights — and Camelot answers with cavalry, clerics and battle mages. The armies meet mid-maze; tip the balance.
- **Ley Shrines**: five shrines held by the Dread. Clear the area and stand in the circle to capture one — it pays gold, heals your side, and becomes a **waypoint** (press **T** at Camelot or any shrine you hold). Raiders will try to take them back.
- **Spellbooks** glow in dead ends; **six mini-bosses** lair in the glades and drop permanent relics.
- **The endgame**: three **Dread Wards** shield the Citadel. Destroy them all to bring the shield down; at half health the **Dread Lord** rises. Destroy the Citadel to win — lose Camelot and it's over.

**Keys:** SPACE / Q potion · T waypoint travel · M map · mouse wheel zoom · P pause · F fullscreen · G graphics quality · N or the speaker button (top right) to mute

## The realm
- A large maze generated fresh each game: a braided labyrinth with loops, open glades and long avenues.
- Green pine forests near Camelot, mossy stone walls in the middle, ashen ruins with obsidian spikes and ember cracks near the Citadel. Gold veins and foes get richer the further you go.

## Performance
Built for laptops with integrated graphics:
- **GL Compatibility** renderer, no real-time shadows (blob shadows instead), per-vertex lighting.
- All art is generated in code as flat-shaded, vertex-coloured low-poly meshes sharing one material.
- Every unit type (both armies, miners, knights), projectile, loot drop, particle, pickup and resource type is drawn with a **single MultiMesh** — a busy fight with 200+ enemies is still only ~100 draw calls.
- No physics engine: movement uses grid collision and Dijkstra **flow fields**, so hundreds of enemies path through the maze cheaply. Enemies "think" ~8× per second, staggered, push apart every other frame, and idle lairs far from Merlin sleep until he approaches.
- **Graphics quality** drops automatically if the game runs below ~42 FPS (Low renders 3D at 66% resolution and halves particles). Press **G** to cycle Low / Medium / High.
- Sound effects are synthesised at startup — there are no asset files at all.

## How it's built
- `scripts/` — everything: `maze.gd` (generation, flow fields, collision, world meshes), `models.gd` (all low-poly models), `horde.gd` (enemies & knights), `hero.gd`, `castle.gd`, `nodes.gd` (gold veins, spellbooks), `items.gd` (loot), `landmarks.gd` (wards, shrines), `fx.gd` (projectiles, particles, pickups), `hud.gd`, `sfx.gd`.
- `.github/workflows/deploy.yml` exports the web build on every push to `main` and publishes it to the `gh-pages` branch, which GitHub Pages serves.
- Exported without threads, so it runs on GitHub Pages without special headers.

### Test hooks
Run the project with `-- --shots=DIR` to play on autopilot and save screenshots, `-- --defend` for a castle-defence test, or `-- --stress` to spawn 230 enemies and print per-system timings.
