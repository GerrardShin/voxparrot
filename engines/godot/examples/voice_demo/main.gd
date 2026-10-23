extends Node
## Headless-friendly demo: transcribes a WAV file through the local backend
## and prints the result, or (in a windowed run) hold SPACE to talk.
##
## Headless test:
##   godot --headless --path . -- --wav /path/to/sample.wav
## The ParakeetVoice node comes from the addon — this demo project expects
## the repo's engines/godot/addons/godot_parakeet folder to be copied/linked into it,
## exactly like a real game would. The run_demo.sh script sets that up.

var voice: ParakeetVoice
var _status: Label
var _transcript: Label


func _ready() -> void:
	voice = ParakeetVoice.new()
	add_child(voice)
	voice.transcription_received.connect(_on_transcription)
	voice.transcription_failed.connect(_on_failed)
	voice.command_recognized.connect(_on_command)
	# Demo command: this phrase in the JFK test clip triggers an event,
	# the same way "end turn" would in a card game.
	voice.register_command("ask not what your country", "jfk_quote")
	voice.register_command("end turn", "end_turn")

	var args := OS.get_cmdline_user_args()
	var wav_path := ""
	for i in args.size():
		if args[i] == "--wav" and i + 1 < args.size():
			wav_path = args[i + 1]
	if wav_path != "":
		print("[demo] transcribing: ", wav_path)
		voice.transcribe_file(wav_path)
		return
	_build_ui()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	_status = Label.new()
	_status.text = "Hold SPACE and speak (English), release to transcribe."
	vbox.add_child(_status)
	_transcript = Label.new()
	_transcript.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_transcript)


func _unhandled_input(event: InputEvent) -> void:
	if _status == null:
		return
	if event.is_action_pressed("ui_accept"):
		voice.start_recording()
		_status.text = "Recording..."
	elif event.is_action_released("ui_accept") and voice.is_recording():
		voice.stop_recording_and_transcribe()
		_status.text = "Transcribing..."


func _on_transcription(text: String, info: Dictionary) -> void:
	print("[demo] TRANSCRIPT: ", text)
	print("[demo] INFO: ", info)
	if _transcript:
		_transcript.text = text
		_status.text = "Hold SPACE and speak (English), release to transcribe."
	if _has_wav_arg():
		get_tree().quit(0)


func _on_command(command: String, text: String) -> void:
	print("[demo] COMMAND RECOGNIZED: ", command, " <- ", text)


func _on_failed(error: String) -> void:
	printerr("[demo] FAILED: ", error)
	if _has_wav_arg():
		get_tree().quit(1)


func _has_wav_arg() -> bool:
	return "--wav" in OS.get_cmdline_user_args()
