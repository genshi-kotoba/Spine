class_name ComputerScreen
extends MainScene
## ComputerScreen — 场景二：电脑桌面
## 固定摄像机纯点击交互；自定义鼠标光标；左侧三图标；
## mail_icon 点击后打开 mailbox_screen 弹层（打开期间锁定底层输入）。


const MAILBOX_SCENE := preload("res://scenes/mailbox_screen.tscn")
const CURSOR_TEXTURE := preload("res://assets/sprites/cursor_icon.png")

@onready var _mail_icon: MailIcon = $MailIcon

## 当前打开的邮箱弹层实例（空表示未打开）
var _mailbox: MailboxScreen = null


func _ready() -> void:
	super._ready()
	Input.set_custom_mouse_cursor(CURSOR_TEXTURE)
	_mail_icon.open_mailbox.connect(open_mailbox)


func _exit_tree() -> void:
	# 恢复默认光标，避免污染其他场景
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)


## 打开邮箱弹层并锁定底层输入
func open_mailbox() -> void:
	if _mailbox != null:
		return
	_mailbox = MAILBOX_SCENE.instantiate()
	_mailbox.closed.connect(_on_mailbox_closed)
	add_child(_mailbox)
	StoryMonitor.lock_input()


func _on_mailbox_closed() -> void:
	_mailbox = null
	StoryMonitor.unlock_input()
