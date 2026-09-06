class_name ComputerScreen
extends MainScene
## ComputerScreen — 场景二：电脑桌面
## 固定摄像机纯点击交互；系统原生光标（v1.2 去除自定义光标）；左侧 mail / work 双图标；
## 点击分别打开 mailbox_screen / work_screen 弹层（打开期间锁定底层输入）。
## 弹层互斥（docs/desktop_screens_constraints.md §4.4 决策 F7）：打开一个前先关闭另一个。


const MAILBOX_SCENE := preload("res://scenes/mailbox_screen.tscn")
const WORK_SCENE := preload("res://scenes/work_screen.tscn")

@onready var _mail_icon: MailIcon = $MailIcon
@onready var _work_icon: WorkIcon = $WorkIcon

## 当前打开的邮箱弹层实例（空表示未打开）
var _mailbox: MailboxScreen = null
## 当前打开的工作弹层实例（空表示未打开）
var _work_screen: WorkScreen = null


func _ready() -> void:
	super._ready()
	_mail_icon.open_mailbox.connect(open_mailbox)
	_work_icon.open_work.connect(open_work)


## 打开邮箱弹层并锁定底层输入（互斥：先关 work_screen）
func open_mailbox() -> void:
	if _mailbox != null:
		return
	if _work_screen != null:
		_work_screen.close()
	_mailbox = MAILBOX_SCENE.instantiate()
	_mailbox.closed.connect(_on_mailbox_closed)
	add_child(_mailbox)
	StoryMonitor.lock_input()


## 打开工作弹层并锁定底层输入（互斥：先关 mailbox）
func open_work() -> void:
	if _work_screen != null:
		return
	if _mailbox != null:
		_mailbox.close()
	_work_screen = WORK_SCENE.instantiate()
	_work_screen.closed.connect(_on_work_screen_closed)
	add_child(_work_screen)
	StoryMonitor.lock_input()


func _on_mailbox_closed() -> void:
	_mailbox = null
	StoryMonitor.unlock_input()


func _on_work_screen_closed() -> void:
	_work_screen = null
	StoryMonitor.unlock_input()
