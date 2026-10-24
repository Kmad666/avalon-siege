class_name Props
extends RefCounted
## Low-poly models for the Sigurd valley, built in code and cached.
## All are flat-shaded with vertex colours for the cel shader, and carry
## smoothed outline normals for the ink pass.

static var _cache := {}


static func _cached(key: String, builder: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]


# ------------------------------------------------------------- vegetation

const SNOW := Color(0.84, 0.86, 0.91)


static func pine() -> ArrayMesh:
	return _cached("pine", func():
		var g := Geo.new()
		g.prism(Vector3.ZERO, 0.28, 0.18, 2.2, 5, Color(0.26, 0.19, 0.15))
		var cols := [Color(0.1, 0.17, 0.14), Color(0.12, 0.2, 0.16), Color(0.14, 0.23, 0.17), Color(0.16, 0.25, 0.18)]
		var y := 1.6
		var r := 2.4
		for k in 4:
			var h := 2.9 - k * 0.3
			g.prism(Vector3(0, y, 0), r, 0.0, h, 7, cols[k], Color(0, 0, 0, 0), k * 0.45)
			# Snow lying on the upper part of each tier, slightly proud of the needles.
			var f := 0.42 if k < 3 else 0.3
			g.prism(Vector3(0, y + h * f, 0), r * (1.0 - f) + 0.08, 0.0, h * (1.0 - f) + 0.05, 7, SNOW, Color(0, 0, 0, 0), k * 0.45)
			y += 1.75 - k * 0.15
			r *= 0.74
		return g.mesh(true))


static func broadleaf() -> ArrayMesh:
	return _cached("broad", func():
		var g := Geo.new()
		g.prism(Vector3.ZERO, 0.32, 0.2, 3.0, 6, Color(0.3, 0.24, 0.19))
		g.push(Transform3D(Basis(Vector3(0, 0, 1), 0.5), Vector3(0, 2.4, 0)))
		g.prism(Vector3.ZERO, 0.12, 0.06, 1.5, 4, Color(0.3, 0.24, 0.19))
		g.pop()
		# Winter: dark twiggy crowns heaped with snow.
		g.blob(Vector3(0, 2.6, 0), 2.4, 3.0, Color(0.24, 0.21, 0.2), 71, 7, 2)
		g.blob(Vector3(0.2, 4.2, 0.1), 1.9, 1.5, SNOW, 74, 7, 1)
		g.blob(Vector3(1.1, 3.6, 0.5), 1.5, 1.9, Color(0.27, 0.23, 0.21), 72, 6, 2)
		g.blob(Vector3(1.2, 4.9, 0.5), 1.15, 0.8, SNOW, 75, 6, 1)
		g.blob(Vector3(-0.9, 3.3, -0.7), 1.4, 1.7, Color(0.22, 0.2, 0.19), 73, 6, 2)
		return g.mesh(true))


static func dead_tree() -> ArrayMesh:
	return _cached("dead", func():
		var g := Geo.new()
		var c := Color(0.17, 0.14, 0.13)
		g.prism(Vector3.ZERO, 0.32, 0.12, 4.6, 5, c)
		var branches := [[2.2, 0.9, 0.0, 1.8], [2.9, -0.8, 1.9, 1.5], [3.5, 0.7, 3.6, 1.2], [1.6, -1.0, 4.4, 1.3]]
		for b in branches:
			g.push(Transform3D(Basis(Vector3.UP, b[2]) * Basis(Vector3(0, 0, 1), b[1]), Vector3(0, b[0], 0)))
			g.prism(Vector3.ZERO, 0.11, 0.02, b[3], 4, c.lightened(0.04))
			g.pop()
		return g.mesh(true))


static func shrub() -> ArrayMesh:
	return _cached("shrub", func():
		var g := Geo.new()
		g.blob(Vector3.ZERO, 0.8, 0.9, Color(0.16, 0.22, 0.17), 81, 6, 1)
		g.blob(Vector3(0.05, 0.45, 0.0), 0.72, 0.5, SNOW, 83, 6, 1)
		g.blob(Vector3(0.5, 0, 0.3), 0.55, 0.6, SNOW.darkened(0.06), 82, 5, 1)
		return g.mesh(true))


