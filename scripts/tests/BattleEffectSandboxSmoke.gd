extends SceneTree

const SandboxScene := preload("res://scenes/debug/BattleEffectSandbox.tscn")


func _init() -> void:
	var sandbox = SandboxScene.instantiate()
	sandbox.demo_enabled = false
	root.add_child(sandbox)
	await process_frame
	sandbox.play_demo_step()
	await process_frame
	print("BattleEffectSandbox smoke passed")
	quit()
