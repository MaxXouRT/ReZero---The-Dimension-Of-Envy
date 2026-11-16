class_name FlashlightController
extends Node3D
## The flashlight: Subaru's only real tool in the Dimension of Envy.
##
##  * Realistic spot: limited range, soft cone, dynamic shadows, slight lag
##    behind the camera (hand sway) and a faint bounce light around the player.
##  * Battery: drains while on, dims and stutters when low; spare batteries
##    can be found. Never drains during cutscenes.
##  * Supernatural flicker: requested through EventBus.flashlight_flicker_requested
##    or directly by Satella (proximity makes it unstable).
##  * Used by the AI: SatellaAI asks `illuminates(point)` to know if the
##    player is shining the light on her.

@export var max_energy := 5.5
@export var spot_range := 22.0
@export var spot_angle := 30.0
@export var drain_per_second := 1.0 / 540.0   ## a full battery lasts ~9 minutes
@export var sway_amount := 9.0

var has_flashlight := false
var on := false
var spot: SpotLight3D
var bounce: OmniLight3D
var _flicker_time := 0.0
var _flicker_intensity := 0.0
var _dead_time := 0.0
var _noise_t := 0.0
var _target_basis := Basis()
var instability := 0.0           ## 0..1 set by Satella proximity
var drain_enabled := true


func _ready() -> void:
	spot = SpotLight3D.new()
	spot.name = "Spot"
	spot.spot_range = spot_range
	spot.spot_angle = spot_angle
	spot.spot_angle_attenuation = 0.9
	spot.spot_attenuation = 0.75
	spot.light_color = Color(1.0, 0.93, 0.82)
	spot.light_energy = max_energy
	spot.shadow_enabled = true
	spot.shadow_bias = 0.04
	spot.shadow_normal_bias = 1.0
	spot.light_volumetric_fog_energy = 0.6
	spot.light_specular = 0.6
	spot.position = Vector3(0.18, -0.16, -0.1)
	add_child(spot)
	bounce = OmniLight3D.new()
	bounce.name = "Bounce"
	bounce.omni_range = 3.2
	bounce.light_energy = 0.22
	bounce.light_color = Color(0.85, 0.8, 0.9)
	bounce.shadow_enabled = false
	bounce.light_volumetric_fog_energy = 0.0
	bounce.position = Vector3(0, 0, -1.2)
	add_child(bounce)
	EventBus.flashlight_flicker_requested.connect(flicker)
	_apply(false)


func give() -> void:
	has_flashlight = true
	GameState.add_item("flashlight")


func toggle() -> void:
	if not has_flashlight:
		return
	set_on(not on)


func set_on(value: bool, silent := false) -> void:
	if not has_flashlight:
		value = false
	if value == on:
		return
	on = value
	if not silent:
		AudioManager.play_2d("flashlight_click", -8.0, randf_range(0.95, 1.05))
	_apply(on)
	EventBus.flashlight_toggled.emit(on)


func _apply(state: bool) -> void:
	spot.visible = state
	bounce.visible = state


func battery() -> float:
	return float(GameState.run.get("battery", 1.0))


func add_battery() -> void:
	GameState.run["battery"] = 1.0
	AudioManager.play_2d("battery", -6.0)
	EventBus.flashlight_battery_changed.emit(1.0)


## Supernatural flicker. intensity 1 = the light nearly dies.
func flicker(duration: float, intensity := 1.0) -> void:
	_flicker_time = maxf(_flicker_time, duration)
	_flicker_intensity = maxf(_flicker_intensity, intensity)
	if on and duration > 0.3:
		AudioManager.play_attached("flicker_buzz", self, -14.0, 2.0)


## Light dies completely for `duration` seconds (events).
func die_for(duration: float) -> void:
	_dead_time = duration


func illuminates(point: Vector3) -> bool:
	if not on or not spot.visible or spot.light_energy < 0.3:
		return false
	var to := point - spot.global_position
	if to.length() > spot_range:
		return false
	var fwd := -spot.global_transform.basis.z
	return fwd.dot(to.normalized()) > cos(deg_to_rad(spot_angle * 0.8))


func _process(delta: float) -> void:
	# Hand sway: the light lags slightly behind the camera.
	var parent3d := get_parent() as Node3D
	if parent3d:
		var target := parent3d.global_transform.basis
		var lag := 1.0 if Settings.reduce_camera_motion else clampf(delta * sway_amount, 0.0, 1.0)
		_target_basis = _target_basis.slerp(target.orthonormalized(), lag) if _target_basis != Basis() else target.orthonormalized()
		global_transform.basis = _target_basis.orthonormalized()
	if not on:
		return
	# Battery
	var b := battery()
	if drain_enabled and not get_tree().paused:
		b = maxf(0.0, b - drain_per_second * delta)
		GameState.run["battery"] = b
		if int(b * 100.0) % 5 == 0:
			EventBus.flashlight_battery_changed.emit(b)
	var energy := max_energy * lerpf(0.25, 1.0, clampf(b / 0.3, 0.0, 1.0))
	if b <= 0.0:
		energy = 0.0
	_noise_t += delta
	# Low battery stutter
	if b < 0.15 and randf() < delta * 2.0:
		_flicker_time = maxf(_flicker_time, 0.25)
		_flicker_intensity = maxf(_flicker_intensity, 0.7)
	# Satella makes the light unstable
	if instability > 0.05 and randf() < delta * instability * 3.0:
		_flicker_time = maxf(_flicker_time, randf_range(0.1, 0.4))
		_flicker_intensity = maxf(_flicker_intensity, instability)
	var mult := 1.0
	if _dead_time > 0.0:
		_dead_time -= delta
		mult = 0.0
	elif _flicker_time > 0.0:
		_flicker_time -= delta
		var s := sin(_noise_t * 53.0) * sin(_noise_t * 21.7 + 1.3)
		mult = 1.0 - _flicker_intensity * (0.5 + 0.5 * s)
		if randf() < 0.15 * _flicker_intensity:
			mult = 0.0
		if _flicker_time <= 0.0:
			_flicker_intensity = 0.0
	spot.light_energy = energy * mult
	bounce.light_energy = 0.22 * mult * clampf(b * 3.0, 0.0, 1.0)
