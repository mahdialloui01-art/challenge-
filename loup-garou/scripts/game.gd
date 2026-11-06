extends Control

const ROLE_DATA := {
	"werewolf": {"ar": "مستذئب", "fr": "Loup-garou", "en": "Werewolf", "team": "wolves"},
	"seer": {"ar": "العرافة", "fr": "Voyante", "en": "Seer", "team": "village"},
	"witch": {"ar": "الساحرة", "fr": "Sorcière", "en": "Witch", "team": "village"},
	"hunter": {"ar": "الصياد", "fr": "Chasseur", "en": "Hunter", "team": "village"},
	"guard": {"ar": "الحارس", "fr": "Garde", "en": "Guard", "team": "village"},
	"villager": {"ar": "قروي", "fr": "Villageois", "en": "Villager", "team": "village"}
}

var players: Array[Dictionary] = []
var language := "ar"
var phase := "lobby"
var round_number := 0
var selected_player := -1
var log_lines: Array[String] = []

var root_box: VBoxContainer
var status_label: Label
var log_label: Label
var action_box: VBoxContainer

func _ready() -> void:
	_build_shell()
	_show_lobby()

func _build_shell() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#101522")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	root_box = VBoxContainer.new()
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", 14)
	root_box.add_theme_constant_override("margin_left", 24)
	root_box.add_theme_constant_override("margin_right", 24)
	root_box.add_theme_constant_override("margin_top", 28)
	root_box.add_theme_constant_override("margin_bottom", 24)
	add_child(root_box)

	var header := HBoxContainer.new()
	root_box.add_child(header)
	var title := Label.new()
	title.text = "🌙  LOUP GAROU"
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var lang := OptionButton.new()
	lang.add_item("العربية", 0)
	lang.add_item("Français", 1)
	lang.add_item("English", 2)
	lang.item_selected.connect(_change_language)
	header.add_child(lang)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(scroll)
	log_label = Label.new()
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_font_size_override("font_size", 18)
	scroll.add_child(log_label)

	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 10)
	root_box.add_child(action_box)

func _change_language(index: int) -> void:
	language = ["ar", "fr", "en"][index]
	if phase == "lobby":
		_show_lobby()
	else:
		_refresh()

func _tr(ar: String, fr: String, en: String) -> String:
	match language:
		"fr": return fr
		"en": return en
		_: return ar

