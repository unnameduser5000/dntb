extends SceneTree

const SandboxScene := preload("res://scenes/debug/ActorPresentationSandbox.tscn")


func _init() -> void:
	var sandbox = SandboxScene.instantiate()
	root.add_child(sandbox)
	call_deferred("_finish")


func _finish() -> void:
	await process_frame
	print("ActorPresentationSandbox smoke passed")
	quit()
