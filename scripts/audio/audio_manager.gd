extends Node
## AudioManager (autoload)
##
## Sound architecture of the game:
##  * Bus layout built at runtime: Master > Music / Ambience / SFX / Voice / Jumpscare.
##    SFX and Voice go through a reverb (mansion corridors), Master owns a
##    low-pass ("muffle", used for panic and death) and a distortion insert
##    (reality glitches).
##  * Ambience: looping beds cross-faded per zone (void wind, low drone,
##    mansion room tone, forest, throne).
##  * Adaptive music: independent layers (dread / presence / chase / throne)
##    whose volumes follow Satella's presence, Envy Awareness and chases.
##    Music is never constant: the dread layer "breathes" with long silences.
##  * Ambient one-shots: creaks, distant steps, knocks and whispers spawned
##    as 3D sounds around the listener, rarer when the Witch sleeps.
##  * Panic: heartbeat + breathing driven by the player's panic value.

const AUDIO_ROOT := "res://assets/audio/"
const BUSES := ["Music", "Ambience", "SFX", "Voice", "Jumpscare"]

var _cache := {}
var _index := {}                 # "creak" -> ["sfx/creak_1", ...]
var _pool_2d: Array[AudioStreamPlayer] = []
var _ambience := {}              # name -> AudioStreamPlayer
var _ambience_target := {}       # name -> linear volume
var _music := {}                 # layer -> AudioStreamPlayer
var _music_target := {}          # layer -> linear volume
var _listener: Node3D = null
var _ambient_timer := 12.0
var _ambient_profile := "mansion"
var _panic := 0.0
var _heart_timer := 0.0
var _breath_timer := 0.0
var _breath_in := true
var _music_breath_timer := 30.0
var _dread_allowed := false
var presence := 0.0              ## 0..1 how close / visible Satella is (set by Satella AI)
var chase_active := false
var music_mode := "game"         ## game / lobby / throne / credits / silent
var _muffle_target := 20500.0
var _lowpass: AudioEffectLowPassFilter
var _distortion: AudioEffectDistortion
var _distortion_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_buses()
	_build_index()
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool_2d.append(p)
	apply_volumes()
	Settings.settings_changed.connect(apply_volumes)
	EventBus.chase_started.connect(func(_id): chase_active = true)
	EventBus.chase_ended.connect(func(_id, _e): chase_active = false)


# ------------------------------------------------------------------ buses
func _build_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.75
	rev.damping = 0.55
	rev.wet = 0.22
	rev.dry = 0.9
	rev.spread = 1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), rev)
	var rev2 := AudioEffectReverb.new()
	rev2.room_size = 0.85
	rev2.wet = 0.3
	rev2.dry = 0.85
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Voice"), rev2)
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 20500.0
	AudioServer.add_bus_effect(0, _lowpass)
	_distortion = AudioEffectDistortion.new()
	_distortion.mode = AudioEffectDistortion.MODE_LOFI
	_distortion.drive = 0.6
	AudioServer.add_bus_effect(0, _distortion)
	AudioServer.set_bus_effect_enabled(0, 1, false)
	var lim := AudioEffectHardLimiter.new()
	AudioServer.add_bus_effect(0, lim)


func apply_volumes() -> void:
	_set_bus("Master", Settings.vol_master)
	_set_bus("Music", Settings.vol_music)
	_set_bus("Ambience", Settings.vol_ambience)
	_set_bus("SFX", Settings.vol_sfx)
	_set_bus("Voice", Settings.vol_voice)
	_set_bus("Jumpscare", Settings.vol_jumpscare)


