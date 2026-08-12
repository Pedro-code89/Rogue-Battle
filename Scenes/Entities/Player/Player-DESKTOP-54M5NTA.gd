extends CharacterBody2D

signal hp_changed(new_hp: float, max_hp: float)

enum PlayerState {
	IDLE,
	RUN,
	JUMP,
	TRANSITION,
	FALL,
	LAND,
	ATTACK1,
	ATTACK2,
	DEATH
}

@onready var AnimationCharacter: AnimatedSprite2D = $AnimatedSprite2D
@onready var AnimationControl: AnimationPlayer = $AnimationPlayer
@onready var hurtbox: Area2D = $HurtBox

const SPEED: float = 95.0
const SPEED_RUN: float = 140.0
const JUMP_VELOCITY: float = -300.0

var status: PlayerState
var buffered_attack := false
var jump_count: int = 0
var max_jump_count: int = 2
var hp: int = 100
var max_hp: int = 100


func _ready() -> void:
	go_to_idle_state()
	hp_changed.emit(hp, max_hp)

func _physics_process(delta: float) -> void:

	if Input.is_action_just_pressed("ui_cancel"):
		take_damage(20)

	if not is_on_floor():
		velocity += get_gravity() * delta


	match status:
		PlayerState.IDLE:
			idle_state()
		PlayerState.RUN:
			run_state()
		PlayerState.JUMP:
			jump_state()
		PlayerState.TRANSITION:
			transition_state()
		PlayerState.FALL:
			fall_state()
		PlayerState.LAND:
			land_state()
		PlayerState.ATTACK1:
			attack1_state()
		PlayerState.ATTACK2:
			attack2_state()
		PlayerState.DEATH:
			death_state()

	move_and_slide()

# RODA QUANDO TROCA

func go_to_idle_state():
	status = PlayerState.IDLE
	AnimationCharacter.play("Idle")

func go_to_run_state():
	status = PlayerState.RUN
	if AnimationCharacter.animation != "Run":
		AnimationCharacter.play("Run")

func go_to_jump_state():
	status = PlayerState.JUMP
	AnimationCharacter.play("Jump")
	AnimationControl.play("jump")
	velocity.y = JUMP_VELOCITY
	jump_count += 1

func go_to_transition_state():
	status = PlayerState.TRANSITION
	AnimationCharacter.play("Transition")

func go_to_fall_state():
	status = PlayerState.FALL
	AnimationCharacter.play("Fall")
	AnimationControl.play("fall")

func go_to_land_state():
	status = PlayerState.LAND
	AnimationCharacter.play("Land")
	velocity.x = 0

func go_to_attack1_state():
	status = PlayerState.ATTACK1
	face_mouse()
	AnimationControl.play("attack_1")
	AnimationCharacter.play("Attack_1")
	$AttackPivot/HitBox.damage = 10.0
	velocity.x = 0

func go_to_attack2_state():
	status = PlayerState.ATTACK2
	face_mouse()
	AnimationCharacter.play("Attack_2")
	AnimationControl.play("attack_2")
	$AttackPivot/HitBox.damage = 20.0
	velocity.x = 0

func go_to_death_state():
	status = PlayerState.DEATH
	velocity.x = 0
	AnimationCharacter.play("Death")

# FUNÇÕES QUE RODAM CONSTANTEMENTE

func idle_state():
	move()

	if not is_on_floor():
		go_to_fall_state()
		return

	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		go_to_run_state()
		return

	if Input.is_action_just_pressed("jump"):
		go_to_jump_state()
		return

	if Input.is_action_just_pressed("mouse_left"):
		go_to_attack1_state()
		return

func run_state():
	move()

	if not is_on_floor():
		go_to_fall_state()
		return

	var direction := Input.get_axis("move_left", "move_right")
	if direction == 0 and velocity.x == 0:
		go_to_idle_state()
		return

	if Input.is_action_just_pressed("jump"):
		go_to_jump_state()
		return

	if Input.is_action_just_pressed("mouse_left"):
		go_to_attack1_state()
		return

func jump_state():
	move()

	if Input.is_action_just_pressed("jump") and jump_count < max_jump_count:
		go_to_jump_state()
		return

	if velocity.y > 0:
		go_to_transition_state()
		return

func transition_state():
	move()

	if AnimationCharacter.frame == AnimationCharacter.sprite_frames.get_frame_count("Transition") - 1:
		go_to_fall_state()
		return

func fall_state():
	move()

	if is_on_floor():
		jump_count = 0
		go_to_land_state()
		return

func land_state():
	pass

func attack1_state():
	face_mouse()
	velocity.x = 0

	if Input.is_action_just_pressed("mouse_left"):
		buffered_attack = true

	var total_frames = AnimationCharacter.sprite_frames.get_frame_count("Attack_1")
	var current_frames = AnimationCharacter.frame

	if buffered_attack and current_frames >= total_frames * 0.8:
		buffered_attack = false
		go_to_attack2_state()
		return

func attack2_state():
	face_mouse()
	velocity.x = 0

	if Input.is_action_just_pressed("mouse_left"):
		buffered_attack = true

	var total_frames = AnimationCharacter.sprite_frames.get_frame_count("Attack_2")
	var current_frames = AnimationCharacter.frame

	if buffered_attack and current_frames >= total_frames * 0.7:
		buffered_attack = false
		go_to_attack1_state()
		return

func death_state():
	velocity.x = 0

# FUNÇÃO DE MOVIMENTO/ FUNÇÃO BÁSICA

func move():
	var direction := Input.get_axis("move_left", "move_right")

	var current_speed = SPEED
	if Input.is_action_pressed("run"):
		current_speed = SPEED_RUN

	if direction:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if direction < 0:
		AnimationCharacter.flip_h = true
		$AttackPivot.position.x = -20
	elif direction > 0:
		AnimationCharacter.flip_h = false
		$AttackPivot.position.x = 20

func face_mouse() -> void:
	var mouse_pos := get_global_mouse_position()
	if mouse_pos.x < global_position.x:
		AnimationCharacter.flip_h = true
		$AttackPivot.position.x = -20
	else:
		AnimationCharacter.flip_h = false
		$AttackPivot.position.x = 20

func take_damage(amount: int) -> void:
	if status == PlayerState.DEATH:
		return
	
	hp = clampi(hp - amount, 0, max_hp)

	hp_changed.emit(hp, max_hp)

	if hp <= 0:
		die()

func die() -> void:
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	go_to_death_state()

func _on_animated_sprite_2d_animation_finished() -> void:
	match AnimationCharacter.animation:
		"Attack_1":
			if buffered_attack:
				buffered_attack = false
				go_to_attack2_state()
			else:
				go_to_idle_state()
		"Attack_2":
			if buffered_attack:
				buffered_attack = false
				go_to_attack1_state()
			else:
				go_to_idle_state()
		"Land":
			go_to_idle_state()
		"Transition":
			go_to_fall_state()
		"Death":
			queue_free()