func _button(caption: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(callback)
	action_box.add_child(b)

func _clear_actions() -> void:
	for child in action_box.get_children():
		child.queue_free()

func _show_lobby() -> void:
	phase = "lobby"
	status_label.text = _tr("قرية غامضة تنتظر شجاعتك", "Un village mystérieux vous attend", "A mysterious village awaits you")
	log_label.text = _tr("العب محلياً دون إنترنت ضد شخصيات ذكية. النسخة الأولى تركز على قواعد اللعب الأساسية.", "Jouez hors ligne contre des personnages IA. Cette première version pose les bases du jeu.", "Play offline against AI characters. This first build establishes the core game.")
	_clear_actions()
	_button(_tr("ابدأ مباراة أوفلاين • 6 لاعبين", "Lancer une partie hors ligne • 6 joueurs", "Start offline match • 6 players"), _start_offline)

func _start_offline() -> void:
	players.clear()
	var roles := ["werewolf", "seer", "witch", "hunter", "villager", "villager"]
	roles.shuffle()
	for i in range(6):
		players.append({
			"name": _tr("أنت", "Vous", "You") if i == 0 else _tr("لاعب", "Joueur", "Player") + " " + str(i + 1),
			"role": roles[i],
			"alive": true,
			"human": i == 0
		})
	round_number = 1
	log_lines.clear()
	log_lines.append(_tr("بدأت المباراة. دورك السري: ", "La partie commence. Votre rôle secret : ", "The match begins. Your secret role: ") + _role_name(players[0].role))
	_begin_night()

func _role_name(role: String) -> String:
	var data: Dictionary = ROLE_DATA[role]
	return str(data[language])

func _begin_night() -> void:
	phase = "night"
	selected_player = -1
	_refresh()
	_clear_actions()
	status_label.text = "🌑 " + _tr("الليل حلّ على القرية", "La nuit tombe sur le village", "Night falls over the village")
	if players[0].role == "werewolf":
		_button(_tr("اختر ضحية", "Choisir une victime", "Choose a victim"), _show_night_targets)
	elif players[0].role == "seer":
		_button(_tr("اكشف هوية لاعب", "Découvrir un joueur", "Inspect a player"), _show_seer_targets)
	else:
		_button(_tr("انتظر طلوع النهار", "Attendre le lever du jour", "Wait for sunrise"), _resolve_night)

func _show_night_targets() -> void:
	_clear_actions()
	for i in range(1, players.size()):
		if players[i].alive:
			_button(str(players[i].name), func(): _choose_wolf_target(i))

func _choose_wolf_target(index: int) -> void:
	selected_player = index
	_resolve_night()

func _show_seer_targets() -> void:
	_clear_actions()
	for i in range(1, players.size()):
		if players[i].alive:
			_button(str(players[i].name), func(): _seer_check(i))

func _seer_check(index: int) -> void:
	var result := _tr("من فريق الذئاب", "fait partie des loups", "is on the wolf team") if players[index].role == "werewolf" else _tr("من أهل القرية", "fait partie du village", "belongs to the village")
	log_lines.append(str(players[index].name) + " " + result)
	_resolve_night()

func _resolve_night() -> void:
	if selected_player < 0:
		var candidates: Array[int] = []
		for i in range(1, players.size()):
			if players[i].alive:
				candidates.append(i)
		if not candidates.is_empty():
			selected_player = candidates[randi() % candidates.size()]
	if selected_player >= 0:
		players[selected_player].alive = false
		log_lines.append("☠ " + str(players[selected_player].name) + " " + _tr("خرج من اللعبة ليلاً", "a été éliminé cette nuit", "was eliminated during the night"))
	_begin_day()

func _begin_day() -> void:
	phase = "day"
	_refresh()
	_clear_actions()
	status_label.text = "☀️ " + _tr("الصباح — ناقشوا وصوّتوا", "Le jour — débattez et votez", "Day — discuss and vote")
	_button(_tr("ابدأ التصويت", "Lancer le vote", "Start voting"), _show_vote_targets)

func _show_vote_targets() -> void:
	_clear_actions()
	for i in range(players.size()):
		if i != 0 and players[i].alive:
			_button(_tr("صوّت ضد ", "Voter contre ", "Vote against ") + str(players[i].name), func(): _cast_vote(i))

func _cast_vote(target: int) -> void:
	players[target].alive = false
	log_lines.append("⚖ " + str(players[target].name) + " " + _tr("طُرد بالتصويت", "a été éliminé par vote", "was voted out"))
	if _check_winner():
		return
	round_number += 1
	_begin_night()

func _check_winner() -> bool:
	var wolves := 0
	var villagers := 0
	for p in players:
		if p.alive:
			if p.role == "werewolf":
				wolves += 1
			else:
				villagers += 1
	if wolves == 0:
		phase = "finished"
		status_label.text = "🏆 " + _tr("فاز أهل القرية!", "Le village a gagné !", "The village wins!")
	elif wolves >= villagers:
		phase = "finished"
		status_label.text = "🐺 " + _tr("فاز المستذئبون!", "Les loups ont gagné !", "The werewolves win!")
	else:
		return false
	_refresh()
	_clear_actions()
	_button(_tr("العودة للقائمة", "Retour au menu", "Back to menu"), _show_lobby)
	return true

func _refresh() -> void:
	var lines := log_lines.duplicate()
	lines.append("")
	lines.append(_tr("اللاعبون الأحياء:", "Joueurs en vie :", "Players alive:"))
	for p in players:
		if p.alive:
			lines.append("• " + str(p.name) + ("  ★" if p.human else ""))
	log_label.text = "\n".join(lines)