func _set_bus(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(idx, linear <= 0.001)


# ------------------------------------------------------------------ library
func _build_index() -> void:
	for sub: String in ["sfx", "music", "ambience", "voice"]:
		var dir := DirAccess.open(AUDIO_ROOT + sub)
		if dir == null:
			continue
		for f in dir.get_files():
			var file := f.trim_suffix(".import").trim_suffix(".remap")
			if not (file.ends_with(".wav") or file.ends_with(".ogg")):
				continue
			var key := sub + "/" + file.get_basename()
			var base := file.get_basename()
			# group "creak_1" "creak_2" under "creak"
			var group := base
			var parts := base.rsplit("_", true, 1)
			if parts.size() == 2 and parts[1].is_valid_int():
				group = parts[0]
			for g in [group, base]:
				if not _index.has(g):
					_index[g] = []
				if not _index[g].has(key):
					_index[g].append(key)
			_cache[key + "#path"] = AUDIO_ROOT + sub + "/" + file


## Resolves "creak" (random variant), "creak_2" or "sfx/creak_2" to a stream.
func get_stream(sound: String) -> AudioStream:
	var key := sound
	if not sound.contains("/"):
		var list: Array = _index.get(sound, [])
		if list.is_empty():
			push_warning("AudioManager: unknown sound '%s'" % sound)
			return null
		key = list[randi() % list.size()]
	if _cache.has(key):
		return _cache[key]
	var path: String = _cache.get(key + "#path", "")
	if path == "" or not ResourceLoader.exists(path):
		push_warning("AudioManager: missing file for '%s'" % sound)
		return null
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis and (key.begins_with("music/") or key.begins_with("ambience/")):
		stream.loop = true
	_cache[key] = stream
	return stream


func has_sound(sound: String) -> bool:
	return _index.has(sound)


# ------------------------------------------------------------------ playback
func play_2d(sound: String, volume_db := 0.0, pitch := 1.0, bus := "SFX") -> AudioStreamPlayer:
	var stream := get_stream(sound)
	if stream == null:
		return null
	var p: AudioStreamPlayer = null
	for c in _pool_2d:
		if not c.playing:
			p = c
			break
	if p == null:
		p = _pool_2d[0]
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	p.play()
	return p


func play_ui(sound: String) -> void:
	play_2d(sound, -6.0, randf_range(0.97, 1.03))


func play_jumpscare(sound: String, volume_db := 0.0) -> void:
	play_2d(sound, volume_db, 1.0, "Jumpscare")


## Positional sound. `parent` defaults to the current scene.
func play_3d(sound: String, pos: Vector3, volume_db := 0.0, unit_size := 8.0, pitch := 1.0, bus := "SFX", parent: Node = null) -> AudioStreamPlayer3D:
	var stream := get_stream(sound)
	if stream == null:
		return null
	var host := parent if parent != null else get_tree().current_scene
	if host == null or not (host is Node3D or host is Node):
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.max_distance = unit_size * 10.0
	p.pitch_scale = pitch
	p.bus = bus
	p.attenuation_filter_cutoff_hz = 6000.0
	p.attenuation_filter_db = -18.0
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	host.add_child(p)
	if p.is_inside_tree():
		p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Sound emitted by a moving node (follows it).
func play_attached(sound: String, node: Node3D, volume_db := 0.0, unit_size := 8.0, pitch := 1.0, bus := "SFX") -> AudioStreamPlayer3D:
	var p := play_3d(sound, node.global_position, volume_db, unit_size, pitch, bus, node)
	if p:
		p.position = Vector3.ZERO
	return p


## A voice/whisper coming from a direction relative to the listener
## (used to make Satella speak from behind, the left, the right...).
func play_directional(sound: String, direction: Vector3, distance := 4.0, volume_db := 0.0, bus := "Voice") -> void:
	if _listener == null or not is_instance_valid(_listener):
		play_2d(sound, volume_db, 1.0, bus)
		return
	var pos := _listener.global_position + direction.normalized() * distance
	play_3d(sound, pos, volume_db, 4.0, 1.0, bus)


func set_listener(node: Node3D) -> void:
	_listener = node


# ------------------------------------------------------------------ ambience / music
## Cross-fades the looping beds. `layers` = {"amb_void_wind": 0.6, ...}
func set_ambience(layers: Dictionary, profile := "mansion") -> void:
	_ambient_profile = profile
	for name in _ambience_target.keys():
		_ambience_target[name] = 0.0
	for name in layers.keys():
		if not _ambience.has(name):
			var p := AudioStreamPlayer.new()
			p.bus = "Ambience"
			p.stream = get_stream(name)
			p.volume_db = -60.0
			add_child(p)
			if p.stream:
				p.play()
			_ambience[name] = p
		_ambience_target[name] = layers[name]


func _ensure_music(layer: String, sound: String) -> AudioStreamPlayer:
	if not _music.has(layer):
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.stream = get_stream(sound)
		p.volume_db = -60.0
		add_child(p)
		if p.stream:
			p.play()
		_music[layer] = p
		_music_target[layer] = 0.0
	return _music[layer]


func set_music_mode(mode: String) -> void:
	music_mode = mode
	_ensure_music("dread", "music_dread")
	_ensure_music("presence", "music_presence")
	_ensure_music("chase", "music_chase")
	_ensure_music("throne", "music_throne")
	_ensure_music("lobby", "music_lobby")
	_ensure_music("credits", "music_credits")
	if mode == "credits":
		var c: AudioStreamPlayer = _music["credits"]
		c.play(0.0)


func stop_all_music(immediate := false) -> void:
	for k in _music.keys():
		_music_target[k] = 0.0
		if immediate:
			_music[k].volume_db = -80.0


func set_panic(value: float) -> void:
	_panic = clampf(value, 0.0, 1.0)


## Muffles everything (death, fainting). 0 = clear, 1 = underwater.
func set_muffle(amount: float) -> void:
	_muffle_target = lerpf(20500.0, 380.0, clampf(amount, 0.0, 1.0))


func glitch_audio(duration: float) -> void:
	AudioServer.set_bus_effect_enabled(0, 1, true)
	_distortion_time = duration


func _process(delta: float) -> void:
	# Smooth bus effects
	_lowpass.cutoff_hz = lerpf(_lowpass.cutoff_hz, _muffle_target, clampf(delta * 3.0, 0.0, 1.0))
	if _distortion_time > 0.0:
		_distortion_time -= delta
		if _distortion_time <= 0.0:
			AudioServer.set_bus_effect_enabled(0, 1, false)
	# Ambience crossfades
	for name in _ambience.keys():
		var p: AudioStreamPlayer = _ambience[name]
		var target_db := linear_to_db(maxf(_ambience_target.get(name, 0.0), 0.0001))
		p.volume_db = move_toward(p.volume_db, target_db, delta * 12.0)
	_update_music(delta)
	if get_tree().paused:
		return
	_update_ambient_oneshots(delta)
	_update_panic(delta)


func _update_music(delta: float) -> void:
	if _music.is_empty():
		return
	for k in _music_target.keys():
		_music_target[k] = 0.0
	match music_mode:
		"lobby":
			_music_target["lobby"] = 0.55
		"throne":
			_music_target["throne"] = 0.7
			_music_target["presence"] = 0.35 * presence
			_music_target["chase"] = 0.8 if chase_active else 0.0
		"credits":
			_music_target["credits"] = 0.8
		"silent":
			pass
		_:
			# Dread "breathes": long windows of music separated by long silences.
			_music_breath_timer -= delta
			if _music_breath_timer <= 0.0:
				_dread_allowed = not _dread_allowed
				_music_breath_timer = randf_range(45.0, 90.0) if _dread_allowed else randf_range(60.0, 140.0)
			var stage := EnvyAwareness.stage()
			if _dread_allowed and stage >= 1:
				_music_target["dread"] = 0.25 + 0.08 * stage
			_music_target["presence"] = clampf(presence, 0.0, 1.0) * 0.6
			if chase_active:
				_music_target["chase"] = 0.9
				_music_target["dread"] = 0.0
				_music_target["presence"] = 0.25
	for k in _music.keys():
		var p: AudioStreamPlayer = _music[k]
		var target_db := linear_to_db(maxf(_music_target.get(k, 0.0), 0.0001))
		var speed := 30.0 if (k == "chase" and chase_active) else 9.0
		p.volume_db = move_toward(p.volume_db, target_db, delta * speed)


func _update_ambient_oneshots(delta: float) -> void:
	if _listener == null or not is_instance_valid(_listener) or not _listener.is_inside_tree():
		return
	if music_mode == "lobby" or music_mode == "credits":
		return
	_ambient_timer -= delta
	if _ambient_timer > 0.0:
		return
	var factor := EnvyAwareness.presence_factor()
	_ambient_timer = randf_range(9.0, 24.0) / maxf(0.6, factor)
	var pool: Array = []
	match _ambient_profile:
		"forest":
			pool = ["creak", "creak", "whisper", "footsteps_distant"]
		"void":
			pool = ["whisper", "thump", "reality_bend"]
		"silent":
			return
		_:
			pool = ["creak", "creak", "creak", "footsteps_distant", "knock", "clock_tick"]
			if EnvyAwareness.stage() >= 1:
				pool.append("whisper")
			if EnvyAwareness.stage() >= 2:
				pool.append_array(["whisper", "thump", "door_close"])
	var s: String = pool[randi() % pool.size()]
	var dir := Vector3(randf_range(-1, 1), randf_range(-0.2, 0.4), randf_range(-1, 1)).normalized()
	var dist := randf_range(5.0, 14.0)
	var vol := -8.0 if s == "whisper" else -4.0
	var bus := "Voice" if s == "whisper" else "SFX"
	play_3d(s, _listener.global_position + dir * dist, vol, 6.0, randf_range(0.85, 1.05), bus)


func _update_panic(delta: float) -> void:
	if _panic < 0.15:
		return
	_heart_timer -= delta
	if _heart_timer <= 0.0:
		_heart_timer = lerpf(1.1, 0.38, _panic)
		play_2d("heartbeat", lerpf(-22.0, -4.0, _panic), 1.0)
	if _panic > 0.45:
		_breath_timer -= delta
		if _breath_timer <= 0.0:
			_breath_timer = lerpf(1.6, 0.7, _panic)
			play_2d("breath_in" if _breath_in else "breath_out", lerpf(-20.0, -8.0, _panic), randf_range(0.95, 1.1))
			_breath_in = not _breath_in
