class_name Player extends CharacterBody2D

signal health_change(heath_value: int);
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown: Timer = $DashCooldown

const SPEED = 100.0
const JUMP_VELOCITY = -300.0
const ANIMATION_IDLE: String = "idle"
const ANIMATION_JUMP: String = "jump"
const ANIMATION_WALK: String = "walk"
const ANIMATION_DASH: String = "dash"
const MAX_JUMP_COUNT: int = 2
const DEFAULT_HEALTH: int = 5
const DEFAULT_DASH_SPEED = 300

var is_dashing = false

var health = DEFAULT_HEALTH:
		set(value):
			health = max(value, 0)
			health_change.emit(health)
var invinvible = false


@onready var animated: AnimatedSprite2D = %AnimatedSprite2D
var jump_count = 0

func _physics_process(delta: float) -> void:
	var direction := 1.0
	if not dash_timer.is_stopped():
		move_and_slide()
		return
	
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		jump_count = 0
	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and (is_on_floor() or jump_count < MAX_JUMP_COUNT):
		velocity.y = JUMP_VELOCITY
		jump_count += 1

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		if Input.is_action_just_pressed("dash"):
			# cooldown para evitar o spam de dashes
			if not dash_cooldown.is_stopped():
				return
			# começa timer
			dash_timer.start()
			
			# começa animaçao
			is_dashing = true
			
			# logica de impulso
			velocity.x = direction * DEFAULT_DASH_SPEED
			velocity.y = 0
			
		else:
			velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
		
	_update_animations(direction)
	move_and_slide()



func _update_animations(direction: float) -> void:
	if is_dashing:
		animated.play(ANIMATION_DASH)
	else:
		if not is_on_floor():
			animated.play(ANIMATION_JUMP)
			animated.flip_h = direction < 0
		else:
			if direction != 0:
				animated.play(ANIMATION_WALK)
				animated.flip_h = direction < 0
			else:
				animated.play(ANIMATION_IDLE)
	

# funçoes de influencia externa
# ideal para inimigos e efeitos de itens

func take_damage():
	health -= 1



func _on_dash_timer_timeout() -> void:
	velocity.x = 0
	is_dashing = false
	dash_cooldown.start()
	pass # Replace with function body.

# Signal para a entrada de qualquer outro no
# use para configura o dano de inimigos, coleta de itens e etc
# use groups para facilitar isso ai
# para isso funcionar, todo e qualquer corpo deve ser um CharacterBody2D e nao outro Area2D
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == self:
		return

	if body.is_in_group("enemies"):
		# ignora dano enquanto o dash estiver ativo
		if not dash_timer.is_stopped():
			return
		# invencibilidade do player
		if invinvible:
			return
		take_damage()
	pass # Replace with function body.
