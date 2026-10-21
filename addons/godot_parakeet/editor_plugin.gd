@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_custom_type("ParakeetVoice", "Node", preload("parakeet_voice.gd"), preload("icon.svg"))

func _exit_tree() -> void:
	remove_custom_type("ParakeetVoice")
