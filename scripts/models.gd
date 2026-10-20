class_name Models
extends RefCounted
## All low-poly art, built in code once and cached.

static var _cache := {}

const SHADOW := Color(0.1, 0.13, 0.08)


static func _cached(key: String, builder: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]


# ------------------------------------------------------------- scenery

static func tree_mesh() -> ArrayMesh:
	return _cached("tree", func():
		var g := Geo.new()
		g.prism(Vector3.ZERO, 0.16, 0.12, 0.6, 5, Color(0.4, 0.27, 0.17))
		g.prism(Vector3(0, 0.45, 0), 0.95, 0.0, 1.1, 6, Color(0.16, 0.4, 0.2), Color(0, 0, 0, 0), 0.3)
		g.prism(Vector3(0, 0.95, 0), 0.75, 0.0, 0.95, 6, Color(0.19, 0.46, 0.22), Color(0, 0, 0, 0), 0.8)
		g.prism(Vector3(0, 1.4, 0), 0.5, 0.0, 0.8, 6, Color(0.24, 0.52, 0.25), Color(0, 0, 0, 0), 0.1)
		return g.mesh())


static func dead_tree_mesh() -> ArrayMesh:
	return _cached("dead_tree", func():
		var g := Geo.new()
		var c := Color(0.25, 0.2, 0.18)
		g.prism(Vector3.ZERO, 0.18, 0.08, 1.6, 4, c)
		g.push(Transform3D(Basis(Vector3(0, 0, 1), 0.8), Vector3(0, 0.9, 0)))
		g.prism(Vector3.ZERO, 0.07, 0.02, 0.7, 4, c)
		g.pop()
		g.push(Transform3D(Basis(Vector3(1, 0, 0), -0.7), Vector3(0, 1.1, 0)))
		g.prism(Vector3.ZERO, 0.06, 0.02, 0.6, 4, c)
		g.pop()
		return g.mesh())


# ------------------------------------------------------------- resources

## Lumber: a broad golden oak, clearly different from the wall pines.
static func lumber_mesh() -> ArrayMesh:
	return _cached("lumber", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.02, 0), 1.1, 8, SHADOW)
		g.prism(Vector3.ZERO, 0.28, 0.2, 1.0, 6, Color(0.5, 0.33, 0.2))
		g.blob(Vector3(0, 0.85, 0), 1.1, 1.3, Color(0.62, 0.62, 0.22), 11, 7, 2)
		g.blob(Vector3(0.35, 1.3, 0.2), 0.7, 0.9, Color(0.7, 0.66, 0.25), 12, 6, 2)
		g.box(Vector3(0.7, 0.15, 0.55), Vector3(0.7, 0.25, 0.25), Color(0.55, 0.38, 0.24))  # chopped log
		return g.mesh())


static func ore_mesh() -> ArrayMesh:
	return _cached("ore", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.02, 0), 1.0, 8, SHADOW)
		g.blob(Vector3.ZERO, 0.95, 0.9, Color(0.48, 0.46, 0.45), 21, 6, 2)
		g.blob(Vector3(0.6, 0, 0.4), 0.5, 0.5, Color(0.44, 0.42, 0.42), 22, 5, 1)
		var gold := Color(1.0, 0.8, 0.25)
		g.shard(Vector3(0.1, 0.55, 0.45), 0.13, 0.35, gold, Vector3(0.05, 0, 0.12))
		g.shard(Vector3(-0.45, 0.4, 0.2), 0.11, 0.3, gold, Vector3(-0.12, 0, 0.05))
		g.shard(Vector3(0.45, 0.6, -0.2), 0.12, 0.32, gold, Vector3(0.1, 0, -0.05))
		g.shard(Vector3(0.7, 0.35, 0.55), 0.09, 0.25, gold)
		return g.mesh())


static func crystal_mesh() -> ArrayMesh:
	return _cached("crystal", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.02, 0), 0.95, 8, SHADOW)
		g.blob(Vector3.ZERO, 0.7, 0.3, Color(0.35, 0.33, 0.38), 31, 6, 1)
		var c := Color(0.62, 0.45, 1.0)
		g.shard(Vector3(0, 0.1, 0), 0.32, 1.7, c, Vector3(0.05, 0, 0))
		g.shard(Vector3(0.4, 0.05, 0.2), 0.2, 1.05, c.lightened(0.15), Vector3(0.35, 0, 0.15))
		g.shard(Vector3(-0.35, 0.05, 0.25), 0.22, 1.2, c.darkened(0.1), Vector3(-0.3, 0, 0.2))
		g.shard(Vector3(0.1, 0.05, -0.4), 0.18, 0.9, Color(0.45, 0.85, 1.0), Vector3(0.1, 0, -0.3))
		return g.mesh())


static func stump_mesh() -> ArrayMesh:
	return _cached("stump", func():
		var g := Geo.new()
		g.prism(Vector3.ZERO, 0.3, 0.26, 0.3, 6, Color(0.5, 0.33, 0.2), Color(0.8, 0.65, 0.42))
		return g.mesh())


# ------------------------------------------------------------- hero

static func hero_body() -> ArrayMesh:
	return _cached("hero_body", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.5, 8, SHADOW)
		var steel := Color(0.72, 0.74, 0.8)
		var blue := Color(0.2, 0.36, 0.8)
		# legs
		g.box(Vector3(-0.13, 0.25, 0), Vector3(0.16, 0.5, 0.2), Color(0.3, 0.25, 0.22))
		g.box(Vector3(0.13, 0.25, 0), Vector3(0.16, 0.5, 0.2), Color(0.3, 0.25, 0.22))
		# tabard + armour
		g.prism(Vector3(0, 0.45, 0), 0.32, 0.28, 0.55, 6, blue, Color(0, 0, 0, 0), 0.52)
		g.box(Vector3(0, 0.88, 0), Vector3(0.5, 0.3, 0.32), steel)
		g.box(Vector3(-0.32, 0.92, 0), Vector3(0.18, 0.18, 0.22), steel.lightened(0.1))
		g.box(Vector3(0.32, 0.92, 0), Vector3(0.18, 0.18, 0.22), steel.lightened(0.1))
		g.box(Vector3(0, 0.7, 0.17), Vector3(0.12, 0.25, 0.02), Color(0.95, 0.8, 0.3))  # gold cross
		# head + helm
		g.box(Vector3(0, 1.17, 0), Vector3(0.26, 0.26, 0.26), Color(0.92, 0.75, 0.6))
		g.prism(Vector3(0, 1.2, 0), 0.2, 0.17, 0.2, 6, steel)
		g.prism(Vector3(0, 1.4, 0), 0.17, 0.0, 0.12, 6, steel.lightened(0.1))
		g.box(Vector3(0, 1.17, 0.14), Vector3(0.2, 0.05, 0.04), Color(0.15, 0.15, 0.18))  # visor slit
		g.prism(Vector3(0, 1.45, -0.05), 0.05, 0.02, 0.32, 4, Color(0.85, 0.15, 0.15))     # plume
		# cape
		g.quad(Vector3(-0.24, 1.0, -0.17), Vector3(0.24, 1.0, -0.17), Vector3(0.3, 0.25, -0.34), Vector3(-0.3, 0.25, -0.34), Color(0.7, 0.13, 0.15))
		g.quad(Vector3(-0.3, 0.25, -0.33), Vector3(0.3, 0.25, -0.33), Vector3(0.24, 1.0, -0.16), Vector3(-0.24, 1.0, -0.16), Color(0.5, 0.1, 0.12))
		return g.mesh())


static func hero_sword() -> ArrayMesh:
	return _cached("hero_sword", func():
		var g := Geo.new()
		g.box(Vector3(0, 0, 0.08), Vector3(0.06, 0.06, 0.2), Color(0.35, 0.22, 0.15))
		g.box(Vector3(0, 0, 0.2), Vector3(0.3, 0.06, 0.06), Color(0.95, 0.8, 0.3))
		g.box(Vector3(0, 0, 0.62), Vector3(0.1, 0.03, 0.8), Color(0.88, 0.9, 0.96))
		g.prism(Vector3(0, 0, 1.02), 0.05, 0.0, 0.0, 4, Color.WHITE)
		return g.mesh())


