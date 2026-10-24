# Fafnir's Bane

A cel-shaded, dark-fantasy third-person adventure made in **Godot 4.7**, playable in the browser. Inspired by the legend of **Sigurd** (Siegfried) and the wurm **Fafnir**.

**Play:** https://kmad666.github.io/avalon-siege/

> Current build: **map preview**. There are no enemies or mechanics yet — Sigurd flies freely so the valley can be inspected as it's built.

## The valley
A long, snowbound valley (~1 km by 190 m) walled in by mountains. The road winds from the south to the north between medium hills thick with snow-laden pine:

1. **Regin's Forge** — the start: the smith's turf-roofed forge, still glowing, where Gram was remade.
2. **The Barrows** — burial mounds with stone doorways.
3. **The Stone Ring** — nine standing stones beside the road.
4. **The Wurm's Pool** — the frozen pool where Fafnir drinks; the scorched furrow of his trail leads up to it (where Sigurd dug his pit).
5. **Gnitaheath** — the forest withers into a blasted heath of dead trees and bones.
6. **Fafnir's Lair** — a great cave under the northern cliffs, its hoard glinting in the dark.

Runestones mark the road along the way.

## Controls (preview)
- **Click** to capture the mouse and look around · **Esc** frees the cursor (or hold right-click to look)
- **WASD** fly · **Space / E** up · **C / Q** down · **Shift** faster · **mouse wheel** camera distance
- **1–6** jump to a landmark · **G** graphics quality · **F** fullscreen · **N** or the speaker button to mute · **H** hide the HUD

## Look
- **Cel shading:** a custom toon shader with three hard light bands, crisp shadow edges and a hot rim light from the low sun. An **ink-outline** pass (inverted hull with smoothed normals, so hard edges don't crack) traces every model.
- **Deep winter:** an iron-grey overcast, a weak sun behind the cloud, deep snow on the ground and heaped on the pines, the pool frozen over, snow falling, and heavy freezing fog that swallows the valley a short way ahead. The wurm's trail has melted the snow down to black earth.
- **The hero:** a broad-shouldered hooded wanderer — iron pauldrons, a ragged cloak, and only two burning eyes in the dark of the cowl. A light rim traces his silhouette.
- Everything — terrain, trees, the hero, the forge, the lair — is low-poly geometry generated in code, coloured by vertex. No texture or model files.

## Performance
Built for laptops with integrated graphics (GL Compatibility renderer):
- Terrain is built in 64 m chunks so the camera culls what's off-screen; trees, shrubs and rocks are one **MultiMesh** per chunk per kind, with a visibility range hidden by the haze.
- **Graphics quality** (G): *Low* = no shadows or outlines, 70% render scale · *Medium* = one shadow cascade + outlines · *High* = two cascades + MSAA. It drops automatically if the game runs below ~40 FPS.

## How it's built
- `scripts/terrain.gd` — the valley: heightfield, path, biomes, scatter, chunked meshes
- `scripts/props.gd` — all models (the hero, trees, forge, runestones, lair, hoard…)
- `scripts/toon.gd` — the cel and outline shaders
- `scripts/flyer.gd` — the hero's free flight and the chase camera
- `scripts/main.gd` — lighting, landmarks, quality; `scripts/hud.gd` — overlay and strip map; `scripts/sfx.gd` — wind ambience; `scripts/geo.gd` — low-poly mesh builder
- `.github/workflows/deploy.yml` exports the web build on every push to `main` and publishes it to GitHub Pages.

The previous game in this repo, *Avalon Siege*, is preserved on the `avalon-siege-legacy` branch.

### Test hook
Run with `-- --shots=DIR` to photograph a fixed set of viewpoints across the valley.
