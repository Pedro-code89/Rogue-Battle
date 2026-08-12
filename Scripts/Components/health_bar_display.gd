extends Sprite2D
class_name HealthBarDisplay

@export var health_textures: Array[Texture2D]
@export var target: Node

func _ready() -> void:
	if target and target.has_signal("hp_changed"):
		target.hp_changed.connect(_on_hp_changed)
		if not health_textures.is_empty():
			texture = health_textures[0]
	else:
		push_warning("HealthBarDisplay: target não definido ou não tem sinal hp_changed")


func _on_hp_changed(new_hp: float, max_hp: float) -> void:
	if  health_textures.is_empty():
		return

	var percent:= clampf(new_hp / max_hp, 0.0, 1.0)
	var index:= int(round((1.0 - percent) * (health_textures.size() - 1)))
	index = clampi(index, 0, health_textures.size() -1)

	texture = health_textures[index]
