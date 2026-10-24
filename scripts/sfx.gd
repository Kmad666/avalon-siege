class_name Sfx
extends Node
## Tiny procedural sound kit: every effect is synthesised into a short WAV at
## startup, so the game ships with no audio files at all.

const RATE := 22050

var streams := {}
var players: Array[AudioStreamPlayer] = []
var last := {}
static var muted := false


func toggle() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)


## A seamless loop of moaning wind for the valley.
func _start_wind() -> void:
	var n := RATE * 6
	var fade := RATE / 2
	var buf := PackedFloat32Array()
	buf.resize(n + fade)
	var lp := 0.0
	var lp2 := 0.0
	for i in n + fade:
		var t := float(i) / RATE
		var gust := 0.55 + 0.3 * sin(TAU * t / 6.0) + 0.15 * sin(TAU * t / 2.0 + 1.0)
		lp = lerpf(lp, _rng.randf_range(-1.0, 1.0), 0.02 + 0.03 * gust)
		lp2 = lerpf(lp2, lp, 0.2)
		buf[i] = lp2 * 6.0 * gust
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := buf[i]
		if i < fade:
			var k := float(i) / fade
			v = v * k + buf[n + i] * (1.0 - k)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	var pl := AudioStreamPlayer.new()
	pl.stream = w
	pl.volume_db = -14.0
	add_child(pl)
	pl.play()


var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	AudioServer.set_bus_mute(0, muted)
	_start_wind()
	for k in 12:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		players.append(p)
	streams["swing"] = _make(0.14, func(t, i): return _noise() * _env(t, 0.14, 0.03) * 0.35 * (0.5 + 0.5 * sin(t * 90.0)))
	streams["hit"] = _make(0.09, func(t, i): return (_noise() * 0.5 + sin(TAU * 140.0 * t) * 0.6) * _env(t, 0.09, 0.003))
	streams["kill"] = _make(0.2, func(t, i): return (_noise() * 0.45 + sin(TAU * lerpf(260.0, 70.0, t / 0.2) * t) * 0.5) * _env(t, 0.2, 0.004))
	streams["coin"] = _make(0.16, func(t, i): return sin(TAU * (1320.0 if t < 0.05 else 1760.0) * t) * _env(t, 0.16, 0.002) * 0.45)
	streams["gem"] = _make(0.07, func(t, i): return sin(TAU * lerpf(1500.0, 2300.0, t / 0.07) * t) * _env(t, 0.07, 0.002) * 0.3)
	streams["chop"] = _make(0.08, func(t, i): return (sin(TAU * 320.0 * t) * 0.6 + _noise() * 0.4) * _env(t, 0.08, 0.001) * 0.7)
	streams["levelup"] = _make(0.5, func(t, i):
		var notes := [523.25, 659.25, 783.99, 1046.5]
		var n: int = mini(3, int(t / 0.09))
		return (sin(TAU * notes[n] * t) * 0.5 + sin(TAU * notes[n] * 2.0 * t) * 0.15) * _env(t, 0.5, 0.005) * 0.6)
	streams["explode"] = _make(0.55, func(t, i): return _lp_noise(0.08) * _env(t, 0.55, 0.004) * 1.1)
	streams["zap"] = _make(0.22, func(t, i): return (_noise() * (1.0 if sin(TAU * 60.0 * t) > 0.0 else 0.3)) * _env(t, 0.22, 0.002) * 0.4)
	streams["hurt"] = _make(0.18, func(t, i): return (sin(TAU * lerpf(200.0, 80.0, t / 0.18) * t) * 0.7 + _noise() * 0.2) * _env(t, 0.18, 0.003))
	streams["build"] = _make(0.7, func(t, i): return (sin(TAU * 784.0 * t) * 0.4 + sin(TAU * 1175.0 * t) * 0.3 + sin(TAU * 1568.0 * t) * 0.12) * _env(t, 0.7, 0.003))
	streams["arrow"] = _make(0.07, func(t, i): return _noise() * _env(t, 0.07, 0.001) * 0.18 * (1.0 - t / 0.07))
	streams["horn"] = _make(1.1, func(t, i):
		var f := 146.8 * (1.0 + 0.01 * sin(TAU * 5.0 * t))
		var saw := fmod(f * t, 1.0) * 2.0 - 1.0
		return (saw * 0.35 + sin(TAU * f * t) * 0.3) * _env(t, 1.1, 0.12) * 0.7)
	streams["deliver"] = _make(0.35, func(t, i): return (sin(TAU * (880.0 if t < 0.1 else 1318.5) * t) * 0.4) * _env(t, 0.35, 0.003))
	streams["fire"] = _make(0.25, func(t, i): return _lp_noise(0.25) * _env(t, 0.25, 0.04) * 0.5)


var _lp := 0.0


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


func _lp_noise(k: float) -> float:
	_lp = lerpf(_lp, _noise(), k)
	return _lp * 2.5


## Attack / exponential-ish decay envelope.
func _env(t: float, dur: float, attack: float) -> float:
	if t < attack:
		return t / attack
	var k := 1.0 - (t - attack) / maxf(0.001, dur - attack)
	return k * k


func _make(dur: float, f: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = clampf(f.call(t, i), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Play a sound, at most once per `gap` seconds.
func play(sname: String, vol := 0.0, gap := 0.05, pitch_var := 0.1) -> void:
	if muted or not streams.has(sname):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - last.get(sname, -10.0) < gap:
		return
	last[sname] = now
	var p := players[_next]
	_next = (_next + 1) % players.size()
	p.stream = streams[sname]
	p.volume_db = -8.0 + vol
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	p.play()
