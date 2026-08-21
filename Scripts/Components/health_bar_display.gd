extends Sprite2D
class_name HealthBarDisplay

@export var health_textures: Array[Texture2D]
@export var target: Node

const LOW_HP_THRESHOLD: float = 0.25
const FLASH_COLOR: Color = Color(1.0, 0.2, 0.2)  # vermelho
const NORMAL_COLOR: Color = Color(1.0, 1.0, 1.0)  # cor original
const FLASH_DURATION: float = 0.4  # velocidade do pisca-pisca

var flash_tween: Tween

func _ready() -> void:
	if target and target.has_signal("hp_changed"):
		target.hp_changed.connect(_on_hp_changed)
		if not health_textures.is_empty():
			texture = health_textures[0]
	else:
		push_warning("HealthBarDisplay: target não definido ou não tem sinal hp_changed")

func _on_hp_changed(new_hp: float, max_hp: float) -> void:
	if health_textures.is_empty():
		return
	var percent := clampf(new_hp / max_hp, 0.0, 1.0)
	var index := int(round((1.0 - percent) * (health_textures.size() - 1)))
	index = clampi(index, 0, health_textures.size() - 1)
	texture = health_textures[index]

	if percent <= LOW_HP_THRESHOLD and percent > 0:
		start_flash()
	else:
		stop_flash()

func start_flash() -> void:
	if flash_tween and flash_tween.is_valid():
		return  # já tá piscando

	flash_tween = create_tween()
	flash_tween.set_loops()
	flash_tween.tween_property(self, "modulate", FLASH_COLOR, FLASH_DURATION)
	flash_tween.tween_property(self, "modulate", NORMAL_COLOR, FLASH_DURATION)

func stop_flash() -> void:
	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()
	modulate = NORMAL_COLOR