static func boulder() -> ArrayMesh:
	return _cached("boulder", func():
		var g := Geo.new()
		g.blob(Vector3.ZERO, 1.2, 1.3, Color(0.34, 0.34, 0.37), 91, 6, 2)
		g.blob(Vector3(0.0, 0.85, 0.0), 0.95, 0.5, SNOW, 93, 6, 1)
		g.blob(Vector3(0.9, 0, 0.4), 0.6, 0.6, Color(0.31, 0.31, 0.34), 92, 5, 1)
		return g.mesh(true))


# ------------------------------------------------------------- the hooded hero

const ROBE := Color(0.38, 0.35, 0.36)
const HOOD := Color(0.31, 0.29, 0.31)
const LEATHER := Color(0.45, 0.3, 0.2)
const IRON := Color(0.58, 0.6, 0.64)
const GOLD := Color(0.86, 0.66, 0.28)
const VOID := Color(0.01, 0.01, 0.015)
const EYE := Color(1.0, 0.62, 0.18)


## The hero: a broad-shouldered hooded wanderer. Heavy robe, iron pauldrons,
## a deep cowl hiding the face. Faces +z. The eyes are a separate mesh so
## they can glow (see hero_eyes).
static func hero_body() -> ArrayMesh:
	return _cached("hero", func():
		var g := Geo.new()
		# Boots peeking out under the robe.
		for sx in [-0.13, 0.13]:
			g.box(Vector3(sx, 0.1, 0.05), Vector3(0.17, 0.2, 0.28), LEATHER.darkened(0.35))
		# Long robe: flares toward the hem, cinched at the waist.
		g.push_at(Vector3.ZERO, 0.0, Vector3(1.1, 1.0, 0.9))
		g.prism(Vector3(0, 0.12, 0), 0.4, 0.29, 0.78, 9, ROBE, Color(0, 0, 0, 0), 0.17)
		g.pop()
		# Broad chest: wider than deep, widening up to the shoulders.
		g.push_at(Vector3.ZERO, 0.0, Vector3(1.45, 1.0, 0.85))
		g.prism(Vector3(0, 0.9, 0), 0.25, 0.33, 0.44, 8, ROBE.lightened(0.04), Color(0, 0, 0, 0), 0.2)
		g.pop()
		g.box(Vector3(0, 0.92, 0), Vector3(0.74, 0.09, 0.46), LEATHER)            # belt
		g.box(Vector3(0, 0.92, 0.235), Vector3(0.11, 0.11, 0.03), GOLD)           # buckle
		g.box(Vector3(0.2, 0.62, 0.2), Vector3(0.12, 0.62, 0.02), ROBE.darkened(0.25))  # robe split
		# Leather harness across the chest.
		g.push(Transform3D(Basis(Vector3(0, 0, 1), 0.75), Vector3(0, 1.12, 0.215)))
		g.box(Vector3.ZERO, Vector3(0.08, 0.6, 0.03), LEATHER)
		g.pop()
		# Shoulders: iron pauldrons over a heavy mantle.
		g.push_at(Vector3(0, 1.3, -0.02), 0.0, Vector3(1.5, 1.0, 1.0))
		g.blob(Vector3.ZERO, 0.34, 0.16, HOOD, 211, 7, 1)
		g.pop()
		for sx in [-1.0, 1.0]:
			g.push(Transform3D(Basis(Vector3(0, 0, 1), sx * -0.45), Vector3(sx * 0.48, 1.3, 0.0)))
			g.prism(Vector3(0, -0.06, 0), 0.19, 0.12, 0.12, 7, IRON, IRON.lightened(0.1))
			g.prism(Vector3(0, -0.1, 0), 0.2, 0.2, 0.04, 7, IRON.darkened(0.25))
			g.pop()
			# Arms: wide sleeves, leather bracers, gloved fists.
			g.box(Vector3(sx * 0.53, 1.07, 0.02), Vector3(0.2, 0.34, 0.22), ROBE)
			g.box(Vector3(sx * 0.55, 0.82, 0.05), Vector3(0.17, 0.22, 0.18), LEATHER)
			g.box(Vector3(sx * 0.55, 0.82, 0.05), Vector3(0.18, 0.04, 0.19), IRON)
			g.box(Vector3(sx * 0.55, 0.65, 0.07), Vector3(0.14, 0.13, 0.15), LEATHER.darkened(0.3))
		# The cowl: a deep, peaked hood with a dark void where the face is.
		g.push_at(Vector3(0, 1.36, 0.0), 0.0, Vector3(1.0, 1.0, 1.15))
		g.prism(Vector3(0, 0.0, -0.02), 0.22, 0.2, 0.22, 8, HOOD, Color(0, 0, 0, 0), 0.2)
		g.prism(Vector3(0, 0.22, -0.02), 0.2, 0.0, 0.26, 8, HOOD, Color(0, 0, 0, 0), 0.2)
		g.pop()
		g.push(Transform3D(Basis(Vector3(1, 0, 0), -0.18), Vector3(0, 1.49, 0.2)))
		g.quad(Vector3(-0.12, -0.13, 0), Vector3(0.12, -0.13, 0), Vector3(0.1, 0.13, 0), Vector3(-0.1, 0.13, 0), VOID)
		g.pop()
		# Hood brim overhanging the face, and the drape falling to the chest.
		g.push(Transform3D(Basis(Vector3(1, 0, 0), 0.35), Vector3(0, 1.63, 0.18)))
		g.box(Vector3.ZERO, Vector3(0.3, 0.05, 0.13), HOOD.lightened(0.05))
		g.pop()
		g.push_at(Vector3(0, 1.22, 0.08), 0.0, Vector3(1.3, 1.0, 1.0))
		g.prism(Vector3.ZERO, 0.24, 0.2, 0.12, 8, HOOD, Color(0, 0, 0, 0), 0.2)
		g.pop()
		# Gram's hilt at the left hip.
		g.push(Transform3D(Basis(Vector3(1, 0, 0), 0.5), Vector3(-0.4, 0.82, 0.05)))
		g.box(Vector3(0, -0.36, 0), Vector3(0.07, 0.72, 0.04), LEATHER.darkened(0.3))
		g.box(Vector3(0, 0.05, 0), Vector3(0.22, 0.04, 0.05), GOLD)
		g.box(Vector3(0, 0.15, 0), Vector3(0.04, 0.16, 0.04), LEATHER)
		g.box(Vector3(0, 0.25, 0), Vector3(0.07, 0.05, 0.07), GOLD)
		g.pop()
		return g.mesh(true))