static func hero_shield() -> ArrayMesh:
	return _cached("hero_shield", func():
		var g := Geo.new()
		g.box(Vector3.ZERO, Vector3(0.08, 0.5, 0.4), Color(0.2, 0.36, 0.8), Color(0.8, 0.8, 0.85))
		g.box(Vector3(0.05, 0, 0), Vector3(0.02, 0.32, 0.08), Color(0.95, 0.8, 0.3))
		g.box(Vector3(0.05, 0.04, 0), Vector3(0.02, 0.08, 0.26), Color(0.95, 0.8, 0.3))
		return g.mesh())


# ------------------------------------------------------------- units

static func ally_mesh() -> ArrayMesh:
	return _cached("ally", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.45, 8, SHADOW)
		var steel := Color(0.65, 0.68, 0.74)
		g.box(Vector3(-0.11, 0.22, 0), Vector3(0.14, 0.44, 0.18), Color(0.28, 0.24, 0.22))
		g.box(Vector3(0.11, 0.22, 0), Vector3(0.14, 0.44, 0.18), Color(0.28, 0.24, 0.22))
		g.prism(Vector3(0, 0.4, 0), 0.28, 0.24, 0.5, 6, Color(0.85, 0.85, 0.9), Color(0, 0, 0, 0), 0.52)
		g.box(Vector3(0, 0.8, 0), Vector3(0.42, 0.26, 0.28), steel)
		g.box(Vector3(0, 0.65, 0.15), Vector3(0.24, 0.07, 0.02), Color(0.2, 0.36, 0.8))
		g.prism(Vector3(0, 0.95, 0), 0.17, 0.15, 0.3, 6, steel)
		g.box(Vector3(0, 1.08, 0.12), Vector3(0.18, 0.04, 0.05), Color(0.1, 0.1, 0.12))
		# spear
		g.box(Vector3(0.28, 0.8, 0.25), Vector3(0.05, 0.05, 1.3), Color(0.45, 0.32, 0.2))
		g.push_at(Vector3(0.28, 0.8, 0.9))
		g.push(Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5), Vector3.ZERO))
		g.prism(Vector3.ZERO, 0.07, 0.0, 0.25, 4, Color(0.9, 0.9, 0.95))
		g.pop()
		g.pop()
		g.box(Vector3(-0.28, 0.65, 0.05), Vector3(0.06, 0.4, 0.32), Color(0.2, 0.36, 0.8), Color(0.9, 0.85, 0.5))
		return g.mesh())


static func goblin_mesh() -> ArrayMesh:
	return _cached("goblin", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.38, 7, SHADOW)
		var skin := Color(0.45, 0.65, 0.25)
		g.box(Vector3(-0.09, 0.15, 0), Vector3(0.11, 0.3, 0.13), Color(0.3, 0.22, 0.15))
		g.box(Vector3(0.09, 0.15, 0), Vector3(0.11, 0.3, 0.13), Color(0.3, 0.22, 0.15))
		g.prism(Vector3(0, 0.28, 0), 0.22, 0.18, 0.32, 5, Color(0.5, 0.36, 0.22))
		g.box(Vector3(0, 0.72, 0.03), Vector3(0.34, 0.28, 0.3), skin)
		# big ears
		g.tri(Vector3(-0.17, 0.78, 0), Vector3(-0.4, 0.88, -0.05), Vector3(-0.17, 0.68, 0), skin.darkened(0.1))
		g.tri(Vector3(0.17, 0.78, 0), Vector3(0.17, 0.68, 0), Vector3(0.4, 0.88, -0.05), skin.darkened(0.1))
		g.tri(Vector3(-0.17, 0.78, 0), Vector3(-0.17, 0.68, 0), Vector3(-0.4, 0.88, -0.05), skin.darkened(0.2))
		g.tri(Vector3(0.17, 0.78, 0), Vector3(0.4, 0.88, -0.05), Vector3(0.17, 0.68, 0), skin.darkened(0.2))
		g.box(Vector3(-0.08, 0.76, 0.19), Vector3(0.07, 0.05, 0.02), Color(1, 0.85, 0.1))
		g.box(Vector3(0.08, 0.76, 0.19), Vector3(0.07, 0.05, 0.02), Color(1, 0.85, 0.1))
		# dagger
		g.box(Vector3(0.22, 0.4, 0.2), Vector3(0.04, 0.04, 0.4), Color(0.75, 0.75, 0.78))
		return g.mesh())


static func orc_mesh() -> ArrayMesh:
	return _cached("orc", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.55, 8, SHADOW)
		var skin := Color(0.38, 0.52, 0.3)
		g.box(Vector3(-0.15, 0.25, 0), Vector3(0.2, 0.5, 0.24), Color(0.25, 0.2, 0.17))
		g.box(Vector3(0.15, 0.25, 0), Vector3(0.2, 0.5, 0.24), Color(0.25, 0.2, 0.17))
		g.box(Vector3(0, 0.78, 0), Vector3(0.66, 0.6, 0.42), Color(0.42, 0.28, 0.2), Color(0.5, 0.35, 0.25))
		g.box(Vector3(-0.42, 0.85, 0), Vector3(0.22, 0.24, 0.3), Color(0.35, 0.35, 0.38))
		g.box(Vector3(0.42, 0.85, 0), Vector3(0.22, 0.24, 0.3), Color(0.35, 0.35, 0.38))
		g.box(Vector3(0, 1.22, 0.05), Vector3(0.36, 0.32, 0.34), skin)
		g.box(Vector3(-0.1, 1.11, 0.23), Vector3(0.05, 0.1, 0.04), Color(0.95, 0.92, 0.8))
		g.box(Vector3(0.1, 1.11, 0.23), Vector3(0.05, 0.1, 0.04), Color(0.95, 0.92, 0.8))
		g.box(Vector3(0, 1.28, 0.22), Vector3(0.26, 0.05, 0.02), Color(0.9, 0.15, 0.1))
		# axe
		g.box(Vector3(0.48, 0.65, 0.3), Vector3(0.06, 0.06, 0.8), Color(0.4, 0.28, 0.18))
		g.box(Vector3(0.48, 0.65, 0.66), Vector3(0.04, 0.4, 0.2), Color(0.7, 0.7, 0.74))
		return g.mesh())


static func skeleton_mesh() -> ArrayMesh:
	return _cached("skeleton", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.4, 7, SHADOW)
		var bone := Color(0.9, 0.88, 0.78)
		g.box(Vector3(-0.09, 0.25, 0), Vector3(0.07, 0.5, 0.07), bone)
		g.box(Vector3(0.09, 0.25, 0), Vector3(0.07, 0.5, 0.07), bone)
		g.box(Vector3(0, 0.52, 0), Vector3(0.28, 0.08, 0.14), bone)
		g.box(Vector3(0, 0.66, 0), Vector3(0.06, 0.24, 0.06), bone)
		for k in 3:
			g.box(Vector3(0, 0.72 + k * 0.08, 0), Vector3(0.3 - k * 0.02, 0.04, 0.18), bone.darkened(0.08))
		g.box(Vector3(0, 1.05, 0.02), Vector3(0.26, 0.26, 0.26), bone)
		g.box(Vector3(-0.06, 1.06, 0.14), Vector3(0.07, 0.07, 0.02), Color(0.9, 0.2, 0.15))
		g.box(Vector3(0.06, 1.06, 0.14), Vector3(0.07, 0.07, 0.02), Color(0.9, 0.2, 0.15))
		g.prism(Vector3(0, 1.17, 0.02), 0.2, 0.06, 0.18, 5, Color(0.3, 0.2, 0.35))  # hood
		# bow
		g.box(Vector3(-0.25, 0.8, 0.2), Vector3(0.04, 0.8, 0.05), Color(0.45, 0.3, 0.2))
		g.box(Vector3(-0.25, 1.22, 0.14), Vector3(0.04, 0.1, 0.12), Color(0.45, 0.3, 0.2))
		g.box(Vector3(-0.25, 0.38, 0.14), Vector3(0.04, 0.1, 0.12), Color(0.45, 0.3, 0.2))
		return g.mesh())


