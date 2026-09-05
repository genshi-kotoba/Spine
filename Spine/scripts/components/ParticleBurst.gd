class_name ParticleBurst
extends Node2D
## ParticleBurst — 可复用底色粒子爆炸/震撼组件（C3 前置需求④）
## 一次性发射彩点粒子（随机方向），用于「震撼/碎裂」感。
## 参数化（amount/color/lifetime/spread/velocity/gravity/size），方法触发。
## 无房间/关卡字面量，可挂到任意 Node2D/Area2D 复用（同 DepthParallax 先例）。

## 粒子数量。
@export var amount: int = 40
## 底色粒子颜色（颜色随底色可调）。
@export var color: Color = Color(0.9, 0.85, 0.6, 1)
## 粒子寿命（秒）。
@export var lifetime: float = 0.8
## 扩散角（度，0..180；越大越散；180=全方向）。
@export var spread: float = 180.0
## 初速度（px/s）。
@export var initial_velocity: float = 300.0
## 重力（px/s²）。
@export var gravity: float = 500.0
## 单粒子尺寸（px）。
@export var size: float = 6.0

## 是否允许连续发射（false=一次性 burst 后复位）。
@export var emitting: bool = true

var _particles: GPUParticles2D = null
var _mat: ParticleProcessMaterial = null
var _burst_cooling: float = 0.0
## t34 gap ④：持续震撼发射剩余计时（start_continuous 期间不断喷发）。
var _continuous_left: float = 0.0


func _ready() -> void:
	_build_particles()


func _build_particles() -> void:
	_particles = get_node_or_null("Particles") as GPUParticles2D
	if _particles == null:
		_particles = GPUParticles2D.new()
		_particles.name = "Particles"
		add_child(_particles)
	_mat = ParticleProcessMaterial.new()
	_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_mat.emission_sphere_radius = 4.0
	_mat.direction = Vector3.UP
	_mat.spread = 180.0
	_mat.initial_velocity_min = initial_velocity * 0.5
	_mat.initial_velocity_max = initial_velocity
	_mat.gravity = Vector3(0, gravity, 0)
	_mat.scale_min = size * 0.5
	_mat.scale_max = size
	_mat.color = color
	_particles.process_material = _mat
	_particles.one_shot = true
	_particles.explosiveness = 1.0
	_particles.emitting = false


func _process(delta: float) -> void:
	if _burst_cooling > 0.0:
		_burst_cooling -= delta
	if _continuous_left > 0.0:
		_continuous_left -= delta
		if _continuous_left <= 0.0:
			_stop_continuous()


## 一次性发射后复位（便于重复触发）。
## emitting 作为发射主开关：emitting=false 时 burst() 为无操作（该系统被禁用）。
func burst() -> void:
	if not emitting:
		return
	_apply_material_params()
	_particles.restart()
	_particles.emitting = true
	_burst_cooling = lifetime


## 持续发射震撼粒子（t34 gap ④：沿拆除边沿一段时间内不断喷发；emitting 主开关仍有效）。
func start_continuous(dur: float) -> void:
	if not emitting:
		return
	_apply_material_params()
	_particles.one_shot = false
	_particles.emitting = true
	_continuous_left = dur


## 停止持续发射并复位为一次性爆裂。
func stop_continuous() -> void:
	_stop_continuous()


func _stop_continuous() -> void:
	_particles.emitting = false
	if not _particles.one_shot:
		_particles.one_shot = true
	_continuous_left = 0.0


## 运行时改底色粒子颜色。
func set_color(new_color: Color) -> void:
	color = new_color
	if _mat != null:
		_mat.color = new_color


func _apply_material_params() -> void:
	_particles.amount = amount
	_particles.lifetime = lifetime
	_mat.spread = spread
	_mat.initial_velocity_min = initial_velocity * 0.5
	_mat.initial_velocity_max = initial_velocity
	_mat.gravity = Vector3(0, gravity, 0)
	_mat.scale_min = size * 0.5
	_mat.scale_max = size
	_mat.color = color
