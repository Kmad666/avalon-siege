class_name Items
extends Node3D
## Diablo-style loot: items with a slot, a rarity and random affixes, lying on
## the ground under a pillar of light until Merlin picks them up.

class Item:
	var slot := "staff"
	var rarity := 0          # 0 common, 1 magic, 2 rare, 3 legendary
	var name := ""
	var ilvl := 1
	var stats := {}          # stat key -> value
	var value := 5           # salvage gold

class Drop:
	var item: Item
	var pos := Vector3.ZERO
	var t := 0.0

const SLOTS := ["staff", "hat", "robe", "amulet", "ring"]
const SLOT_NAMES := {"staff": "Staff", "hat": "Hat", "robe": "Robe", "amulet": "Amulet", "ring": "Ring"}
const RARITY_NAMES := ["Common", "Magic", "Rare", "Legendary"]
const RARITY_COLORS := [Color(0.9, 0.9, 0.88), Color(0.45, 0.6, 1.0), Color(1.0, 0.86, 0.3), Color(1.0, 0.55, 0.15)]
const BAG_SIZE := 12

## Which stats each slot can roll (first is its signature stat).
const POOL := {
	"staff": ["dmg", "cd", "dmg", "xp", "speed"],
	"hat": ["cd", "xp", "hp", "pickup", "regen"],
	"robe": ["hp", "armor", "regen", "speed"],
	"amulet": ["dmg", "regen", "gold", "hp", "cd"],
	"ring": ["dmg", "cd", "speed", "pickup", "gold", "hp", "armor"],
}
const STAT_INFO := {
	"dmg": {"label": "+%d%% spell damage", "base": 4.0, "per": 1.6, "prefix": "Searing"},
	"cd": {"label": "-%d%% cooldowns", "base": 2.0, "per": 0.6, "prefix": "Quickened"},
	"hp": {"label": "+%d max HP", "base": 8.0, "per": 5.0, "prefix": "Sturdy"},
	"armor": {"label": "+%d armour", "base": 1.0, "per": 0.4, "prefix": "Warded"},
	"regen": {"label": "+%.1f HP per second", "base": 0.3, "per": 0.15, "prefix": "Mending"},
	"speed": {"label": "+%d%% move speed", "base": 2.0, "per": 0.5, "prefix": "Fleet"},
	"gold": {"label": "+%d%% gold from coins", "base": 5.0, "per": 2.0, "prefix": "Gilded"},
	"xp": {"label": "+%d%% experience", "base": 5.0, "per": 2.0, "prefix": "Wise"},
	"pickup": {"label": "+%d%% pickup range", "base": 10.0, "per": 3.0, "prefix": "Grasping"},
	"bounce": {"label": "+%d Chain Lightning bounces", "base": 1.0, "per": 0.0, "prefix": "Storm"},
}
const BASES := {
	"staff": ["Oak Staff", "Runed Staff", "Elder Staff", "Archmage Staff"],
	"hat": ["Pointed Hat", "Wizard Hat", "Sage Cowl", "Archmage Hat"],
	"robe": ["Linen Robe", "Woven Robe", "Silk Robe", "Archmage Robe"],
	"amulet": ["Charm", "Amulet", "Talisman", "Reliquary"],
	"ring": ["Band", "Ring", "Signet", "Seal"],
}
const SUFFIXES := ["of the Owl", "of the Bear", "of the Stag", "of Storms", "of the Lake", "of Logres", "of the Grail", "of Twilight"]
const LEGENDS := {
	"staff": "Stormcaller", "hat": "Crown of Avalon", "robe": "Mantle of the Lady",
	"amulet": "Heart of Logres", "ring": "Ring of Nimue",
}

var game: Game
var drops: Array[Drop] = []
var b_chest: Batch
var b_beam: Batch
var b_glow: Batch


func setup(g: Game) -> void:
	game = g
	b_chest = Batch.new(self, Models.loot_mesh(), 40, Geo.mat())
	b_beam = Batch.new(self, Models.cube_mesh(), 40, Geo.mat_add())
	b_glow = Batch.new(self, Models.ring_mesh(), 40, Geo.mat_add())


# ------------------------------------------------------------- generation

static func roll_rarity(luck: float) -> int:
	var r := randf()
	if r < 0.012 + 0.02 * luck:
		return 3
	if r < 0.09 + 0.12 * luck:
		return 2
	if r < 0.4 + 0.2 * luck:
		return 1
	return 0