static func ogre_mesh() -> ArrayMesh:
	return _cached("ogre", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.95, 9, SHADOW)
		var skin := Color(0.62, 0.5, 0.4)
		g.box(Vector3(-0.3, 0.4, 0), Vector3(0.36, 0.8, 0.4), skin.darkened(0.15))
		g.box(Vector3(0.3, 0.4, 0), Vector3(0.36, 0.8, 0.4), skin.darkened(0.15))
		g.prism(Vector3(0, 0.6, 0), 0.7, 0.55, 0.6, 7, Color(0.45, 0.32, 0.22))
		g.blob(Vector3(0, 1.0, 0), 0.75, 1.0, skin, 41, 7, 2)
		g.box(Vector3(0, 2.0, 0.25), Vector3(0.45, 0.4, 0.4), skin.lightened(0.05))
		g.box(Vector3(-0.1, 2.05, 0.46), Vector3(0.08, 0.06, 0.02), Color(1, 0.6, 0.1))
		g.box(Vector3(0.1, 2.05, 0.46), Vector3(0.08, 0.06, 0.02), Color(1, 0.6, 0.1))
		g.box(Vector3(-0.75, 1.3, 0.1), Vector3(0.3, 0.8, 0.3), skin)
		g.box(Vector3(0.75, 1.3, 0.1), Vector3(0.3, 0.8, 0.3), skin)
		# club
		g.push_at(Vector3(0.8, 0.9, 0.45))
		g.push(Transform3D(Basis(Vector3(1, 0, 0), 1.2), Vector3.ZERO))
		g.prism(Vector3.ZERO, 0.1, 0.25, 1.4, 6, Color(0.45, 0.3, 0.18))
		g.pop()
		g.pop()
		return g.mesh())


static func dark_knight_mesh() -> ArrayMesh:
	return _cached("dark_knight", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.7, 8, SHADOW)
		var plate := Color(0.2, 0.18, 0.22)
		var red := Color(0.8, 0.12, 0.12)
		g.box(Vector3(-0.17, 0.32, 0), Vector3(0.22, 0.64, 0.26), plate)
		g.box(Vector3(0.17, 0.32, 0), Vector3(0.22, 0.64, 0.26), plate)
		g.prism(Vector3(0, 0.55, 0), 0.42, 0.36, 0.55, 6, red.darkened(0.3), Color(0, 0, 0, 0), 0.52)
		g.box(Vector3(0, 1.1, 0), Vector3(0.7, 0.45, 0.42), plate)
		g.prism(Vector3(-0.42, 1.25, 0), 0.14, 0.0, 0.4, 4, plate.lightened(0.2))
		g.prism(Vector3(0.42, 1.25, 0), 0.14, 0.0, 0.4, 4, plate.lightened(0.2))
		g.box(Vector3(0, 1.55, 0), Vector3(0.34, 0.38, 0.34), plate)
		g.box(Vector3(0, 1.57, 0.18), Vector3(0.24, 0.05, 0.02), Color(1, 0.25, 0.1))
		g.prism(Vector3(-0.14, 1.7, 0), 0.06, 0.0, 0.35, 4, Color(0.85, 0.82, 0.75))
		g.prism(Vector3(0.14, 1.7, 0), 0.06, 0.0, 0.35, 4, Color(0.85, 0.82, 0.75))
		g.quad(Vector3(-0.32, 1.3, -0.22), Vector3(0.32, 1.3, -0.22), Vector3(0.4, 0.2, -0.45), Vector3(-0.4, 0.2, -0.45), red.darkened(0.2))
		g.quad(Vector3(-0.4, 0.2, -0.44), Vector3(0.4, 0.2, -0.44), Vector3(0.32, 1.3, -0.21), Vector3(-0.32, 1.3, -0.21), red.darkened(0.45))
		# greatsword
		g.box(Vector3(0.48, 0.9, 0.55), Vector3(0.14, 0.04, 1.3), Color(0.55, 0.55, 0.6))
		g.box(Vector3(0.48, 0.9, -0.12), Vector3(0.36, 0.08, 0.08), red)
		return g.mesh())


# ------------------------------------------------------------- fortresses

static func castle_mesh() -> ArrayMesh:
	return _cached("castle", func():
		var g := Geo.new()
		var stone := Color(0.8, 0.77, 0.7)
		var dark := Color(0.62, 0.59, 0.54)
		var roof := Color(0.22, 0.4, 0.82)
		var C := 3.3
		# plinth
		g.box(Vector3(0, 0.15, 0), Vector3(8.8, 0.3, 8.8), dark, dark.lightened(0.1))
		# curtain walls between the corner towers, gates facing the maze (-x, -z)
		for side in 4:
			g.push_at(Vector3.ZERO, side * PI * 0.5)
			var gate := side == 2 or side == 3
			if gate:
				for seg in [-1, 1]:
					g.box(Vector3(seg * 2.05, 1.2, C), Vector3(1.9, 2.4, 0.7), stone, dark.lightened(0.15))
				g.box(Vector3(0, 2.15, C), Vector3(2.4, 0.5, 0.7), stone)
				g.box(Vector3(0, 0.95, C + 0.05), Vector3(2.0, 1.9, 0.6), Color(0.4, 0.27, 0.16))
			else:
				g.box(Vector3(0, 1.2, C), Vector3(6.0, 2.4, 0.7), stone, dark.lightened(0.15))
			for m in 5:
				g.box(Vector3(-2.4 + m * 1.2, 2.6, C), Vector3(0.45, 0.45, 0.75), stone)
			g.pop()
		# corner towers
		for k in 4:
			var a := k * PI * 0.5 + PI * 0.25
			var p := Vector3(cos(a), 0, sin(a)) * C * 1.4142
			g.prism(p, 1.0, 0.9, 3.6, 8, stone, dark)
			g.prism(p + Vector3(0, 3.6, 0), 1.15, 1.15, 0.3, 8, dark)
			g.prism(p + Vector3(0, 3.9, 0), 1.2, 0.0, 1.9, 8, roof, roof, 0.2)
		# keep
		g.box(Vector3(0, 2.6, 0), Vector3(3.8, 5.2, 3.8), stone, dark)
		for m in 4:
			g.push_at(Vector3.ZERO, m * PI * 0.5)
			for n in 4:
				g.box(Vector3(-1.4 + n * 0.93, 5.45, 1.75), Vector3(0.5, 0.5, 0.4), stone)
			g.box(Vector3(-0.8, 3.6, 1.91), Vector3(0.32, 0.65, 0.02), Color(0.15, 0.13, 0.18))
			g.box(Vector3(0.8, 3.6, 1.91), Vector3(0.32, 0.65, 0.02), Color(0.15, 0.13, 0.18))
			g.pop()
		g.prism(Vector3(0.8, 5.2, 0.8), 0.85, 0.75, 2.2, 8, stone, dark)
		g.prism(Vector3(0.8, 7.4, 0.8), 1.05, 0.0, 2.0, 8, roof, roof, 0.2)
		# banner
		g.box(Vector3(0.8, 9.9, 0.8), Vector3(0.08, 1.2, 0.08), Color(0.4, 0.3, 0.2))
		g.quad(Vector3(0.8, 10.4, 0.8), Vector3(0.8, 9.9, 0.8), Vector3(0.8, 9.95, 1.8), Vector3(0.8, 10.45, 1.8), Color(0.95, 0.8, 0.25))
		g.quad(Vector3(0.8, 10.45, 1.8), Vector3(0.8, 9.95, 1.8), Vector3(0.8, 9.9, 0.8), Vector3(0.8, 10.4, 0.8), Color(0.85, 0.7, 0.2))
		return g.mesh())


static func tower_plot_mesh() -> ArrayMesh:
	return _cached("tower_plot", func():
		var g := Geo.new()
		g.prism(Vector3.ZERO, 1.3, 1.2, 0.35, 8, Color(0.6, 0.57, 0.52), Color(0.68, 0.65, 0.58), PI / 8)
		g.box(Vector3(0.5, 0.5, 0.3), Vector3(0.5, 0.3, 0.5), Color(0.55, 0.38, 0.24))
		g.box(Vector3(-0.4, 0.45, -0.4), Vector3(0.7, 0.2, 0.25), Color(0.5, 0.35, 0.22))
		return g.mesh())


