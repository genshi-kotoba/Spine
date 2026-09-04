class_name MailIcon
extends InteractableObject
## MailIcon — 邮件图标
## 点击后发出 open_mailbox 信号，由 ComputerScreen 打开 mailbox_screen 弹层。


## 请求打开邮箱弹层
signal open_mailbox


func _ready() -> void:
	states = {
		"idle": {
			"texture": "res://assets/sprites/mail_icon.png",
			"size": Vector2(256, 256),
		},
	}
	super._ready()


## 点击 → 请求打开邮箱弹层
func interact() -> void:
	open_mailbox.emit()
