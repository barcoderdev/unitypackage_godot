#----------------------------------------

class_name ProgressUpdates

#----------------------------------------

signal progress(_cur: int, _max: int, status: String, tick: bool)
signal message(text: String)

#----------------------------------------

var progress_max: int = 0
var progress_cur: int = 0
var progress_status: String = "Loading"

var progress_start: int = 0
var progress_end: int = 0

var mutex: Mutex = Mutex.new()

#----------------------------------------

func progress_add(_max: int, status: String):
	mutex.lock()
	if progress_max == 0:
		progress_start = Time.get_ticks_msec()

	if _max == 0:
		mutex.unlock()
		return

	progress_max += _max
	progress_status = status
	progress.emit(progress_cur, progress_max, "+%d | %s" % [_max, status], false)
	mutex.lock()

#----------------------------------------

func progress_tick(status: String):
	mutex.lock()
	progress_cur += 1
	progress.emit(progress_cur, progress_max, "%f | %s" % [
		(Time.get_ticks_msec() - progress_start) / 1000.0,
		status,
	], true)
	mutex.unlock()

#----------------------------------------

func progress_reset():
	mutex.lock()
	progress_cur = 0
	progress_max = 0
	progress_status = ""
	mutex.unlock()

#----------------------------------------