## One archer tower (castle upgrade); placed around the courtyard.
static func archer_tower_mesh() -> ArrayMesh:
	return _cached("archer_tower", func():
		var g := Geo.new()
		var wood := Color(0.55, 0.38, 0.24)
		for k in 4:
			var a := k * PI * 0.5 + PI * 0.25
			g.box(Vector3(cos(a) * 0.55, 1.2, sin(a) * 0.55), Vector3(0.18, 2.4, 0.18), wood)
		g.box(Vector3(0, 2.5, 0), Vector3(1.6, 0.2, 1.6), wood.lightened(0.1))
		for k in 4:
			g.push_at(Vector3.ZERO, k * PI * 0.5)
			g.box(Vector3(0, 2.8, 0.75), Vector3(1.6, 0.4, 0.1), wood)
			g.pop()
		g.prism(Vector3(0, 3.3, 0), 1.2, 0.0, 1.1, 4, Color(0.75, 0.22, 0.2), Color(0, 0, 0, 0), PI * 0.25)
		return g.mesh())


static func citadel_mesh() -> ArrayMesh:
	return _cached("citadel", func():
		var g := Geo.new()
		var obs := Color(0.17, 0.14, 0.17)
		var obs2 := Color(0.25, 0.2, 0.24)
		var red := Color(0.7, 0.12, 0.1)
		g.prism(Vector3.ZERO, 4.6, 3.8, 1.2, 8, obs2, obs, PI / 8)
		g.prism(Vector3(0, 1.2, 0), 3.4, 2.6, 4.5, 6, obs, obs2)
		g.prism(Vector3(0, 5.7, 0), 2.6, 0.0, 4.0, 6, obs2, obs2)
		for k in 6:
			var a := k * TAU / 6.0
			var p := Vector3(cos(a), 0, sin(a)) * 3.7
			g.prism(p, 0.8, 0.3, 4.0 + (k % 2) * 1.5, 5, obs, obs2, a)
			g.prism(p + Vector3(0, 4.0 + (k % 2) * 1.5, 0), 0.3, 0.0, 1.2, 5, red.darkened(0.3))
			# spikes
			g.push_at(p * 1.12 + Vector3(0, 0.3, 0), a)
			g.push(Transform3D(Basis(Vector3(0, 0, 1), -0.6), Vector3.ZERO))
			g.prism(Vector3.ZERO, 0.18, 0.0, 1.6, 4, Color(0.8, 0.76, 0.7))
			g.pop()
			g.pop()
		# gate
		g.box(Vector3(0, 1.2, 3.2), Vector3(1.6, 2.4, 0.4), Color(0.08, 0.05, 0.06))
		g.box(Vector3(0, 2.5, 3.25), Vector3(1.9, 0.25, 0.4), red)
		return g.mesh())


static func citadel_gem() -> ArrayMesh:
	return _cached("citadel_gem", func():
		var g := Geo.new()
		g.shard(Vector3(0, 0, 0), 0.8, 2.6, Color(1.0, 0.25, 0.15))
		g.push(Transform3D(Basis(Vector3(1, 0, 0), PI), Vector3(0, 0.1, 0)))
		g.shard(Vector3.ZERO, 0.8, 1.2, Color(0.8, 0.12, 0.1))
		g.pop()
		return g.mesh())


# ------------------------------------------------------------- pickups / fx

static func gem_mesh() -> ArrayMesh:
	return _cached("gem", func():
		var g := Geo.new()
		g.shard(Vector3(0, 0, 0), 0.16, 0.38, Color.WHITE)
		g.push(Transform3D(Basis(Vector3(1, 0, 0), PI), Vector3(0, 0.02, 0)))
		g.shard(Vector3.ZERO, 0.16, 0.2, Color(0.8, 0.8, 0.8))
		g.pop()
		return g.mesh())


static func coin_mesh() -> ArrayMesh:
	return _cached("coin", func():
		var g := Geo.new()
		g.push(Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5), Vector3.ZERO))
		g.prism(Vector3(0, -0.04, 0), 0.2, 0.2, 0.08, 8, Color(1.0, 0.78, 0.2), Color(1.0, 0.88, 0.4), 0.0, true)
		g.pop()
		return g.mesh())


static func potion_mesh() -> ArrayMesh:
	return _cached("potion", func():
		var g := Geo.new()
		g.blob(Vector3.ZERO, 0.22, 0.32, Color(0.95, 0.15, 0.2), 51, 6, 1)
		g.prism(Vector3(0, 0.28, 0), 0.07, 0.07, 0.14, 5, Color(0.8, 0.85, 0.9))
		g.prism(Vector3(0, 0.42, 0), 0.08, 0.08, 0.06, 5, Color(0.6, 0.4, 0.25))
		return g.mesh())


## Unit cube (white) for particles; tinted per instance.
static func cube_mesh() -> ArrayMesh:
	return _cached("cube", func():
		var g := Geo.new()
		g.box(Vector3.ZERO, Vector3.ONE, Color.WHITE, Color.WHITE, true, false)
		return g.mesh())


static func orb_mesh() -> ArrayMesh:
	return _cached("orb", func():
		var g := Geo.new()
		g.blob(Vector3(0, -0.5, 0), 0.5, 1.0, Color.WHITE, 61, 6, 2)
		g.push(Transform3D(Basis(Vector3(1, 0, 0), PI), Vector3(0, 0.0, 0)))
		g.prism(Vector3.ZERO, 0.45, 0.0, 0.5, 6, Color(0.85, 0.85, 0.85))
		g.pop()
		return g.mesh())


static func arrow_mesh() -> ArrayMesh:
	return _cached("arrow", func():
		var g := Geo.new()
		g.box(Vector3(0, 0, 0), Vector3(0.05, 0.05, 0.9), Color(0.55, 0.4, 0.25))
		g.push(Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5), Vector3(0, 0, 0.45)))
		g.prism(Vector3.ZERO, 0.08, 0.0, 0.2, 4, Color(0.85, 0.85, 0.9))
		g.pop()
		g.box(Vector3(0, 0.05, -0.38), Vector3(0.02, 0.1, 0.18), Color(0.95, 0.95, 0.95))
		return g.mesh())


static func axe_mesh() -> ArrayMesh:
	return _cached("axe", func():
		var g := Geo.new()
		g.box(Vector3.ZERO, Vector3(0.08, 0.08, 0.9), Color(0.5, 0.35, 0.22))
		g.box(Vector3(0, 0, 0.32), Vector3(0.5, 0.05, 0.3), Color(0.85, 0.88, 0.95))
		g.box(Vector3(0, 0, -0.32), Vector3(0.5, 0.05, 0.3), Color(0.85, 0.88, 0.95))
		return g.mesh())


## Flat glowing ring for novas / auras (radius 1, scaled at runtime).
static func ring_mesh() -> ArrayMesh:
	return _cached("ring", func():
		var g := Geo.new()
		g.ring(Vector3.ZERO, 0.88, 0.12, 24, Color.WHITE)
		return g.mesh())


## Glowing sword-slash arc (radius 1, 150 degrees, facing +z).
static func slash_mesh() -> ArrayMesh:
	return _cached("slash", func():
		var g := Geo.new()
		var n := 10
		var span := deg_to_rad(150.0)
		for i in n:
			var a0 := -span * 0.5 + span * i / n
			var a1 := -span * 0.5 + span * (i + 1) / n
			var d0 := Vector3(sin(a0), 0, cos(a0))
			var d1 := Vector3(sin(a1), 0, cos(a1))
			var w0 := 0.15 + 0.25 * sin(PI * float(i) / n)
			var w1 := 0.15 + 0.25 * sin(PI * float(i + 1) / n)
			g.quad(d1 * (1.0 - w1), d0 * (1.0 - w0), d0, d1, Color.WHITE)
		return g.mesh())


# ------------------------------------------------------------- Merlin

