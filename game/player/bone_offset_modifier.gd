extends SkeletonModifier3D
class_name BoneOffsetModifier

@export var animation_player: AnimationPlayer
@export var base_animation: StringName = &"idle"
@export var upper_bone := "upperarm.l"
@export var upper_rotation := Vector3(20, 0, 0)
@export var lower_bone := "lowerarm.l"
@export var lower_rotation := Vector3(15, 0, -15)

var base_rotations := {}

func _ready():
	if animation_player == null or not animation_player.has_animation(base_animation):
		return
	var animation := animation_player.get_animation(base_animation)
	for bone_name in [upper_bone, lower_bone]:
		for i in animation.get_track_count():
			if animation.track_get_type(i) == Animation.TYPE_ROTATION_3D and String(animation.track_get_path(i)).ends_with(":" + bone_name):
				base_rotations[bone_name] = animation.rotation_track_interpolate(i, 0.0)

func _process_modification_with_delta(_delta: float):
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	apply_pose(skeleton, upper_bone, upper_rotation)
	apply_pose(skeleton, lower_bone, lower_rotation)

func apply_pose(skeleton: Skeleton3D, bone_name: String, rotation_degrees_offset: Vector3):
	var bone := skeleton.find_bone(bone_name)
	if bone == -1 or not base_rotations.has(bone_name):
		return
	var offset := Quaternion.from_euler(rotation_degrees_offset * PI / 180.0)
	skeleton.set_bone_pose_rotation(bone, base_rotations[bone_name] * offset)
