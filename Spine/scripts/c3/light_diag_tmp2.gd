extends SceneTree

func _init() -> void:
	var gs: Node = (load("res://scripts/autoload/GameState.gd") as Script).new()
	gs.name = "GameState"
	root.add_child(gs)
	var sm: Node = (load("res://scripts/autoload/StoryMonitor.gd") as Script).new()
	sm.name = "StoryMonitor"
	root.add_child(sm)
	await process_frame
	var scene: Node = load("res://scenes/c3_level.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var flow: Node = scene
	var asm: Node = scene.get_node_or_null("CorridorAssembly")
	var vis: Node2D = null
	if asm != null:
		vis = asm.get("_visual") as Node2D
	print("[diag] initial visual_visible=", vis.visible if vis != null else "n/a")
	flow.on_paper_collected("paper_living", 100)
	flow.on_paper_collected("paper_kitchen", 100)
	flow.on_paper_collected("study_b", 99)
	flow.on_paper_collected("study_a", 100)
	print("[diag] after4 stage=", flow.current_stage, " light_step=", flow._light_step, " locked=", sm.input_locked)
	for i in range(700):
		await physics_frame
		if i % 60 == 0:
			print("[diag] t=", i, " stage=", flow.current_stage, " light_step=", flow._light_step, " locked=", sm.input_locked)
		if flow.current_stage >= 7 and flow._light_step == 5:
			break
	print("[diag] final stage=", flow.current_stage, " light_step=", flow._light_step, " locked=", sm.input_locked, " hold=", gs.get_process_flag("hold_breath_unlocked"))
	if vis != null:
		print("[diag] visual_visible_final=", vis.visible)
	quit()