static func wizard_body() -> ArrayMesh:
	return _cached("wizard_body", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.5, 8, SHADOW)
		var robe := Color(0.47, 0.32, 0.19)
		var robe_d := Color(0.36, 0.24, 0.14)
		var hat := Color(0.42, 0.28, 0.16)
		# boots peeking out
		g.box(Vector3(-0.12, 0.06, 0.08), Vector3(0.14, 0.12, 0.22), Color(0.22, 0.16, 0.12))
		g.box(Vector3(0.12, 0.06, 0.08), Vector3(0.14, 0.12, 0.22), Color(0.22, 0.16, 0.12))
		# long robe (flared cone) + upper body
		g.prism(Vector3(0, 0.05, 0), 0.4, 0.24, 0.75, 8, robe, Color(0, 0, 0, 0), 0.2)
		g.prism(Vector3(0, 0.8, 0), 0.24, 0.2, 0.32, 8, robe.lightened(0.05), Color(0, 0, 0, 0), 0.2)
		g.box(Vector3(0, 0.62, 0), Vector3(0.5, 0.07, 0.42), Color(0.75, 0.6, 0.25))     # belt
		g.box(Vector3(0, 0.6, 0.22), Vector3(0.1, 0.1, 0.03), Color(0.95, 0.82, 0.35))   # buckle
		# sleeves
		g.box(Vector3(-0.3, 0.88, 0.05), Vector3(0.16, 0.16, 0.36), robe_d)
		g.box(Vector3(0.3, 0.88, 0.05), Vector3(0.16, 0.16, 0.36), robe_d)
		g.box(Vector3(-0.3, 0.86, 0.25), Vector3(0.1, 0.1, 0.06), Color(0.92, 0.75, 0.6))
		# head + long white beard
		g.box(Vector3(0, 1.22, 0.02), Vector3(0.26, 0.26, 0.26), Color(0.92, 0.75, 0.6))
		g.box(Vector3(-0.06, 1.25, 0.15), Vector3(0.05, 0.04, 0.02), Color(0.15, 0.2, 0.35))
		g.box(Vector3(0.06, 1.25, 0.15), Vector3(0.05, 0.04, 0.02), Color(0.15, 0.2, 0.35))
		g.push(Transform3D(Basis(Vector3(1, 0, 0), PI - 0.25), Vector3(0, 1.17, 0.16)))
		g.prism(Vector3.ZERO, 0.19, 0.0, 0.6, 6, Color(0.95, 0.95, 0.92))
		g.pop()
		g.box(Vector3(0, 1.15, 0.15), Vector3(0.24, 0.07, 0.04), Color(0.95, 0.95, 0.92))  # moustache
		# wide-brim pointed hat, tip bent back
		var hb := Vector3(0, 1.36, 0.02)
		g.prism(hb, 0.4, 0.38, 0.05, 10, hat, hat.darkened(0.05))
		g.prism(hb + Vector3(0, 0.05, 0), 0.24, 0.13, 0.3, 8, hat.lightened(0.04))
		g.prism(hb + Vector3(0, 0.05, 0), 0.25, 0.235, 0.07, 8, Color(0.28, 0.18, 0.1))  # hat band
		g.push(Transform3D(Basis(Vector3(1, 0, 0), -0.45), hb + Vector3(0, 0.33, 0)))
		g.prism(Vector3.ZERO, 0.13, 0.0, 0.32, 8, hat)
		g.pop()
		return g.mesh())


static func wizard_staff() -> ArrayMesh:
	return _cached("wizard_staff", func():
		var g := Geo.new()
		g.prism(Vector3(0, -0.75, 0), 0.04, 0.035, 1.55, 5, Color(0.42, 0.28, 0.16))
		g.prism(Vector3(0, 0.75, 0), 0.07, 0.03, 0.12, 5, Color(0.3, 0.2, 0.12))
		return g.mesh())


static func staff_gem() -> ArrayMesh:
	return _cached("staff_gem", func():
		var g := Geo.new()
		g.shard(Vector3(0, 0, 0), 0.09, 0.26, Color(0.55, 0.8, 1.0))
		g.push(Transform3D(Basis(Vector3(1, 0, 0), PI), Vector3(0, 0.02, 0)))
		g.shard(Vector3.ZERO, 0.09, 0.12, Color(0.4, 0.6, 1.0))
		g.pop()
		return g.mesh())


# ------------------------------------------------------------- Camelot's army

static func _soldier_base(g: Geo, tabard: Color, steel: Color) -> void:
	g.box(Vector3(-0.11, 0.22, 0), Vector3(0.14, 0.44, 0.18), Color(0.28, 0.24, 0.22))
	g.box(Vector3(0.11, 0.22, 0), Vector3(0.14, 0.44, 0.18), Color(0.28, 0.24, 0.22))
	g.prism(Vector3(0, 0.4, 0), 0.28, 0.24, 0.5, 6, tabard, Color(0, 0, 0, 0), 0.52)
	g.box(Vector3(0, 0.8, 0), Vector3(0.42, 0.26, 0.28), steel)
	g.prism(Vector3(0, 0.95, 0), 0.17, 0.15, 0.3, 6, steel)


static func swordsman_mesh() -> ArrayMesh:
	return _cached("swordsman", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.5, 8, SHADOW)
		g.push_at(Vector3.ZERO, 0.0, Vector3(1.15, 1.15, 1.15))
		_soldier_base(g, Color(0.2, 0.36, 0.8), Color(0.7, 0.72, 0.78))
		g.box(Vector3(0, 1.08, 0.12), Vector3(0.18, 0.04, 0.05), Color(0.1, 0.1, 0.12))
		g.prism(Vector3(0, 1.25, -0.02), 0.04, 0.02, 0.22, 4, Color(0.95, 0.8, 0.3))
		g.box(Vector3(0.3, 0.7, 0.35), Vector3(0.06, 0.04, 0.75), Color(0.88, 0.9, 0.95))
		g.box(Vector3(0.3, 0.7, 0.0), Vector3(0.22, 0.05, 0.05), Color(0.95, 0.8, 0.3))
		g.box(Vector3(-0.3, 0.68, 0.06), Vector3(0.07, 0.48, 0.38), Color(0.2, 0.36, 0.8), Color(0.95, 0.8, 0.3))
		g.pop()
		return g.mesh())


static func archer_mesh() -> ArrayMesh:
	return _cached("archer_ally", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.42, 8, SHADOW)
		_soldier_base(g, Color(0.25, 0.5, 0.25), Color(0.5, 0.38, 0.25))
		g.prism(Vector3(0, 1.0, 0), 0.2, 0.0, 0.3, 6, Color(0.25, 0.5, 0.25))  # hood
		g.box(Vector3(-0.25, 0.8, 0.2), Vector3(0.04, 0.8, 0.05), Color(0.55, 0.38, 0.22))
		g.box(Vector3(-0.25, 1.22, 0.14), Vector3(0.04, 0.1, 0.12), Color(0.55, 0.38, 0.22))
		g.box(Vector3(-0.25, 0.38, 0.14), Vector3(0.04, 0.1, 0.12), Color(0.55, 0.38, 0.22))
		g.box(Vector3(0.12, 0.85, -0.2), Vector3(0.14, 0.4, 0.12), Color(0.45, 0.3, 0.2))  # quiver
		return g.mesh())


static func paladin_mesh() -> ArrayMesh:
	return _cached("paladin", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.9, 9, SHADOW)
		g.push_at(Vector3.ZERO, 0.0, Vector3(1.9, 1.9, 1.9))
		_soldier_base(g, Color(0.92, 0.9, 0.85), Color(0.85, 0.85, 0.9))
		g.box(Vector3(0, 0.6, 0.15), Vector3(0.1, 0.3, 0.02), Color(0.95, 0.75, 0.2))
		g.box(Vector3(0, 0.66, 0.15), Vector3(0.24, 0.07, 0.02), Color(0.95, 0.75, 0.2))
		g.box(Vector3(0, 1.08, 0.12), Vector3(0.18, 0.04, 0.05), Color(0.1, 0.1, 0.12))
		g.box(Vector3(0.32, 0.8, 0.3), Vector3(0.05, 0.05, 0.75), Color(0.45, 0.32, 0.2))
		g.box(Vector3(0.32, 0.8, 0.68), Vector3(0.22, 0.2, 0.2), Color(0.8, 0.8, 0.85))  # warhammer
		g.pop()
		return g.mesh())


