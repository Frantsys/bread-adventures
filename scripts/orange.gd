class_name Orange extends CharacterBody2D
@onready var animated: AnimatedSprite2D = $AnimatedSprite2D
@onready var sensors: Node2D = $Node2D
@onready var avoid_timer: Timer = $AvoidTimer
@onready var floor_ray: RayCast2D = $Node2D/FloorRay
@onready var wall_ray: RayCast2D = $Node2D/WallRay

const SPEED = 60.0
const JUMP_VELOCITY = -200.0
const DEFAULT_GRAVITY: float = 980
var gravity: float = DEFAULT_GRAVITY

var player: Player = null
var direction := 1.0

func _ready() -> void:
	# busca pelo primeiro jogador na arvore de nodes
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D

func _physics_process(delta: float) -> void:
# aplica gravidade
	if not is_on_floor():
		velocity.y += DEFAULT_GRAVITY * delta

	if player == null:
		move_and_slide()
		return

	# define a direção (persegue o player ou foge de buraco se o timer estiver ativo)
	if avoid_timer.is_stopped():
		var diff_x := player.global_position.x - global_position.x
		# Zona morta de 10px para não ficar tremendo exatamente em cima do player
		if abs(diff_x) > 10.0:
			direction = sign(diff_x)

	update_facing(direction)

	# evitar buracos fundos
	if is_on_floor() and not floor_ray.is_colliding() and avoid_timer.is_stopped():
		direction *= -1
		update_facing(direction)
		# mantém a direção oposta por 0.8s para se afastar da borda sem travar
		avoid_timer.start()

	velocity.x = direction * SPEED
	animated.flip_h = (direction < 0)
	
	move_and_slide()
	update_animations(direction)

func update_facing(dir: int) -> void:
	# muda a direcao do raycast de acordo com a direçao do inimigo
	sensors.scale.x = dir


func update_animations(direction: float):
	if not is_on_floor():
		animated.play("fall")
	if direction != 0:
		animated.play("walking")
		animated.flip_h = direction < 0
	else:
		animated.play("idle")