## Two glowing eyes in the dark of the hood (drawn unshaded).
static func hero_eyes() -> ArrayMesh:
	return _cached("hero_eyes", func():
		var g := Geo.new()
		g.push(Transform3D(Basis(Vector3(1, 0, 0), -0.18), Vector3(0, 1.5, 0.205)))
		for sd in [-1.0, 1.0]:
			# Slanted slits, inner corners lower: a hard, narrowed stare.
			var o := Vector3(sd * 0.095, 0.014, 0)
			var i := Vector3(sd * 0.022, -0.004, 0)
			var h := Vector3(0, 0.022, 0)
			g.quad(o, i, i - h, o - h * 0.6, EYE)
			g.quad(o - h * 0.6, i - h, i, o, EYE)
		g.pop()
		return g.mesh(false))


## A soft additive haze around the eyes so they read from a distance.
static func hero_eye_haze() -> ArrayMesh:
	return _cached("hero_eye_haze", func():
		var g := Geo.new()
		g.push(Transform3D(Basis(Vector3(1, 0, 0), -0.18), Vector3(0, 1.5, 0.21)))
		var c := Color(EYE.r * 0.45, EYE.g * 0.3, EYE.b * 0.15)
		for sd in [-1.0, 1.0]:
			var m := Vector3(sd * 0.058, 0.004, 0)
			for k in 8:
				var a0 := TAU * k / 8.0
				var a1 := TAU * (k + 1) / 8.0
				g.tri(m, m + Vector3(cos(a0) * 0.085, sin(a0) * 0.05, 0), m + Vector3(cos(a1) * 0.085, sin(a1) * 0.05, 0), c)
				g.tri(m, m + Vector3(cos(a1) * 0.085, sin(a1) * 0.05, 0), m + Vector3(cos(a0) * 0.085, sin(a0) * 0.05, 0), c)
		g.pop()
		return g.mesh(false))