static func champion_mesh() -> ArrayMesh:
	return _cached("champion", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.7, 8, SHADOW)
		g.push_at(Vector3.ZERO, 0.0, Vector3(1.5, 1.5, 1.5))
		var gold := Color(0.95, 0.78, 0.3)
		_soldier_base(g, Color(0.2, 0.36, 0.85), gold)
		g.quad(Vector3(-0.2, 0.92, -0.15), Vector3(0.2, 0.92, -0.15), Vector3(0.26, 0.2, -0.32), Vector3(-0.26, 0.2, -0.32), Color(0.2, 0.36, 0.85))
		g.quad(Vector3(-0.26, 0.2, -0.31), Vector3(0.26, 0.2, -0.31), Vector3(0.2, 0.92, -0.14), Vector3(-0.2, 0.92, -0.14), Color(0.15, 0.25, 0.6))
		g.prism(Vector3(0, 1.25, 0), 0.06, 0.0, 0.25, 4, Color(0.9, 0.2, 0.2))
		g.box(Vector3(0.3, 0.8, 0.45), Vector3(0.08, 0.04, 1.0), Color(0.95, 0.95, 1.0))
		g.pop()
		return g.mesh())


static func worker_mesh() -> ArrayMesh:
	return _cached("worker", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.38, 7, SHADOW)
		g.box(Vector3(-0.09, 0.18, 0), Vector3(0.12, 0.36, 0.15), Color(0.35, 0.3, 0.25))
		g.box(Vector3(0.09, 0.18, 0), Vector3(0.12, 0.36, 0.15), Color(0.35, 0.3, 0.25))
		g.prism(Vector3(0, 0.34, 0), 0.22, 0.2, 0.4, 6, Color(0.62, 0.5, 0.32))
		g.box(Vector3(0, 0.88, 0.02), Vector3(0.22, 0.22, 0.22), Color(0.92, 0.75, 0.6))
		g.prism(Vector3(0, 0.98, 0.02), 0.2, 0.1, 0.1, 6, Color(0.75, 0.6, 0.3))   # straw hat
		g.box(Vector3(0, 0.6, -0.2), Vector3(0.3, 0.32, 0.18), Color(0.7, 0.62, 0.45))  # sack
		g.box(Vector3(0.24, 0.55, 0.2), Vector3(0.04, 0.04, 0.6), Color(0.45, 0.32, 0.2))  # pickaxe
		g.box(Vector3(0.24, 0.55, 0.48), Vector3(0.04, 0.35, 0.06), Color(0.6, 0.6, 0.65))
		return g.mesh())


static func spellbook_mesh() -> ArrayMesh:
	return _cached("spellbook", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.75, 8, SHADOW)
		g.prism(Vector3.ZERO, 0.55, 0.5, 0.18, 6, Color(0.55, 0.53, 0.5), Color(0.62, 0.6, 0.56))
		g.prism(Vector3(0, 0.18, 0), 0.18, 0.15, 0.6, 6, Color(0.6, 0.58, 0.54))
		g.box(Vector3(0, 0.82, 0), Vector3(0.5, 0.06, 0.4), Color(0.6, 0.58, 0.54))
		# open book, tilted toward the viewer
		g.push(Transform3D(Basis(Vector3(1, 0, 0), -0.35), Vector3(0, 0.92, 0)))
		g.box(Vector3(-0.15, 0, 0), Vector3(0.28, 0.04, 0.36), Color(0.45, 0.12, 0.15))
		g.box(Vector3(0.15, 0, 0), Vector3(0.28, 0.04, 0.36), Color(0.45, 0.12, 0.15))
		g.box(Vector3(-0.14, 0.03, 0), Vector3(0.25, 0.03, 0.32), Color(0.95, 0.92, 0.82))
		g.box(Vector3(0.14, 0.03, 0), Vector3(0.25, 0.03, 0.32), Color(0.95, 0.92, 0.82))
		g.pop()
		return g.mesh())


static func rune_mesh() -> ArrayMesh:
	return _cached("rune", func():
		var g := Geo.new()
		g.box(Vector3.ZERO, Vector3(0.36, 0.06, 0.36), Color.WHITE)
		g.box(Vector3.ZERO, Vector3(0.12, 0.08, 0.52), Color(0.8, 0.8, 0.8))
		g.box(Vector3.ZERO, Vector3(0.52, 0.08, 0.12), Color(0.8, 0.8, 0.8))
		return g.mesh())


# ------------------------------------------------------------- new Dread units

static func _wolf(g: Geo, fur: Color) -> void:
	for lx in [-0.14, 0.14]:
		for lz in [-0.35, 0.3]:
			g.box(Vector3(lx, 0.2, lz), Vector3(0.1, 0.4, 0.1), fur.darkened(0.2))
	g.box(Vector3(0, 0.5, 0), Vector3(0.38, 0.3, 0.9), fur, fur.lightened(0.1))
	g.box(Vector3(0, 0.62, 0.5), Vector3(0.3, 0.28, 0.3), fur.lightened(0.05))
	g.box(Vector3(0, 0.56, 0.72), Vector3(0.16, 0.14, 0.2), fur.darkened(0.1))
	g.box(Vector3(-0.08, 0.66, 0.66), Vector3(0.05, 0.04, 0.02), Color(1, 0.8, 0.1))
	g.box(Vector3(0.08, 0.66, 0.66), Vector3(0.05, 0.04, 0.02), Color(1, 0.8, 0.1))
	g.prism(Vector3(-0.1, 0.76, 0.48), 0.05, 0.0, 0.14, 4, fur.darkened(0.2))
	g.prism(Vector3(0.1, 0.76, 0.48), 0.05, 0.0, 0.14, 4, fur.darkened(0.2))
	g.push(Transform3D(Basis(Vector3(1, 0, 0), -2.2), Vector3(0, 0.58, -0.45)))
	g.prism(Vector3.ZERO, 0.08, 0.02, 0.4, 4, fur)
	g.pop()


static func wolf_rider_mesh() -> ArrayMesh:
	return _cached("wolf_rider", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.55, 8, SHADOW)
		_wolf(g, Color(0.38, 0.36, 0.36))
		# goblin rider
		var skin := Color(0.45, 0.65, 0.25)
		g.box(Vector3(0, 0.82, -0.05), Vector3(0.26, 0.3, 0.22), Color(0.5, 0.36, 0.22))
		g.box(Vector3(0, 1.08, 0.0), Vector3(0.26, 0.22, 0.22), skin)
		g.tri(Vector3(-0.13, 1.12, 0), Vector3(-0.3, 1.2, -0.04), Vector3(-0.13, 1.04, 0), skin.darkened(0.1))
		g.tri(Vector3(0.13, 1.12, 0), Vector3(0.13, 1.04, 0), Vector3(0.3, 1.2, -0.04), skin.darkened(0.1))
		g.box(Vector3(0.18, 0.95, 0.35), Vector3(0.04, 0.04, 0.9), Color(0.45, 0.3, 0.2))
		g.push(Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5), Vector3(0.18, 0.95, 0.8)))
		g.prism(Vector3.ZERO, 0.06, 0.0, 0.2, 4, Color(0.75, 0.75, 0.78))
		g.pop()
		return g.mesh())


static func shaman_mesh() -> ArrayMesh:
	return _cached("shaman", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.5, 8, SHADOW)
		var skin := Color(0.38, 0.52, 0.3)
		g.prism(Vector3(0, 0.05, 0), 0.36, 0.26, 0.75, 6, Color(0.42, 0.3, 0.22))
		g.box(Vector3(0, 0.9, 0), Vector3(0.5, 0.32, 0.36), Color(0.48, 0.38, 0.28))
		g.box(Vector3(0, 1.2, 0.04), Vector3(0.3, 0.28, 0.3), skin)
		g.box(Vector3(0, 1.22, 0.2), Vector3(0.22, 0.05, 0.02), Color(0.2, 0.9, 0.3))
		# feathered headdress
		for k in 5:
			var a := -0.6 + k * 0.3
			g.push(Transform3D(Basis(Vector3(0, 0, 1), a), Vector3(sin(a) * 0.1, 1.32, -0.05)))
			g.box(Vector3(0, 0.15, 0), Vector3(0.05, 0.3, 0.02), [Color(0.9, 0.2, 0.15), Color(0.95, 0.85, 0.3), Color(0.2, 0.7, 0.3)][k % 3])
			g.pop()
		# skull staff
		g.box(Vector3(0.36, 0.85, 0.15), Vector3(0.05, 1.5, 0.05), Color(0.4, 0.28, 0.18))
		g.box(Vector3(0.36, 1.65, 0.15), Vector3(0.16, 0.16, 0.16), Color(0.92, 0.9, 0.8))
		g.shard(Vector3(0.36, 1.74, 0.15), 0.07, 0.2, Color(0.3, 1.0, 0.4))
		return g.mesh())


