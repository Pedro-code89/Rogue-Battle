extends CharacterBody2D
## Inimigo que persegue o jogador ao detectá-lo, por um tempo limitado.
 
@export var hp := 150
@export var max_hp := 150
 
@export var speed := 100.0
@export var stop_distance := 25.0
@export var attack_distance := 30.0    # alcance de combo: aqui ele abre com Attack1
@export var attack2_range := 30.0      # alcance geral do combo: usado pra abrir/encadear Attack2 e Attack3
@export var chase_duration := 10.0
@export var damage_attack := 7.0
@export var damage_attack2 := 12.0
@export var damage_attack3 := 15.0
@export var attack3_stun_duration := 1.5   # por quanto tempo o golpe final paralisa o player
@export var attack3_cooldown := 1.5        # tempo mínimo entre um Attack3 e o próximo
@export var attack_cooldown := 0.4   # tempo de "respiro" depois de terminar o combo
@export var knockback_force := 90.0       # força do empurrão pra trás
@export var knockback_friction := 520.0   # quão rápido o empurrão desacelera

# Variação do combo — pesos de 0.0 a 1.0
@export var chance_attack1_repeat := 0.25     # do Attack1: chance de repetir (jab duplo) em vez de ir pro Attack2
@export var chance_skip_to_attack3 := 0.30    # do Attack1: chance de pular direto pro golpe final
@export var chance_attack2_loop_attack1 := 0.20  # do Attack2: chance de voltar pro Attack1 em vez de fechar com Attack3

@onready var player: Node2D = get_tree().get_first_node_in_group("player")
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var chase_timer: Timer = $ChaseTimer
@onready var hit_particles: GPUParticles2D = $Hit_particles
@onready var shock_player_tree: AnimationPlayer = $ShockPlayerTree
@onready var shock_hit: AnimationPlayer = $ShockHit

enum AttackType { NONE, ATTACK1, ATTACK2, ATTACK3 }
var current_attack := AttackType.NONE

var is_chasing := false
var is_attacking := false
var gravity := ProjectSettings.get_setting("physics/2d/default_gravity") as float
var is_dead := false

var knockback_velocity_x := 0.0
var attack_cooldown_timer := 0.0

var can_attack3 := true
var attack3_cooldown_timer := 0.0

const DAMAGE_LABEL = preload("uid://by3nwql4oot7k")

const ANIM_ATTACK1 := "Attack_Shock"
const ANIM_ATTACK2 := "Attack_Shock_1"
const ANIM_ATTACK3 := "Attack_Shock_2"      # ajusta pro nome real da animação no AnimatedSprite2D
const TREE_ATTACK1 := "attack_shock"
const TREE_ATTACK2 := "attack_2_shock"
const TREE_ATTACK3 := "attack_3_shock"      # ajusta pro nome real da animação no ShockPlayerTree
 
@onready var hitbox: Area2D = $Hitbox  # ajusta o nome se for diferente
@onready var hitbox_2: Hitbox = $Hitbox2
@onready var hitbox_3: Hitbox = $Hitbox3

var hitbox_base_offset_x := 0.0

func _ready() -> void:
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	chase_timer.timeout.connect(_on_chase_timer_timeout)

	chase_timer.wait_time = chase_duration
	chase_timer.one_shot = true

	animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)

	hitbox_base_offset_x = absf(hitbox.position.x)