## The cloak, hung from the shoulders (pivot at the neck) so it can stream.
## Ragged at the hem.
static func hero_cloak() -> ArrayMesh:
	return _cached("cloak", func():
		var g := Geo.new()
		var c := HOOD.lightened(0.02)
		var top := 0.0
		var bot := -1.12
		var n := 7
		for i in n:
			var u0 := float(i) / n
			var u1 := float(i + 1) / n
			var x0t := lerpf(-0.42, 0.42, u0)
			var x1t := lerpf(-0.42, 0.42, u1)
			var x0b := lerpf(-0.56, 0.56, u0)
			var x1b := lerpf(-0.56, 0.56, u1)
			var b0 := bot + (0.0 if i % 2 == 0 else 0.1)
			var b1 := bot + (0.1 if i % 2 == 0 else 0.0)
			var tip := bot - 0.08 - 0.06 * float((i * 7) % 3)
			var xm := (x0b + x1b) * 0.5
			# Outer and inner faces of each strip, then a ragged point.
			g.quad(Vector3(x0t, top, 0), Vector3(x1t, top, 0), Vector3(x1b, b1, -0.08), Vector3(x0b, b0, -0.08), c)
			g.quad(Vector3(x0b, b0, -0.09), Vector3(x1b, b1, -0.09), Vector3(x1t, top, -0.01), Vector3(x0t, top, -0.01), c.darkened(0.35))
			g.tri(Vector3(x0b, b0, -0.08), Vector3(x1b, b1, -0.08), Vector3(xm, tip, -0.09), c)
			g.tri(Vector3(x1b, b1, -0.09), Vector3(x0b, b0, -0.09), Vector3(xm, tip, -0.1), c.darkened(0.35))
		return g.mesh(true))


# ------------------------------------------------------------- set pieces

