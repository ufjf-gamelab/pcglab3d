extends OmniLight3D
class_name FlickerLight

@export var base_energy := 1.5
@export var energy_flicker := 0.35
@export var base_range := 4.0
@export var range_flicker := 0.15
@export var flicker_speed := 6.0
@export var jitter := 0.02

var noise := FastNoiseLite.new()
var time := 0.0
var origin: Vector3

func _ready():
	noise.seed = randi()
	noise.frequency = 1.0
	origin = position

func _process(delta):
	time += delta * flicker_speed
	var n := noise.get_noise_1d(time)
	light_energy = base_energy * (1.0 + n * energy_flicker)
	omni_range = base_range * (1.0 + n * range_flicker)
	var offset := Vector3(noise.get_noise_2d(time, 50.0), noise.get_noise_2d(time, 100.0), noise.get_noise_2d(time, 150.0))
	position = origin + offset * jitter
