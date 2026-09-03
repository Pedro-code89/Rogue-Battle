extends CharacterBody2D 
## Inimigo que persegue o jogador ao detectá-lo, por um tempo limitado.

@export var hp := 150
@export var max_hp := 150

@export var speed := 100.0
@export var stop_distance := 25.0
@export var attack_distance := 30.0
@export var attack2_range := 30.0
@export var chase_duration := 10.0
@export var damage_attack := 12.0
@export var damage_attack2 := 15.0
@export var damage_attack3 := 30.0
@export var attack3_stun_duration := 3.0
@export var attack3_cooldown := 1.0
@export var attack_cooldown := 0.3
@export var knockback_force := 90.0
@export var knockback_friction := 520.0

# Variação do combo
@export var chance_attack1_repeat := 0.25
@export var chance_skip_to_attack3 := 0.25
@export var chance_attack2_loop_attack1 := 0.25

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
const ANIM_ATTACK3 := "Attack_Shock_2"

const TREE_ATTACK1 := "attack_shock"
const TREE_ATTACK2 := "attack_2_shock"
const TREE_ATTACK3 := "attack_3_shock"

@onready var hitbox: Area2D = $Hitbox
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

	knockback_velocity_x = move_toward(
		knockback_velocity_x,
		0.0,
		knockback_friction * delta
	)

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

			# Ataque inicial aleatório
			var roll := randi_range(1, 3)

			match roll:
				1:
					_start_attack1()

				2:
					_start_attack2()

				3:
					if can_attack3:
						_start_attack3()
					else:
						_start_attack1()

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
	hitbox_2.stun_duration = 0.0

	print("START ATTACK2 | DANO: ", hitbox_2.damage)

	animated_sprite.play(ANIM_ATTACK2)
	shock_player_tree.play(TREE_ATTACK2)


func _start_attack3() -> void:
	current_attack = AttackType.ATTACK3

	hitbox_3.damage = damage_attack3
	hitbox_3.stun_duration = attack3_stun_duration

	print("START ATTACK3 | DANO: ", hitbox_3.damage)

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
			_start_attack1()
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
			_start_attack1()
		elif can_attack3:
			_start_attack3()
		else:
			_end_attack_sequence()

	elif animated_sprite.animation == ANIM_ATTACK3:
		_end_attack_sequence()


func flash_hit() -> void:
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