func _face_player() -> void:
	if player == null:
		return

	var facing_left := player.global_position.x < global_position.x
	animated_sprite.flip_h = facing_left
	hitbox.position.x = hitbox_base_offset_x * (-1.0 if facing_left else 1.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	knockback_velocity_x = move_toward(knockback_velocity_x, 0.0, knockback_friction * delta)

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	if attack3_cooldown_timer > 0.0:
		attack3_cooldown_timer -= delta
		if attack3_cooldown_timer <= 0.0:
			can_attack3 = true

	_apply_gravity(delta)

	if player == null or not is_chasing:
		velocity.x = knockback_velocity_x
		move_and_slide()

		if not is_attacking:
			_update_animation()

		return

	var distance := absf(global_position.x - player.global_position.x)

	if distance <= attack2_range and attack_cooldown_timer <= 0.0:
		# =========================
		# ATAQUE
		# =========================
		velocity.x = knockback_velocity_x
		_face_player()

		if not is_attacking:
			is_attacking = true

			if distance <= attack_distance:
				_start_attack1()
			else:
				_start_attack2()

		move_and_slide()
	else:
		# =========================
		# PERSEGUIÇÃO
		# =========================
		if not is_attacking:
			velocity.x = _get_chase_velocity_x() + knockback_velocity_x
			move_and_slide()
			_update_animation()
		else:
			velocity.x = knockback_velocity_x
			move_and_slide()
 
 
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += gravity * delta
 
 
func _get_chase_velocity_x() -> float:
	var distance := absf(global_position.x - player.global_position.x)

	if distance <= stop_distance:
		return 0.0

	return signf(player.global_position.x - global_position.x) * speed
 
func _update_animation() -> void:
	if absf(velocity.x) > 0.1:
		animated_sprite.play("Move_Shock")
		animated_sprite.flip_h = velocity.x < 0
	else:
		animated_sprite.play("Idle_Shock")


func _start_attack1() -> void:
	current_attack = AttackType.ATTACK1

	hitbox.damage = damage_attack
	hitbox.stun_duration = 0.0

	print("START ATTACK1 | DANO: ", hitbox.damage)

	animated_sprite.play(ANIM_ATTACK1)
	shock_player_tree.play(TREE_ATTACK1)


func _start_attack2() -> void:
	current_attack = AttackType.ATTACK2

	hitbox_2.damage = damage_attack2
	hitbox.stun_duration = 0.0

	print("START ATTACK2 | DANO: ", hitbox.damage)

	animated_sprite.play(ANIM_ATTACK2)
	shock_player_tree.play(TREE_ATTACK2)


func _start_attack3() -> void:
	current_attack = AttackType.ATTACK3

	hitbox_3.damage = damage_attack3
	hitbox.stun_duration = attack3_stun_duration

	print("START ATTACK3 | DANO: ", hitbox.damage)

	animated_sprite.play(ANIM_ATTACK3)
	shock_player_tree.play(TREE_ATTACK3)

	can_attack3 = false
	attack3_cooldown_timer = attack3_cooldown
func _end_attack_sequence() -> void:
	is_attacking = false
	current_attack = AttackType.NONE
	attack_cooldown_timer = attack_cooldown
	_update_animation()
 
 
func _on_animated_sprite_animation_finished() -> void:
	if animated_sprite.animation == ANIM_ATTACK1:
		var distance := INF
		if player != null:
			distance = absf(global_position.x - player.global_position.x)

		if distance > attack2_range:
			_end_attack_sequence()
			return

		var roll := randf()

		if roll < chance_skip_to_attack3 and can_attack3:
			_start_attack3()
		elif roll < chance_skip_to_attack3 + chance_attack1_repeat:
			_start_attack1()  # jab duplo
		else:
			_start_attack2()

	elif animated_sprite.animation == ANIM_ATTACK2:
		var distance := INF
		if player != null:
			distance = absf(global_position.x - player.global_position.x)

		if distance > attack2_range:
			_end_attack_sequence()
			return

		var roll := randf()

		if roll < chance_attack2_loop_attack1:
			_start_attack1()  # reinicia o combo em vez de fechar
		elif can_attack3:
			_start_attack3()
		else:
			_end_attack_sequence()  # Attack3 em cooldown, encerra em vez de repetir à toa

	elif animated_sprite.animation == ANIM_ATTACK3:
		_end_attack_sequence()  # combo sempre termina aqui
 
func flash_hit():
	shock_hit.play("hit_flash_shock")
 

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_chasing = true
		chase_timer.stop()


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		chase_timer.start()


func _on_chase_timer_timeout() -> void:
	is_chasing = false
	is_attacking = false

func take_damage(amount: int) -> void:
 
	hp -= amount
	hp = clampi(hp, 0, max_hp)
 
	flash_hit()

	if hp <= 0:
		die()
		return
 
	var knock_direction := 1.0
	if player != null:
		knock_direction = signf(global_position.x - player.global_position.x)

	knockback_velocity_x = knock_direction * knockback_force
 
	var new_damage_label = DAMAGE_LABEL.instantiate() as Label
	new_damage_label.text = str(amount)
	new_damage_label.global_position = global_position + Vector2(-25, -70)
 
	get_tree().current_scene.call_deferred(
		"add_child",
		new_damage_label
	)
 
	hit_particles.restart()
	hit_particles.emitting = true
 
func die() -> void:
	is_dead = true
	is_attacking = false
	current_attack = AttackType.NONE
	velocity = Vector2.ZERO
 
	animated_sprite.play("Death_Shock")
	shock_player_tree.play("death_shock")
