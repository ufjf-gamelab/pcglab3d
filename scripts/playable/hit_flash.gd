extends Node
class_name HitFlash
# Checa o life do objeto pai e dá um flash branco quando ele sofre dano

@export var flash_color := Color(1, 1, 1, 0.85)
@export var duration := 0.15 # Quantos segundos até o flash sair

var _target: Node
var _last_life: int
var _material: StandardMaterial3D
var _tween: Tween

func _ready():
	_target = get_parent()
	_last_life = _target.life

	# Resolvi criar um novo material que faz overlay, porque todos os objetos compartilham do mesmo material
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(flash_color, 0.0)

	# Aqui eu percorro todos os filhos que são MeshInstance3D e aplico o material de overlay
	# Esse * é pra pegar qualquer nome, o true é que é recursivo, e o false é pra pegar cenas instanciadas
	for mesh in _target.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = _material

func _process(_delta):
	# TODO: Chamar isso só quando o life mudar

	if _target.life < _last_life:
		flash()
	_last_life = _target.life

func flash():
	if _tween:
		_tween.kill()
	
	# O albedo_color:a significa que eu só quero mudar o alfa
	_material.albedo_color.a = flash_color.a
	_tween = create_tween()
	_tween.tween_property(_material, "albedo_color:a", 0.0, duration)
