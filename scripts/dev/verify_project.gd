extends SceneTree

## Headless smoke test: preload key scripts and run main scene briefly.
const REPORT_PATH := "user://VerifyProject.txt"
const RUN_SECONDS := 3.0


func _initialize() -> void:
	var lines: PackedStringArray = []
	var ok := true
	for path in GamePaths.VERIFY_SCRIPTS:
		var script := load(path)
		if script == null:
			lines.append("FAIL load %s" % path)
			ok = false
		else:
			lines.append("OK   load %s" % path)

	if ok:
		var err := change_scene_to_file(GamePaths.MAIN_SCENE)
		if err != OK:
			lines.append("FAIL scene %s err=%s" % [GamePaths.MAIN_SCENE, str(err)])
			ok = false
		else:
			lines.append("OK   scene %s" % GamePaths.MAIN_SCENE)
			call_deferred("_finish_after_run", lines, ok)
			return

	_write_report(lines, ok)
	quit(0 if ok else 1)


func _finish_after_run(lines: PackedStringArray, ok: bool) -> void:
	await create_timer(RUN_SECONDS).timeout
	lines.append("OK   ran %.1fs" % RUN_SECONDS)
	_write_report(lines, ok)
	quit(0 if ok else 1)


func _write_report(lines: PackedStringArray, ok: bool) -> void:
	lines.insert(0, "ok=%s" % str(ok))
	var text := "\n".join(lines) + "\n"
	print(text)
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(text)