## Regin's forge: a turf-roofed smithy, its hearth still glowing, an anvil
## outside where Gram was remade from Sigmund's shards.
static func forge() -> ArrayMesh:
	return _cached("forge", func():
		var g := Geo.new()
		var wood := Color(0.32, 0.22, 0.16)
		var stone := Color(0.38, 0.37, 0.38)
		g.box(Vector3(0, 0.3, 0), Vector3(7.0, 0.6, 5.0), stone, stone.lightened(0.05))   # footing
		g.box(Vector3(0, 1.6, 0), Vector3(6.4, 2.0, 4.4), wood, wood.lightened(0.05))
		for sx in [-3.2, 3.2]:
			for sz in [-2.2, 2.2]:
				g.box(Vector3(sx, 1.6, sz), Vector3(0.35, 2.4, 0.35), wood.darkened(0.2))
		# Turf roof under a thick layer of snow.
		g.push_at(Vector3(0, 2.6, 0))
		g.quad(Vector3(-3.8, 0, -2.8), Vector3(-3.8, 0, 2.8), Vector3(0, 1.8, 2.8), Vector3(0, 1.8, -2.8), SNOW.darkened(0.04))
		g.quad(Vector3(0, 1.8, -2.8), Vector3(0, 1.8, 2.8), Vector3(3.8, 0, 2.8), Vector3(3.8, 0, -2.8), SNOW.darkened(0.08))
		g.tri(Vector3(-3.8, 0, 2.8), Vector3(3.8, 0, 2.8), Vector3(0, 1.8, 2.8), wood)
		g.tri(Vector3(3.8, 0, -2.8), Vector3(-3.8, 0, -2.8), Vector3(0, 1.8, -2.8), wood)
		g.pop()
		# Door and the forge-glow window.
		g.box(Vector3(-1.4, 1.2, 2.22), Vector3(1.1, 1.8, 0.05), Color(0.16, 0.11, 0.08))
		g.box(Vector3(1.6, 1.5, 2.22), Vector3(1.0, 0.7, 0.05), Color(1.0, 0.5, 0.15))
		# Chimney.
		g.box(Vector3(2.2, 4.0, -0.8), Vector3(0.8, 2.2, 0.8), stone)
		# Anvil on a stump, quench barrel.
		g.prism(Vector3(1.8, 0, 4.0), 0.4, 0.36, 0.6, 7, wood)
		g.box(Vector3(1.8, 0.75, 4.0), Vector3(0.7, 0.25, 0.3), Color(0.22, 0.22, 0.25))
		g.box(Vector3(2.25, 0.8, 4.0), Vector3(0.25, 0.12, 0.18), Color(0.22, 0.22, 0.25))
		g.prism(Vector3(-0.2, 0, 4.2), 0.42, 0.42, 0.85, 8, wood.lightened(0.05), Color(0.1, 0.14, 0.18))
		# Woodpile.
		for k in 4:
			g.box(Vector3(-3.0, 0.2 + k * 0.25, 3.2), Vector3(1.6, 0.22, 0.22), wood.lightened(0.08 * (k % 2)))
		return g.mesh(true))


## A runestone carved with the tale, red-painted grooves.
static func runestone() -> ArrayMesh:
	return _cached("runestone", func():
		var g := Geo.new()
		g.prism(Vector3.ZERO, 0.55, 0.32, 2.6, 5, Color(0.42, 0.41, 0.42), Color(0, 0, 0, 0), 0.4)
		g.box(Vector3(0, 1.3, 0.37), Vector3(0.08, 1.6, 0.03), Color(0.55, 0.12, 0.1))
		g.box(Vector3(0, 1.8, 0.36), Vector3(0.5, 0.06, 0.03), Color(0.55, 0.12, 0.1))
		g.box(Vector3(0, 1.0, 0.36), Vector3(0.4, 0.06, 0.03), Color(0.55, 0.12, 0.1))
		return g.mesh(true))


## A standing stone for the ring.
static func standing_stone() -> ArrayMesh:
	return _cached("standing", func():
		var g := Geo.new()
		g.prism(Vector3.ZERO, 0.75, 0.45, 3.6, 4, Color(0.4, 0.4, 0.42), Color(0, 0, 0, 0), 0.3)
		return g.mesh(true))


## A burial mound's kerb stones and its dark doorway.
static func mound_door() -> ArrayMesh:
	return _cached("mound_door", func():
		var g := Geo.new()
		var st := Color(0.38, 0.37, 0.39)
		g.box(Vector3(-0.8, 0.8, 0), Vector3(0.5, 1.6, 0.5), st)
		g.box(Vector3(0.8, 0.8, 0), Vector3(0.5, 1.6, 0.5), st)
		g.box(Vector3(0, 1.75, 0), Vector3(2.3, 0.4, 0.6), st)
		g.box(Vector3(0, 0.75, -0.05), Vector3(1.1, 1.5, 0.3), Color(0.03, 0.03, 0.04))
		return g.mesh(true))


