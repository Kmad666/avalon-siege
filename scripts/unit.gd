class_name Unit
extends RefCounted
## One enemy or allied soldier. Plain data: the Horde moves and draws them all.

var kind := "goblin"
var team := 1            # 1 = enemy, 0 = ally
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var facing := 0.0
var hp := 10.0
var max_hp := 10.0
var r := 0.4
var speed := 3.0
var dmg := 5.0
var reach := 0.5         # melee reach beyond touching
var ranged := 0.0        # > 0: shoots from this range
var atk_cd := 1.0
var atk_t := 0.0
var xp := 1
var gold_chance := 0.3
var elite := false
var boss := false
var mode := "march"      # march | camp | guard
var home := Vector3.ZERO
var camp_id := -1
var flash := 0.0
var anim := 0.0
var lunge := 0.0
var dying := 0.0         # > 0 while playing the death sink
var alive := true
var tile := 0
var aggro := false
var stuck_t := 0.0
var respawn_t := 0.0
var slot := 0            # ally formation slot
var scale := 1.0
var think := 0.0          # seconds until the next (expensive) decision
var t_kind := ""          # current target: hero | ally | castle | ""
var t_ally: Unit = null
var path_dir := Vector3.ZERO
var los := false
var sep := Vector3.ZERO
