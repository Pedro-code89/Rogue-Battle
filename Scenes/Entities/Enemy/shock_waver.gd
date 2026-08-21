extends CharacterBody2D
class_name ShockWaver

@export var speed: float = 60.0
@export var attack_range: float = 45.0
@export var attack_cooldown: float = 0.4   # só aplicado depois do combo completo

const ATTACK_ANIMS := ["attack1_shockwaver", "attack2_shockwaver", "attack3_shockwaver"]
const ATTACK_MATED := ["Attack_shock_waver", "Attack_2_shock_waver", "Attack_3_shock_waver"]

var combo_index: int = 0   # 0, 1 ou 2 — qual golpe do combo é o próximo

var player: Node2D = null
var can_attack: bool = true
var is_attacking: bool = false

const GRAVITY: float = 900.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var detection_area: Area2D = $DetectionAreaShock


func _ready() -> void:
	detection_area.body_entered.connect(_on_detection_area_body_entered)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if is_attacking:
		velocity.x = 0

	elif player:
		# Verifica somente a distância horizontal entre o inimigo e o player
		var distance_to_player = abs(player.global_position.x - global_position.x)

		if distance_to_player <= attack_range:
			velocity.x = 0  # dentro do alcance, para de andar — ataca ou espera o cooldown

			if can_attack:
				start_attack()
		else:
			var direction = sign(player.global_position.x - global_position.x)
			velocity.x = direction * speed

	else:
		velocity.x = 0

	handle_animation()
	move_and_slide()


func handle_animation() -> void:
	if is_attacking:
		return  # a animação de ataque já é tocada em start_attack(), não sobrescreve aqui

	if velocity.x != 0:
		animated_sprite.play("Run_shock_waver")
		animated_sprite.flip_h = velocity.x < 0
	else:
		animated_sprite.play("Idle_shock_waver")


func start_attack() -> void:
	is_attacking = true
	can_attack = false

	# Primeiro troca a "faixa" de animação do sprite pra a correta,
	# depois deixa o AnimationPlayer scrubar o frame dentro dela E
	# ligar/desligar o hitbox, tudo sincronizado.
	animated_sprite.play(ATTACK_MATED[combo_index])
	animation_player.play(ATTACK_ANIMS[combo_index])

	await animation_player.animation_finished
	is_attacking = false

	combo_index += 1

	if combo_index >= ATTACK_ANIMS.size():
		# combo completo — reseta e aplica o cooldown de verdade
		combo_index = 0
		await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true
	else:
		# ainda tem golpe no combo — libera na hora, sem espera
		can_attack = true


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