## Fafnir's lair: a jagged arch of black rock around the cave mouth.
static func cave_arch() -> ArrayMesh:
	return _cached("cave", func():
		var g := Geo.new()
		var rock := Color(0.3, 0.27, 0.27)
		for k in 9:
			var a := PI * float(k) / 8.0
			var p := Vector3(cos(a) * 7.0, sin(a) * 6.5, 0)
			g.blob(p + Vector3(0, -1.2, 0), 2.2, 3.2, rock.lightened(0.03 * (k % 3)), 110 + k, 6, 2)
		# The darkness within, and a pair of great claw-gouges either side.
		g.box(Vector3(0, 2.6, -2.0), Vector3(11.0, 7.0, 0.4), Color(0.01, 0.01, 0.02))
		for sx in [-1.0, 1.0]:
			for k in 3:
				g.box(Vector3(sx * (8.6 + k * 0.5), 2.0 + k * 0.4, 0.6), Vector3(0.25, 3.0, 0.3), Color(0.08, 0.06, 0.06))
		return g.mesh(true))


## The glint of the hoard, spilling out of the cave mouth.
static func hoard() -> ArrayMesh:
	return _cached("hoard", func():
		var g := Geo.new()
		var gold := Color(0.95, 0.72, 0.25)
		g.blob(Vector3.ZERO, 3.2, 1.1, gold.darkened(0.1), 121, 9, 2)
		g.blob(Vector3(1.8, 0, 1.0), 1.6, 0.7, gold, 122, 7, 1)
		g.blob(Vector3(-2.0, 0, 0.6), 1.4, 0.6, gold, 123, 7, 1)
		var rr := RandomNumberGenerator.new()
		rr.seed = 7
		for k in 14:
			var p := Vector3(rr.randf_range(-3.5, 3.5), rr.randf_range(0.2, 0.9), rr.randf_range(-1.5, 2.5))
			if k % 3 == 0:
				g.box(p, Vector3(0.5, 0.4, 0.35), Color(0.45, 0.28, 0.15), gold)       # chest
			elif k % 3 == 1:
				g.prism(p, 0.18, 0.1, 0.35, 6, gold.lightened(0.15))                    # goblet
			else:
				g.shard(p, 0.12, 0.35, Color(0.7, 0.15, 0.2))                           # gem
		return g.mesh(true))


## Bones of those who came for the gold before you.
static func bones() -> ArrayMesh:
	return _cached("bones", func():
		var g := Geo.new()
		var b := Color(0.82, 0.78, 0.68)
		g.box(Vector3(0, 0.12, 0), Vector3(0.28, 0.24, 0.3), b)                  # skull
		g.box(Vector3(0.05, 0.12, 0.16), Vector3(0.18, 0.06, 0.02), Color(0.1, 0.08, 0.07))
		g.box(Vector3(0.6, 0.05, 0.1), Vector3(0.9, 0.08, 0.1), b)
		g.box(Vector3(0.4, 0.05, -0.4), Vector3(0.1, 0.08, 0.8), b)
		for k in 4:
			g.box(Vector3(-0.5 + k * 0.12, 0.08, -0.2), Vector3(0.05, 0.12, 0.5), b.darkened(0.08))
		g.box(Vector3(-0.9, 0.05, 0.4), Vector3(0.7, 0.06, 0.08), Color(0.5, 0.5, 0.54))   # rusted sword
		return g.mesh(true))


## A camp fire with a ring of stones (beside the forge).
static func campfire() -> ArrayMesh:
	return _cached("campfire", func():
		var g := Geo.new()
		for k in 8:
			var a := k * TAU / 8.0
			g.blob(Vector3(cos(a) * 0.8, 0, sin(a) * 0.8), 0.22, 0.25, Color(0.4, 0.39, 0.4), 130 + k, 5, 1)
		g.box(Vector3(0, 0.12, 0), Vector3(1.0, 0.14, 0.16), Color(0.25, 0.17, 0.12))
		g.box(Vector3(0, 0.15, 0), Vector3(0.16, 0.14, 1.0), Color(0.25, 0.17, 0.12))
		return g.mesh(true))


static func flame() -> ArrayMesh:
	return _cached("flame", func():
		var g := Geo.new()
		g.shard(Vector3.ZERO, 0.35, 1.0, Color(1.0, 0.55, 0.15))
		g.shard(Vector3(0.15, 0, 0.1), 0.2, 0.7, Color(1.0, 0.8, 0.3))
		return g.mesh(false))
