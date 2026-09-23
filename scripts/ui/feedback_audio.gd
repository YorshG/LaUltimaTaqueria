extends AudioStreamPlayer

const SAMPLE_RATE := 22050
const MAX_PENDING := 4
# Frequency (Hz), duration (s). PCM exists only in memory, never in asset files.
const TONES := {
	"selection": [[440.0, 0.045]],
	"chain_valid": [[660.0, 0.06], [880.0, 0.06]],
	"dish_created": [[520.0, 0.045], [650.0, 0.045]],
	"dish_served": [[1000.0, 0.055]],
	"satisfied": [[660.0, 0.07], [830.0, 0.07], [990.0, 0.09]],
	"breach": [[220.0, 0.09], [140.0, 0.11]],
	"low_reputation": [[330.0, 0.08], [330.0, 0.08]],
	"upgrade": [[740.0, 0.06], [1110.0, 0.09]],
	"boss_phase_2": [[260.0, 0.08], [390.0, 0.08]],
	"boss_phase_3": [[260.0, 0.06], [390.0, 0.06], [520.0, 0.08]],
	"victory": [[523.0, 0.09], [659.0, 0.09], [784.0, 0.16]],
	"defeat": [[294.0, 0.10], [220.0, 0.10], [147.0, 0.16]],
}

# Internal playback seam for headless/silent operation, not a settings feature.
var playback_enabled := true:
	set(value):
		playback_enabled = value
		if not value:
			stop()
			_pending.clear()
			_current_id = ""

var _pending: Array[String] = []
var _current_id := ""
var _terminal := false
var _streams: Dictionary = {}


func _ready() -> void:
	# Keep only feedback audio alive after Main disables gameplay on defeat.
	process_mode = Node.PROCESS_MODE_ALWAYS
	max_polyphony = 1
	volume_db = -14.0
	playback_enabled = playback_enabled and DisplayServer.get_name() != "headless"
	finished.connect(_on_finished)


func request(payload: Dictionary) -> void:
	var cue := str(payload.get("sound_id", ""))
	if not playback_enabled or _terminal or not TONES.has(cue):
		return
	if payload.get("terminal", false):
		_terminal = true
		_pending.clear()
		stop()
		_play_cue(cue)
	elif cue == _current_id or cue in _pending:
		return
	elif _current_id.is_empty():
		_play_cue(cue)
	else:
		if _pending.size() == MAX_PENDING:
			_pending.pop_front()
		_pending.append(cue)


func _on_finished() -> void:
	_current_id = ""
	if not _pending.is_empty():
		_play_cue(_pending.pop_front())


func _play_cue(cue: String) -> void:
	_current_id = cue
	if not _streams.has(cue):
		_streams[cue] = synthesize(cue)
	stream = _streams[cue]
	play()


static func synthesize(cue: String) -> AudioStreamWAV:
	if not TONES.has(cue):
		return null
	var pcm := PackedByteArray()
	for note in TONES[cue]:
		var frequency := float(note[0])
		var count := int(float(note[1]) * SAMPLE_RATE)
		var start := pcm.size()
		var gap := int(0.01 * SAMPLE_RATE)
		pcm.resize(start + (count + gap) * 2)
		for index in range(count):
			var seconds := float(index) / SAMPLE_RATE
			var envelope := minf(1.0, minf(seconds / 0.005, float(count - 1 - index) / SAMPLE_RATE / 0.008))
			var sample := int(sin(TAU * frequency * seconds) * envelope * 24000.0)
			pcm.encode_u16(start + index * 2, sample & 0xffff)
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = SAMPLE_RATE
	result.stereo = false
	result.data = pcm
	return result