static func necromancer_mesh() -> ArrayMesh:
	return _cached("necromancer", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.45, 8, SHADOW)
		var robe := Color(0.25, 0.15, 0.3)
		g.prism(Vector3(0, 0.02, 0), 0.38, 0.2, 1.0, 7, robe, Color(0, 0, 0, 0), 0.3)
		g.box(Vector3(0, 1.12, 0.03), Vector3(0.24, 0.24, 0.24), Color(0.9, 0.88, 0.8))
		g.box(Vector3(-0.06, 1.14, 0.15), Vector3(0.06, 0.06, 0.02), Color(0.7, 0.2, 1.0))
		g.box(Vector3(0.06, 1.14, 0.15), Vector3(0.06, 0.06, 0.02), Color(0.7, 0.2, 1.0))
		g.prism(Vector3(0, 1.0, -0.02), 0.26, 0.0, 0.62, 6, robe.lightened(0.06))  # hood
		g.box(Vector3(-0.3, 0.75, 0.05), Vector3(0.14, 0.14, 0.3), robe.darkened(0.1))
		g.box(Vector3(0.3, 0.75, 0.05), Vector3(0.14, 0.14, 0.3), robe.darkened(0.1))
		g.box(Vector3(0.36, 0.8, 0.2), Vector3(0.05, 1.5, 0.05), Color(0.2, 0.18, 0.2))
		g.shard(Vector3(0.36, 1.55, 0.2), 0.1, 0.32, Color(0.7, 0.25, 1.0))
		return g.mesh())


# ------------------------------------------------------------- new Camelot units

static func _horse(g: Geo, coat: Color) -> void:
	for lx in [-0.16, 0.16]:
		for lz in [-0.4, 0.38]:
			g.box(Vector3(lx, 0.27, lz), Vector3(0.11, 0.54, 0.11), coat.darkened(0.15))
	g.box(Vector3(0, 0.68, 0), Vector3(0.42, 0.36, 1.05), coat, coat.lightened(0.08))
	g.push(Transform3D(Basis(Vector3(1, 0, 0), -0.6), Vector3(0, 0.85, 0.5)))
	g.box(Vector3(0, 0.15, 0), Vector3(0.22, 0.45, 0.26), coat)
	g.pop()
	g.box(Vector3(0, 1.05, 0.72), Vector3(0.2, 0.2, 0.36), coat.lightened(0.05))
	g.box(Vector3(0, 1.1, 0.52), Vector3(0.06, 0.24, 0.3), Color(0.2, 0.15, 0.12))  # mane
	g.box(Vector3(0, 0.6, -0.6), Vector3(0.08, 0.4, 0.1), Color(0.2, 0.15, 0.12))    # tail
	g.box(Vector3(0, 0.88, 0), Vector3(0.46, 0.08, 0.5), Color(0.2, 0.36, 0.8))      # caparison


static func cavalry_mesh() -> ArrayMesh:
	return _cached("cavalry", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.6, 8, SHADOW)
		_horse(g, Color(0.85, 0.82, 0.78))
		var steel := Color(0.72, 0.74, 0.8)
		g.box(Vector3(0, 1.12, -0.05), Vector3(0.36, 0.38, 0.26), steel)
		g.prism(Vector3(0, 1.3, -0.05), 0.15, 0.13, 0.3, 6, steel)
		g.box(Vector3(0, 1.43, 0.06), Vector3(0.16, 0.04, 0.05), Color(0.1, 0.1, 0.12))
		g.box(Vector3(0.24, 1.12, 0.55), Vector3(0.06, 0.06, 1.5), Color(0.9, 0.85, 0.7))
		g.box(Vector3(-0.24, 1.05, 0.05), Vector3(0.06, 0.4, 0.3), Color(0.2, 0.36, 0.8), Color(0.95, 0.8, 0.3))
		return g.mesh())


static func _robed(g: Geo, robe: Color, hat: Color, gem: Color, beard: bool) -> void:
	g.prism(Vector3(0, 0.05, 0), 0.36, 0.22, 0.75, 8, robe, Color(0, 0, 0, 0), 0.2)
	g.prism(Vector3(0, 0.8, 0), 0.22, 0.18, 0.3, 8, robe.lightened(0.05), Color(0, 0, 0, 0), 0.2)
	g.box(Vector3(0, 0.62, 0), Vector3(0.46, 0.06, 0.4), Color(0.85, 0.7, 0.3))
	g.box(Vector3(0, 1.2, 0.02), Vector3(0.24, 0.24, 0.24), Color(0.92, 0.75, 0.6))
	if beard:
		g.push(Transform3D(Basis(Vector3(1, 0, 0), PI - 0.25), Vector3(0, 1.15, 0.15)))
		g.prism(Vector3.ZERO, 0.15, 0.0, 0.4, 6, Color(0.6, 0.45, 0.3))
		g.pop()
	g.prism(Vector3(0, 1.32, 0.02), 0.34, 0.32, 0.05, 8, hat)
	g.prism(Vector3(0, 1.37, 0.02), 0.2, 0.0, 0.55, 8, hat.lightened(0.05))
	g.box(Vector3(0.32, 0.78, 0.18), Vector3(0.05, 1.45, 0.05), Color(0.42, 0.28, 0.16))
	g.shard(Vector3(0.32, 1.48, 0.18), 0.08, 0.24, gem)


static func battlemage_mesh() -> ArrayMesh:
	return _cached("battlemage", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.42, 8, SHADOW)
		_robed(g, Color(0.2, 0.32, 0.75), Color(0.18, 0.26, 0.6), Color(1.0, 0.55, 0.15), true)
		return g.mesh())


static func cleric_mesh() -> ArrayMesh:
	return _cached("cleric", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.42, 8, SHADOW)
		var white := Color(0.92, 0.9, 0.85)
		g.prism(Vector3(0, 0.05, 0), 0.36, 0.22, 0.75, 8, white, Color(0, 0, 0, 0), 0.2)
		g.prism(Vector3(0, 0.8, 0), 0.22, 0.18, 0.3, 8, white.lightened(0.03), Color(0, 0, 0, 0), 0.2)
		g.box(Vector3(0, 0.5, 0.2), Vector3(0.08, 0.5, 0.02), Color(0.95, 0.75, 0.25))
		g.box(Vector3(0, 0.62, 0.2), Vector3(0.26, 0.08, 0.02), Color(0.95, 0.75, 0.25))
		g.box(Vector3(0, 1.2, 0.02), Vector3(0.24, 0.24, 0.24), Color(0.92, 0.75, 0.6))
		g.prism(Vector3(0, 1.12, -0.02), 0.22, 0.12, 0.38, 6, white.darkened(0.08))     # hood
		g.box(Vector3(0.32, 0.8, 0.18), Vector3(0.05, 1.3, 0.05), Color(0.85, 0.7, 0.3))
		g.prism(Vector3(0.32, 1.42, 0.18), 0.12, 0.12, 0.05, 8, Color(1.0, 0.85, 0.35))   # sun disc
		return g.mesh())


# ------------------------------------------------------------- landmarks & loot

