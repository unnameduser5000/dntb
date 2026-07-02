extends Node

## CI-safe DialogueManager autoload wrapper.
## The third-party plugin runtime is not required for the current smoke path,
## and its script graph is not stable in headless CI on this branch.

signal dialogue_started(resource_path: String, cue: String)
signal passed_cue(cue: String)
signal got_dialogue(line)
signal mutated(mutation: Dictionary)
signal dialogue_ended(resource_path: String)


func is_runtime_available() -> bool:
	return false
