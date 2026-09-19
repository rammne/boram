extends AudioStreamPlayer

func play_track() -> void:
	# Prevent the track from restarting from 0:00 if it is already active
	if not playing:
		play()

func stop_track() -> void:
	stop()