static func make(ilvl: int, rarity: int, slot := "") -> Item:
	var it := Item.new()
	it.slot = slot if slot != "" else SLOTS[randi() % SLOTS.size()]
	it.rarity = rarity
	it.ilvl = clampi(ilvl, 1, 15)
	var pool: Array = POOL[it.slot]
	var n: int = [1, 2, 3 + randi() % 2, 4][rarity]
	var keys: Array = []
	keys.append(pool[0])
	var tries := 0
	while keys.size() < n and tries < 30:
		tries += 1
		var k: String = pool[randi() % pool.size()]
		if not keys.has(k):
			keys.append(k)
	var mag: float = [0.7, 0.9, 1.05, 1.3][rarity]
	for k in keys:
		var inf: Dictionary = STAT_INFO[k]
		var v: float = (inf.base + inf.per * it.ilvl) * mag * randf_range(0.8, 1.15)
		it.stats[k] = v if k == "regen" else roundf(v)
	if rarity == 3:
		if it.slot == "staff" or it.slot == "ring":
			it.stats["bounce"] = 1.0 + (1.0 if it.slot == "staff" else 0.0)
		it.name = LEGENDS[it.slot]
	else:
		var tier := clampi(it.ilvl / 4, 0, 3)
		var base: String = BASES[it.slot][tier]
		var top: String = keys[1] if keys.size() > 1 else keys[0]
		match rarity:
			0: it.name = base
			1: it.name = "%s %s" % [STAT_INFO[top].prefix, base]
			2: it.name = "%s %s" % [base, SUFFIXES[randi() % SUFFIXES.size()]]
	it.value = int((4 + it.ilvl * 3) * [1, 2, 4, 10][rarity])
	return it


static func stat_lines(it: Item) -> Array:
	var out := []
	for k in it.stats:
		var inf: Dictionary = STAT_INFO[k]
		var v: float = it.stats[k]
		out.append(inf.label % v if k == "regen" else inf.label % int(v))
	return out


static func score(it: Item) -> float:
	if it == null:
		return 0.0
	var w := {"dmg": 1.0, "cd": 1.6, "hp": 0.18, "armor": 1.6, "regen": 3.0, "speed": 1.0, "gold": 0.4, "xp": 0.4, "pickup": 0.2, "bounce": 8.0}
	var s := 0.0
	for k in it.stats:
		s += it.stats[k] * w.get(k, 0.5)
	return s


# ------------------------------------------------------------- world drops

func drop(it: Item, pos: Vector3) -> void:
	var d := Drop.new()
	d.item = it
	d.pos = game.maze.collide(pos + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)), 0.3)
	d.pos.y = 0
	drops.append(d)
	if it.rarity >= 2:
		game.sfx.play("levelup", -6.0 if it.rarity == 2 else 0.0, 0.2, 0.0)


func roll_drop(pos: Vector3, chance: float, luck: float, min_rarity := 0) -> void:
	if randf() >= chance:
		return
	var rg := game.maze.region[Maze.idx(Maze.tile_of(pos))]
	var ilvl := 1 + game.wave / 2 + int(rg * 6.0)
	var r := maxi(min_rarity, roll_rarity(luck))
	drop(make(ilvl, r), pos)


func update(dt: float) -> void:
	var hero := game.hero
	var i := drops.size() - 1
	while i >= 0:
		var d: Drop = drops[i]
		d.t += dt
		if hero.alive and Vector2(d.pos.x - hero.position.x, d.pos.z - hero.position.z).length() < 1.3:
			if hero.take_item(d.item):
				drops.remove_at(i)
		i -= 1


func render() -> void:
	for b in [b_chest, b_beam, b_glow]:
		b.begin()
	for d in drops:
		var c: Color = RARITY_COLORS[d.item.rarity]
		b_chest.add(Basis(Vector3.UP, 0.6), d.pos, Color.WHITE)
		var h := 2.5 + d.item.rarity * 1.5
		var pulse := 0.6 + 0.3 * sin(d.t * 4.0)
		b_beam.add(Basis.IDENTITY.scaled(Vector3(0.12, h, 0.12)), d.pos + Vector3(0, h * 0.5, 0), Color(c.r * pulse * 0.6, c.g * pulse * 0.6, c.b * pulse * 0.6))
		b_glow.add(Basis.IDENTITY.scaled(Vector3(0.8, 1, 0.8)), d.pos + Vector3(0, 0.05, 0), Color(c.r * pulse, c.g * pulse, c.b * pulse))
	for b in [b_chest, b_beam, b_glow]:
		b.finish()
