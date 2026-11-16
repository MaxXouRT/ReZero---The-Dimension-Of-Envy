extends Node
## Loads every GDScript of the project (with autoloads available) and reports
## parse errors. Usage: godot --headless --path . res://tests/check_scripts.tscn

func _ready() -> void:
	var failed := 0
	var files: Array = []
	_collect("res://scripts", files)
	_collect("res://tests", files)
	for f in files:
		var s = load(f)
		if s == null or (s is GDScript and not s.can_instantiate() and not f.ends_with("check_scripts.gd")):
			print("FAILED: ", f)
			failed += 1
	print("Checked %d scripts, %d failed" % [files.size(), failed])
	get_tree().quit(1 if failed > 0 else 0)

func _collect(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path + "/" + f)
	for sub in d.get_directories():
		_collect(dir_path + "/" + sub, out)
