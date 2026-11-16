class_name FlickerLight
extends OmniLight3D
## Candle / sconce / chandelier light. Gently breathing flame flicker, plus
## horror hooks used by the Horror Event Director and Satella:
##   blackout(t)  - goes dark for t seconds, then relights with a sputter
##   kill()       - permanently extinguished (for this loop)
##   surge()      - a violent violet flare when she manifests nearby
##   relight()    - lit again (puzzles)

@export var flicker := 0.15
@export var flicker_speed := 7.0
var base_energy := 1.0
var base_color := Color(1.0, 0.62, 0.32)
var lit := true
var flame: Node3D = null             ## Optional visible flame mesh toggled with the light.
var _t := randf() * 100.0
var _blackout := 0.0
var _surge := 0.0


func _ready() -> void:
	add_to_group("flicker_lights")
	base_energy = light_energy
	base_color = light_color


func _process(delta: float) -> void:
	_t += delta * flicker_speed
	if not lit:
		light_energy = 0.0
		return
	if _blackout > 0.0:
		_blackout -= delta
		light_energy = 0.0 if _blackout > 0.25 or randf() < 0.5 else base_energy * 0.4
		if flame:
			flame.visible = light_energy > 0.0
		return
	var n := sin(_t) * 0.5 + sin(_t * 2.31 + 1.3) * 0.3 + sin(_t * 5.7) * 0.2
	var e := base_energy * (1.0 + n * flicker)
	if _surge > 0.0:
		_surge -= delta
		e *= 1.0 + _surge * 3.0
		light_color = base_color.lerp(Color(0.6, 0.2, 1.0), clampf(_surge, 0.0, 1.0))
	else:
		light_color = base_color
	light_energy = maxf(e, 0.0)
	if flame:
		flame.visible = true
		flame.scale = Vector3.ONE * (0.9 + n * 0.15)


func blackout(duration: float) -> void:
	_blackout = duration


func kill() -> void:
	lit = false
	light_energy = 0.0
	if flame:
		flame.visible = false


func relight() -> void:
	lit = true
	_blackout = 0.0
	if flame:
		flame.visible = true


func surge(amount := 1.0) -> void:
	_surge = amount
