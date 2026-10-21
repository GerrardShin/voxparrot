class_name ParakeetVoice
extends Node
## On-device speech-to-text node for Godot 4.
##
## Two ways to feed it audio:
##  1. Push-to-talk microphone capture: [method start_recording] /
##     [method stop_recording_and_transcribe]
##  2. Any WAV you already have: [method transcribe_wav_bytes] /
##     [method transcribe_file]
##
## Recognition runs in the local backend (see backend/server.py in the repo):
## sherpa-onnx + NVIDIA Parakeet TDT, fully on-device. Nothing leaves the
## player's machine. A native GDExtension backend is on the roadmap; the
## HTTP contract stays the same so games will not need code changes.
##
## Register voice commands with [method register_command]; when a transcript
## contains the phrase, [signal command_recognized] fires.

signal transcription_received(text: String, info: Dictionary)
signal command_recognized(command: String, text: String)
signal transcription_failed(error: String)
signal recording_started
signal recording_stopped

## Base URL of the local STT backend.
@export var server_url: String = "http://127.0.0.1:8765"
## Audio bus used for microphone capture (created automatically if missing).
@export var capture_bus_name: String = "ParakeetCapture"

const TARGET_SAMPLE_RATE := 16000

var _commands: Dictionary = {}  # normalized phrase -> command id (String)
var _http: HTTPRequest
var _capture: AudioEffectCapture
var _mic_player: AudioStreamPlayer
var _recording: bool = false


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


## Register a voice command. When a transcript (lowercased, punctuation
## stripped) contains [param phrase], command_recognized emits [param command].
## Example: register_command("end turn", "end_turn")
func register_command(phrase: String, command: String) -> void:
	_commands[_normalize(phrase)] = command


func clear_commands() -> void:
	_commands.clear()


# ---------------------------------------------------------------- recording

func start_recording() -> void:
	if _recording:
		return
	_ensure_capture_chain()
	_capture.clear_buffer()
	_mic_player.play()
	_recording = true
	recording_started.emit()


func stop_recording_and_transcribe() -> void:
	if not _recording:
		return
	_recording = false
	_mic_player.stop()
	recording_stopped.emit()
	var frames_available := _capture.get_frames_available()
	if frames_available == 0:
		transcription_failed.emit("no audio captured")
		return
	var stereo: PackedVector2Array = _capture.get_buffer(frames_available)
	var mono := _to_mono_16k(stereo, int(AudioServer.get_mix_rate()))
	transcribe_wav_bytes(_encode_wav_16bit(mono, TARGET_SAMPLE_RATE))


func is_recording() -> bool:
	return _recording


func _ensure_capture_chain() -> void:
	if _capture:
		return
	var bus_idx := AudioServer.get_bus_index(capture_bus_name)
	if bus_idx == -1:
		AudioServer.add_bus()
		bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_idx, capture_bus_name)
		AudioServer.set_bus_send(bus_idx, "Master")
	_capture = null
	for i in AudioServer.get_bus_effect_count(bus_idx):
		if AudioServer.get_bus_effect(bus_idx, i) is AudioEffectCapture:
			_capture = AudioServer.get_bus_effect(bus_idx, i)
			break
	if _capture == null:
		_capture = AudioEffectCapture.new()
		AudioServer.add_bus_effect(bus_idx, _capture)
	AudioServer.set_bus_mute(bus_idx, true)  # capture without monitoring feedback
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = capture_bus_name
	add_child(_mic_player)


# ------------------------------------------------------------- transcription

func transcribe_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		transcription_failed.emit("file not found: " + path)
		return
	transcribe_wav_bytes(FileAccess.get_file_as_bytes(path))


func transcribe_wav_bytes(wav_bytes: PackedByteArray) -> void:
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		transcription_failed.emit("transcription already in progress")
		return
	var headers := PackedStringArray(["Content-Type: audio/wav"])
	var err := _http.request_raw(server_url + "/transcribe", headers, HTTPClient.METHOD_POST, wav_bytes)
	if err != OK:
		transcription_failed.emit("HTTP request failed to start: %s" % err)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		transcription_failed.emit("backend error (result=%d, code=%d)" % [result, response_code])
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		transcription_failed.emit("invalid backend response")
		return
	var info: Dictionary = parsed
	var text: String = str(info.get("text", ""))
	transcription_received.emit(text, info)
	var normalized := _normalize(text)
	for phrase: String in _commands:
		if normalized.contains(phrase):
			command_recognized.emit(str(_commands[phrase]), text)


# ------------------------------------------------------------------ helpers

static func _normalize(text: String) -> String:
	var t := text.to_lower()
	var out := ""
	for ch in t:
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == " " or (ch.unicode_at(0) > 127):
			out += ch
	return " ".join(out.split(" ", false))


static func _to_mono_16k(stereo: PackedVector2Array, src_rate: int) -> PackedFloat32Array:
	var mono := PackedFloat32Array()
	mono.resize(stereo.size())
	for i in stereo.size():
		mono[i] = (stereo[i].x + stereo[i].y) * 0.5
	if src_rate == TARGET_SAMPLE_RATE:
		return mono
	# Linear-interpolation resample (good enough for short voice commands).
	var ratio := float(src_rate) / float(TARGET_SAMPLE_RATE)
	var out_len := int(mono.size() / ratio)
	var out := PackedFloat32Array()
	out.resize(out_len)
	for i in out_len:
		var pos := i * ratio
		var idx := int(pos)
		var frac := pos - idx
		var a := mono[idx]
		var b := mono[min(idx + 1, mono.size() - 1)]
		out[i] = a + (b - a) * frac
	return out


static func _encode_wav_16bit(samples: PackedFloat32Array, sample_rate: int) -> PackedByteArray:
	var peer := StreamPeerBuffer.new()
	var data_size := samples.size() * 2
	peer.put_data("RIFF".to_ascii_buffer())
	peer.put_u32(36 + data_size)
	peer.put_data("WAVE".to_ascii_buffer())
	peer.put_data("fmt ".to_ascii_buffer())
	peer.put_u32(16)
	peer.put_u16(1)  # PCM
	peer.put_u16(1)  # mono
	peer.put_u32(sample_rate)
	peer.put_u32(sample_rate * 2)
	peer.put_u16(2)
	peer.put_u16(16)
	peer.put_data("data".to_ascii_buffer())
	peer.put_u32(data_size)
	for s in samples:
		peer.put_16(int(clampf(s, -1.0, 1.0) * 32767.0))
	return peer.data_array
