class_name MailboxScreen
extends CanvasLayer
## MailboxScreen — 邮箱弹层（二级场景）
## 覆盖在 computer_screen 之上；遮罩拦截输入使底层图标不可点；
## 关闭按钮或点击遮罩（Panel 外区域）关闭并恢复交互。
## 本阶段仅界面骨架：邮件内容由剧情系统通过 load_mails() 填充。


## 弹层已关闭（ComputerScreen 监听以解锁输入）
signal closed

@onready var _dim: ColorRect = $Dim
@onready var _mail_list: ItemList = $Panel/MailList
@onready var _close_button: Button = $Panel/CloseButton


func _ready() -> void:
	_close_button.pressed.connect(close)
	_dim.gui_input.connect(_on_dim_gui_input)


## 数据接口：加载邮件列表（本阶段空实现，留待剧情系统调用）
func load_mails(mail_data: Array) -> void:
	# TODO: 将 mail_data 填充到 _mail_list，并支持点击查看邮件详情
	pass


## 关闭弹层
func close() -> void:
	closed.emit()
	queue_free()


## 点击遮罩（Panel 外区域）关闭
func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
