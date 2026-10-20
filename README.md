# Avalon Siege

A low-poly isometric fantasy action RPG made in **Godot 4.7**, playable in the browser — nothing to download.

**Play:** https://kmad666.github.io/avalon-siege/

You are **Merlin**. Camelot stands fully defended in one corner of a fog-choked realm; the Dread Citadel looms in the other. While the two armies grind against each other on the War Lane, you and your hooded Circle of Avalon venture out — down the guarded Royal Roads, along branching trails, and into maze pockets that hide spellbooks and treasure.

## How to play
- **Pick a difficulty** on the title screen: Squire, Knight or Legend.
- **Move** by clicking and holding (Diablo style) or with **WASD / arrow keys**. Merlin's **spells cast on their own** (Vampire Survivors style), led by **Chain Lightning**.
- **Blink** (right-click or **E**): teleport a short way toward the cursor — even over a wall — once every 20 seconds. It never upgrades.
- **The Circle of Avalon**: four hooded adepts follow you from the start, each with their own spell — **Frost** (frost bolts that slow), **Ember** (a cone of flame), **Thorn** (a briar field that roots and wounds the swarm) and **Light** (Mending Ward: heals and shields you). A fallen adept returns 15 s later.
- **Camelot defends itself**: all five archer towers, stout walls, a mage tower and Royal Guards at every gate from the first second. Its steward keeps spending gold on miners, the army and the rest.
- **The realm**:
  - **The War Lane** — the single direct road between Camelot and the Citadel. Both sides feed troops into it constantly; whichever side is being pushed back sends more, so the battle surges back and forth.
  - **The Royal Roads and the Kingsroad** — fast roads (you move 25% quicker on them) to treasure hubs in the far corners, each guarded by a mini-boss and a legendary hoard. **Dread garrisons** with a Garrison Captain hold every road: only cross once you can break them.
  - **Branching trails** fork off the roads through the forest and ruins to glades and **maze pockets**. Every pocket hides a reward at its heart — a **spellbook**, a **treasure chest** or a rich **gold seam** — and the minimap marks what each holds.
- **Fog**: a grey Silent Hill haze hides everything beyond a short radius. The minimap only shows foes that you, Camelot, your troops or your shrines can see.
- **The swarm**: Dread foes are fragile but numerous.
- **Loot equips itself**: if a drop beats what Merlin wears he puts it on, otherwise it's melted down for gold.
- **Ley Shrines**: capture them for gold, healing and waypoint travel (**T**).
- **The endgame**: three **Dread Wards** shield the Citadel. Bring them down, face the **Dread Lord**, and destroy the Citadel. Its **Dread Aura** halves damage to its defenders, and Merlin's spells only deal a quarter damage to the Citadel itself — the army must carry the siege.

**Keys:** RMB / E blink · SPACE / Q potion · T waypoint travel · M map · mouse wheel zoom · P pause · F fullscreen · G graphics quality · N or the speaker button (top right) to mute

## Performance
Built for laptops with integrated graphics:
- **GL Compatibility** renderer, no real-time shadows (blob shadows instead), per-vertex lighting.
- All art is generated in code as flat-shaded, vertex-coloured low-poly meshes sharing one material.
- Every unit type (both armies, miners, knights), projectile, loot drop, particle, pickup and resource type is drawn with a **single MultiMesh** — a busy fight with 200+ enemies is still only ~100 draw calls.
- No physics engine: movement uses grid collision and Dijkstra **flow fields**, so hundreds of units path through the realm cheaply. Units "think" 5–8× per second, staggered, push apart every other frame; idle lairs far from Merlin sleep (checked one frame in four and left out of the spatial index).
- The world is built in 17×17-tile chunks so off-screen terrain is culled, and units outside the camera's view aren't drawn at all.
- The fog is a single full-screen shader quad; the HUD redraws at 30 Hz.
- **Graphics quality** drops automatically if the game runs below ~42 FPS (Low renders 3D at 66% resolution and halves particles). Press **G** to cycle Low / Medium / High.
- Sound effects are synthesised at startup — there are no asset files at all.

## How it's built
- `scripts/` — everything: `maze.gd` (generation, flow fields, collision, world meshes), `models.gd` (all low-poly models), `horde.gd` (enemies & knights), `hero.gd`, `castle.gd`, `nodes.gd` (gold veins, spellbooks), `items.gd` (loot), `landmarks.gd` (wards, shrines), `fog.gd` (fog of war), `fx.gd` (projectiles, particles, pickups), `hud.gd`, `sfx.gd`.
- `.github/workflows/deploy.yml` exports the web build on every push to `main` and publishes it to the `gh-pages` branch, which GitHub Pages serves.
- Exported without threads, so it runs on GitHub Pages without special headers.

### Test hooks
Run the project with `-- --shots=DIR` to play on autopilot and save screenshots, `-- --defend` for a castle-defence test, or `-- --stress` to spawn 230 enemies and print per-system timings.