static func ward_mesh() -> ArrayMesh:
	return _cached("ward", func():
		var g := Geo.new()
		var obs := Color(0.17, 0.13, 0.17)
		g.prism(Vector3.ZERO, 2.2, 1.9, 0.5, 6, Color(0.24, 0.2, 0.22), obs, 0.3)
		g.prism(Vector3(0, 0.5, 0), 0.9, 0.35, 6.0, 4, obs, obs, PI * 0.25)
		for k in 4:
			var a := PI * 0.25 + k * PI * 0.5
			var d := Vector3(cos(a), 0, sin(a))
			g.prism(d * 1.6 + Vector3(0, 0.5, 0), 0.3, 0.0, 1.6, 4, obs.lightened(0.05))
			g.box(d * 0.62 + Vector3(0, 2.0 + k * 0.6, 0), Vector3(0.16, 0.5, 0.16), Color(1.0, 0.25, 0.1))
		return g.mesh())


static func shrine_base_mesh() -> ArrayMesh:
	return _cached("shrine_base", func():
		var g := Geo.new()
		var st := Color(0.66, 0.64, 0.6)
		g.prism(Vector3.ZERO, 2.3, 2.2, 0.22, 10, st.darkened(0.15), st)
		g.ring(Vector3(0, 0.23, 0), 1.6, 0.18, 20, Color(0.45, 0.43, 0.42))
		for k in 5:
			var a := k * TAU / 5.0
			g.prism(Vector3(cos(a), 0, sin(a)) * 1.9 + Vector3(0, 0.2, 0), 0.22, 0.17, 1.3, 4, st, st.lightened(0.08), a)
		g.prism(Vector3(0, 0.2, 0), 0.35, 0.28, 1.1, 6, st.lightened(0.05))
		return g.mesh())


static func shrine_crystal_mesh() -> ArrayMesh:
	return _cached("shrine_crystal", func():
		var g := Geo.new()
		g.shard(Vector3(0, 0, 0), 0.32, 1.1, Color.WHITE)
		g.push(Transform3D(Basis(Vector3(1, 0, 0), PI), Vector3(0, 0.05, 0)))
		g.shard(Vector3.ZERO, 0.32, 0.45, Color(0.85, 0.85, 0.85))
		g.pop()
		return g.mesh())


static func loot_mesh() -> ArrayMesh:
	return _cached("loot", func():
		var g := Geo.new()
		g.box(Vector3(0, 0.16, 0), Vector3(0.5, 0.32, 0.36), Color(0.5, 0.32, 0.18), Color(0.55, 0.36, 0.2))
		g.box(Vector3(0, 0.36, 0), Vector3(0.52, 0.1, 0.38), Color(0.6, 0.4, 0.22))
		g.box(Vector3(0, 0.2, 0.19), Vector3(0.1, 0.12, 0.03), Color(0.95, 0.8, 0.3))
		g.box(Vector3(-0.2, 0.2, 0), Vector3(0.05, 0.34, 0.38), Color(0.75, 0.62, 0.3))
		g.box(Vector3(0.2, 0.2, 0), Vector3(0.05, 0.34, 0.38), Color(0.75, 0.62, 0.3))
		return g.mesh())


static func royal_guard_mesh() -> ArrayMesh:
	return _cached("royal_guard", func():
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.6, 8, SHADOW)
		g.push_at(Vector3.ZERO, 0.0, Vector3(1.3, 1.3, 1.3))
		var gold := Color(0.95, 0.78, 0.3)
		_soldier_base(g, Color(0.75, 0.12, 0.15), Color(0.82, 0.82, 0.88))
		g.box(Vector3(0, 0.62, 0.15), Vector3(0.12, 0.2, 0.02), gold)
		g.box(Vector3(0, 1.08, 0.12), Vector3(0.18, 0.04, 0.05), Color(0.1, 0.1, 0.12))
		g.prism(Vector3(0, 1.1, -0.02), 0.06, 0.03, 0.3, 4, Color(0.85, 0.15, 0.15))   # crest
		# halberd
		g.box(Vector3(0.3, 0.75, 0.25), Vector3(0.05, 0.05, 1.6), Color(0.45, 0.32, 0.2))
		g.box(Vector3(0.3, 0.75, 1.0), Vector3(0.04, 0.32, 0.22), Color(0.85, 0.87, 0.92))
		g.box(Vector3(-0.3, 0.68, 0.06), Vector3(0.07, 0.5, 0.4), Color(0.75, 0.12, 0.15), gold)
		g.pop()
		return g.mesh())


## Hooded, robed adept of the Circle of Avalon. 0 frost, 1 ember, 2 thorn, 3 light.
static func adept_mesh(i: int) -> ArrayMesh:
	return _cached("adept_%d" % i, func():
		var robes := [Color(0.3, 0.48, 0.78), Color(0.7, 0.28, 0.14), Color(0.28, 0.46, 0.22), Color(0.86, 0.84, 0.76)]
		var gems := [Color(0.6, 0.9, 1.0), Color(1.0, 0.55, 0.15), Color(0.5, 1.0, 0.35), Color(1.0, 0.95, 0.55)]
		var robe: Color = robes[i]
		var g := Geo.new()
		g.disc(Vector3(0, 0.03, 0), 0.42, 8, SHADOW)
		g.prism(Vector3(0, 0.03, 0), 0.34, 0.2, 0.82, 8, robe, Color(0, 0, 0, 0), 0.2)
		g.prism(Vector3(0, 0.85, 0), 0.2, 0.17, 0.22, 8, robe.lightened(0.05), Color(0, 0, 0, 0), 0.2)
		g.box(Vector3(0, 0.6, 0), Vector3(0.42, 0.05, 0.38), robe.darkened(0.35))           # rope belt
		g.box(Vector3(-0.27, 0.78, 0.06), Vector3(0.13, 0.13, 0.3), robe.darkened(0.12))     # sleeves
		g.box(Vector3(0.27, 0.78, 0.06), Vector3(0.13, 0.13, 0.3), robe.darkened(0.12))
		# Deep pointed hood with a shadowed face and glowing eyes.
		g.prism(Vector3(0, 0.98, -0.03), 0.22, 0.0, 0.62, 7, robe.darkened(0.08), Color(0, 0, 0, 0), 0.3)
		g.box(Vector3(0, 1.1, 0.13), Vector3(0.18, 0.16, 0.04), Color(0.05, 0.05, 0.07))
		g.box(Vector3(-0.045, 1.12, 0.155), Vector3(0.04, 0.025, 0.01), gems[i])
		g.box(Vector3(0.045, 1.12, 0.155), Vector3(0.04, 0.025, 0.01), gems[i])
		# Staff with a glowing focus.
		g.box(Vector3(0.3, 0.75, 0.18), Vector3(0.045, 1.4, 0.045), Color(0.4, 0.27, 0.16))
		g.shard(Vector3(0.3, 1.45, 0.18), 0.07, 0.2, gems[i])
		return g.mesh())


## A Dread garrison camp: a black banner, a ring of stakes and a fire pit.
static func dread_camp_mesh() -> ArrayMesh:
	return _cached("dread_camp", func():
		var g := Geo.new()
		var wood := Color(0.32, 0.22, 0.16)
		for k in 9:
			var a := k * TAU / 9.0 + 0.2
			if k % 3 == 1:
				continue
			var p := Vector3(cos(a), 0, sin(a)) * 4.6
			g.push(Transform3D(Basis(Vector3(cos(a + PI * 0.5), 0, sin(a + PI * 0.5)), 0.35), p))
			g.prism(Vector3.ZERO, 0.13, 0.0, 1.5, 4, wood)
			g.pop()
		g.box(Vector3(1.5, 1.6, -1.5), Vector3(0.12, 3.2, 0.12), Color(0.2, 0.18, 0.18))
		g.quad(Vector3(1.5, 3.1, -1.5), Vector3(1.5, 2.0, -1.5), Vector3(2.4, 2.1, -1.5), Vector3(2.4, 3.0, -1.5), Color(0.55, 0.08, 0.08))
		g.quad(Vector3(2.4, 3.0, -1.5), Vector3(2.4, 2.1, -1.5), Vector3(1.5, 2.0, -1.5), Vector3(1.5, 3.1, -1.5), Color(0.4, 0.05, 0.05))
		g.prism(Vector3(-1.2, 0, 1.2), 0.6, 0.5, 0.2, 7, Color(0.3, 0.28, 0.27))
		g.shard(Vector3(-1.2, 0.15, 1.2), 0.3, 0.6, Color(1.0, 0.5, 0.15))
		return g.mesh())
