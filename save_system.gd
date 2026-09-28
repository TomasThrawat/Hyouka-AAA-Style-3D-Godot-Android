extends Node

const SAVE_PATH := "user://neon_frontier_save.cfg"

var stage := 1
var score := 0
var best_score := 0
var _has_save := false

func _ready() -> void:
	load_state()

func has_save() -> bool:
	return _has_save

func load_state() -> void:
	var config := ConfigFile.new()
	var result := config.load(SAVE_PATH)
	if result != OK:
		stage = 1
		score = 0
		best_score = 0
		_has_save = false
		return
	stage = int(config.get_value("game", "stage", 1))
	score = int(config.get_value("game", "score", 0))
	best_score = int(config.get_value("game", "best_score", 0))
	_has_save = stage > 1 or score > 0

func save_state(stage_value: int, score_value: int, best_value: int) -> void:
	stage = stage_value
	score = score_value
	best_score = best_value
	var config := ConfigFile.new()
	config.set_value("game", "stage", stage)
	config.set_value("game", "score", score)
	config.set_value("game", "best_score", best_score)
	config.set_value("game", "version", 2)
	config.save(SAVE_PATH)
	_has_save = true

func clear_state() -> void:
	DirAccess.remove_absolute(SAVE_PATH)
	_has_save = false
	stage = 1
	score = 0
	best_score = 0
