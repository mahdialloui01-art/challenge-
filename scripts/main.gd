extends Node3D

const QUESTIONS_PATH := "res://data/questions.json"
const SAVE_PATH := "user://player_data.cfg"

var questions: Array = []
var question_order: Array[int] = []
var question_index := 0
var score := 0
var answered := false
var showing_results := false
var difficulty := "medium"
var vibration_enabled := true
var explanations_enabled := true
var best_score := 0
var games_played := 0

var content: VBoxContainer
var footer_label: Label
var progress_label: Label
var score_label: Label
var question_label: Label
var category_label: Label
var feedback_label: Label
var next_button: Button

const DIFFICULTIES := {
    "easy": {"name": "سهل", "count": 5, "description": "5 أسئلة — بداية ممتعة"},
    "medium": {"name": "متوسط", "count": 10, "description": "10 أسئلة — تحدٍّ متوازن"},
    "hard": {"name": "صعب", "count": 20, "description": "كل الأسئلة — للمحترفين"}
}

func _ready() -> void:
    _build_3d_world()
    _load_questions()
    _load_player_data()
    _build_interface()
    _show_main_menu()

func _build_3d_world() -> void:
    var camera := Camera3D.new()
    camera.position = Vector3(0, 0, 9)
    camera.current = true
    add_child(camera)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-35, -25, 0)
    light.light_energy = 1.4
    add_child(light)

    var colors := [
        Color(0.20, 0.75, 1.0), Color(0.55, 0.35, 1.0),
        Color(0.10, 0.95, 0.75), Color(1.0, 0.65, 0.25)
    ]
    for i in range(12):
        var orb := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.28 if i % 3 == 0 else 0.16
        sphere.height = sphere.radius * 2.0
        orb.mesh = sphere
        var material := StandardMaterial3D.new()
        material.albedo_color = colors[i % colors.size()]
        material.emission_enabled = true
        material.emission = colors[i % colors.size()] * 0.45
        orb.material_override = material
        var angle := TAU * float(i) / 12.0
        orb.position = Vector3(cos(angle) * 4.5, sin(angle * 1.7) * 3.0, -1.5)
        add_child(orb)

    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 2.7
    torus.outer_radius = 2.78
    ring.mesh = torus
    ring.position = Vector3(0, 0, -2.0)
    ring.rotation_degrees = Vector3(22, 0, 12)
    var ring_material := StandardMaterial3D.new()
    ring_material.albedo_color = Color(0.25, 0.45, 1.0, 0.45)
    ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ring.material_override = ring_material
    add_child(ring)

func _load_questions() -> void:
    if not FileAccess.file_exists(QUESTIONS_PATH):
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(QUESTIONS_PATH))
    if parsed is Dictionary and parsed.has("questions"):
        questions = parsed["questions"]

func _load_player_data() -> void:
    var config := ConfigFile.new()
    if config.load(SAVE_PATH) == OK:
        best_score = int(config.get_value("stats", "best_score", 0))
        games_played = int(config.get_value("stats", "games_played", 0))
        difficulty = str(config.get_value("settings", "difficulty", "medium"))
        vibration_enabled = bool(config.get_value("settings", "vibration", true))
        explanations_enabled = bool(config.get_value("settings", "explanations", true))
    if not DIFFICULTIES.has(difficulty):
        difficulty = "medium"

func _save_player_data() -> void:
    var config := ConfigFile.new()
    config.set_value("stats", "best_score", best_score)
    config.set_value("stats", "games_played", games_played)
    config.set_value("settings", "difficulty", difficulty)
    config.set_value("settings", "vibration", vibration_enabled)
    config.set_value("settings", "explanations", explanations_enabled)
    config.save(SAVE_PATH)

func _build_interface() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.layout_direction = Control.LAYOUT_DIRECTION_RTL
    layer.add_child(root)

    var tint := ColorRect.new()
    tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    tint.color = Color(0.025, 0.035, 0.10, 0.84)
    root.add_child(tint)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 30)
    margin.add_theme_constant_override("margin_right", 30)
    margin.add_theme_constant_override("margin_top", 38)
    margin.add_theme_constant_override("margin_bottom", 28)
    root.add_child(margin)

    var page := VBoxContainer.new()
    page.add_theme_constant_override("separation", 14)
    margin.add_child(page)

    var brand := Label.new()
    brand.text = "✦ تَحَدّي العَباقِرَة ✦"
    brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    brand.add_theme_font_size_override("font_size", 34)
    brand.add_theme_color_override("font_color", Color(0.93, 0.96, 1.0))
    page.add_child(brand)

    var tagline := Label.new()
    tagline.text = "فكّر بذكاء… وتفوّق!"
    tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tagline.add_theme_font_size_override("font_size", 17)
    tagline.add_theme_color_override("font_color", Color(0.48, 0.78, 1.0))
    page.add_child(tagline)

    var separator := HSeparator.new()
    separator.add_theme_color_override("color", Color(0.25, 0.43, 0.75, 0.65))
    page.add_child(separator)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    page.add_child(scroll)

    content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 16)
    scroll.add_child(content)

    footer_label = Label.new()
    footer_label.text = "◆ تعمل دون إنترنت  •  استمتع بالتحدّي ◆"
    footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer_label.add_theme_font_size_override("font_size", 14)
    footer_label.add_theme_color_override("font_color", Color(0.58, 0.68, 0.88))
    page.add_child(footer_label)

func _clear_content() -> void:
    for child in content.get_children():
        child.queue_free()

func _add_heading(title_text: String, subtitle_text: String = "") -> void:
    var heading := Label.new()
    heading.text = title_text
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 29)
    heading.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
    content.add_child(heading)
    if not subtitle_text.is_empty():
        var subtitle := Label.new()
        subtitle.text = subtitle_text
        subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        subtitle.add_theme_font_size_override("font_size", 17)
        subtitle.add_theme_color_override("font_color", Color(0.64, 0.78, 1.0))
        content.add_child(subtitle)

func _add_stat_card(caption: String, value: String) -> void:
    var card := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.09, 0.15, 0.31, 0.94)
    style.border_color = Color(0.25, 0.43, 0.78, 0.85)
    style.set_border_width_all(1)
    style.set_corner_radius_all(18)
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 14
    style.content_margin_bottom = 14
    card.add_theme_stylebox_override("panel", style)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 5)
    card.add_child(box)
    var value_label := Label.new()
    value_label.text = value
    value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    value_label.add_theme_font_size_override("font_size", 27)
    value_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36))
    box.add_child(value_label)
    var caption_label := Label.new()
    caption_label.text = caption
    caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption_label.add_theme_font_size_override("font_size", 15)
    caption_label.add_theme_color_override("font_color", Color(0.78, 0.85, 1.0))
    box.add_child(caption_label)
    content.add_child(card)

func _show_main_menu() -> void:
    _clear_content()
    _add_heading("مرحباً بك أيها العبقري!", "هل أنت مستعد لاختبار معلوماتك؟")
    _add_stat_card("أفضل نتيجة شخصية", "🏆  %d نقطة" % best_score)
    _add_stat_card("عدد الجولات المكتملة", "🎮  %d" % games_played)

    var play := _make_button("▶   ابدأ التحدّي")
    play.custom_minimum_size.y = 78
    play.pressed.connect(_start_game)
    content.add_child(play)

    var settings_button := _make_button("⚙   الإعدادات")
    settings_button.pressed.connect(_show_settings)
    content.add_child(settings_button)

    var achievements_button := _make_button("★   النجوم والإنجازات")
    achievements_button.pressed.connect(_show_achievements)
    content.add_child(achievements_button)

    var help_button := _make_button("؟   طريقة اللعب")
    help_button.pressed.connect(_show_help)
    content.add_child(help_button)

    var mode: Dictionary = DIFFICULTIES[difficulty]
    var mode_label := Label.new()
    mode_label.text = "المستوى الحالي: %s" % mode["name"]
    mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mode_label.add_theme_font_size_override("font_size", 16)
    mode_label.add_theme_color_override("font_color", Color(0.55, 0.88, 0.78))
    content.add_child(mode_label)

func _show_settings() -> void:
    _clear_content()
    _add_heading("الإعدادات", "اضبط تجربتك كما تحب")
    var difficulty_title := Label.new()
    difficulty_title.text = "مستوى الصعوبة"
    difficulty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    difficulty_title.add_theme_font_size_override("font_size", 21)
    difficulty_title.add_theme_color_override("font_color", Color(0.48, 0.82, 1.0))
    content.add_child(difficulty_title)

    for key in ["easy", "medium", "hard"]:
        var info: Dictionary = DIFFICULTIES[key]
        var marker := " ✓" if difficulty == key else ""
        var button := _make_button("%s%s\n%s" % [info["name"], marker, info["description"]])
        button.custom_minimum_size.y = 76
        button.pressed.connect(func(): _set_difficulty(key))
        content.add_child(button)

    var vibration_button := _make_button("اهتزاز عند الإجابة: %s" % ("مفعّل" if vibration_enabled else "متوقف"))
    vibration_button.pressed.connect(func():
        vibration_enabled = not vibration_enabled
        _save_player_data()
        _show_settings()
    )
    content.add_child(vibration_button)

    var explanation_button := _make_button("إظهار شرح الإجابات: %s" % ("مفعّل" if explanations_enabled else "متوقف"))
    explanation_button.pressed.connect(func():
        explanations_enabled = not explanations_enabled
        _save_player_data()
        _show_settings()
    )
    content.add_child(explanation_button)

    var back := _make_button("→   العودة للرئيسية")
    back.pressed.connect(_show_main_menu)
    content.add_child(back)

func _set_difficulty(value: String) -> void:
    difficulty = value
    _save_player_data()
    _show_settings()

func _show_achievements() -> void:
    _clear_content()
    _add_heading("النجوم والإنجازات", "كل إجابة صحيحة تقرّبك من لقب العبقري")
    _add_stat_card("أفضل نتيجة", "🏆  %d نقطة" % best_score)
    _add_stat_card("الجولات المكتملة", "🎮  %d جولة" % games_played)
    _add_stat_card("بداية الطريق", "⭐  %s" % ("مفتوح" if games_played >= 1 else "مغلق"))
    _add_stat_card("عبقري التحدّي", "🌟  %s" % ("مفتوح" if best_score >= 80 else "احصل على 80 نقطة"))
    _add_stat_card("أسطورة المعرفة", "👑  %s" % ("مفتوح" if best_score >= 100 else "احصل على 100 نقطة"))
    var back := _make_button("→   العودة للرئيسية")
    back.pressed.connect(_show_main_menu)
    content.add_child(back)

func _show_help() -> void:
    _clear_content()
    _add_heading("طريقة اللعب", "أثبت ذكاءك في مجموعة من الأسئلة المتنوعة")
    var rules := Label.new()
    rules.text = "١. اختر مستوى الصعوبة من الإعدادات.\n\n٢. اضغط على الإجابة التي تراها صحيحة.\n\n٣. ستحصل على 10 نقاط عن كل إجابة صحيحة.\n\n٤. اقرأ الشرح لتتعلم معلومة جديدة.\n\n٥. أكمل الأسئلة وحاول تحطيم رقمك القياسي!\n\nاللعبة تعمل بالكامل دون إنترنت، ويتم حفظ أفضل نتيجة وإعداداتك على جهازك."
    rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    rules.add_theme_font_size_override("font_size", 19)
    rules.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
    rules.custom_minimum_size.y = 360
    content.add_child(rules)
    var back := _make_button("→   العودة للرئيسية")
    back.pressed.connect(_show_main_menu)
    content.add_child(back)

func _start_game() -> void:
    if questions.is_empty():
        _clear_content()
        _add_heading("تعذّر بدء اللعبة", "لم نتمكن من تحميل الأسئلة. أعد تشغيل التطبيق.")
        var back_error := _make_button("العودة للرئيسية")
        back_error.pressed.connect(_show_main_menu)
        content.add_child(back_error)
        return

    score = 0
    showing_results = false
    question_index = 0
    question_order.clear()
    for i in range(questions.size()):
        question_order.append(i)
    question_order.shuffle()
    var requested_count: int = int(DIFFICULTIES[difficulty]["count"])
    question_order.resize(mini(requested_count, question_order.size()))
    _display_question()

func _display_question() -> void:
    answered = false
    _clear_content()
    var item: Dictionary = questions[question_order[question_index]]

    category_label = Label.new()
    category_label.text = "✦  %s  ✦" % str(item.get("category", "تحدّي عام"))
    category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    category_label.add_theme_font_size_override("font_size", 20)
    category_label.add_theme_color_override("font_color", Color(0.42, 0.85, 1.0))
    content.add_child(category_label)

    progress_label = Label.new()
    progress_label.text = "السؤال %d / %d" % [question_index + 1, question_order.size()]
    progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    progress_label.add_theme_font_size_override("font_size", 17)
    progress_label.add_theme_color_override("font_color", Color(0.78, 0.84, 1.0))
    content.add_child(progress_label)

    score_label = Label.new()
    score_label.text = "⭐ %d نقطة" % score
    score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    score_label.add_theme_font_size_override("font_size", 18)
    score_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
    content.add_child(score_label)

    question_label = Label.new()
    question_label.text = str(item.get("question", ""))
    question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    question_label.custom_minimum_size.y = 150
    question_label.add_theme_font_size_override("font_size", 26)
    question_label.add_theme_color_override("font_color", Color.WHITE)
    content.add_child(question_label)

    var options: Array = item.get("answers", [])
    for i in range(options.size()):
        var answer_text := str(options[i])
        var answer_button := _make_button(answer_text)
        answer_button.pressed.connect(func(): _select_answer(answer_text))
        content.add_child(answer_button)

    feedback_label = Label.new()
    feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feedback_label.custom_minimum_size.y = 72
    feedback_label.add_theme_font_size_override("font_size", 17)
    feedback_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.75))
    content.add_child(feedback_label)

    next_button = _make_button("السؤال التالي  ←")
    next_button.disabled = true
    next_button.pressed.connect(_next_question)
    content.add_child(next_button)

    var home_button := _make_button("القائمة الرئيسية")
    home_button.pressed.connect(_show_main_menu)
    content.add_child(home_button)

func _select_answer(selected: String) -> void:
    if answered:
        return
    answered = true
    var item: Dictionary = questions[question_order[question_index]]
    var options: Array = item.get("answers", [])
    var correct_index := int(item.get("correct", -1))
    var correct_answer := str(options[correct_index]) if correct_index >= 0 and correct_index < options.size() else ""
    if selected == correct_answer:
        score += 10
        feedback_label.text = "إجابة صحيحة! أحسنت +10 ⭐"
        if explanations_enabled:
            feedback_label.text += "\n" + str(item.get("explanation", ""))
        feedback_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.68))
    else:
        feedback_label.text = "إجابة غير صحيحة. الجواب: " + correct_answer
        if explanations_enabled:
            feedback_label.text += "\n" + str(item.get("explanation", ""))
        feedback_label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.55))
    if vibration_enabled:
        Input.vibrate_handheld(65)
    score_label.text = "⭐ %d نقطة" % score
    next_button.disabled = false
    if question_index == question_order.size() - 1:
        next_button.text = "عرض النتيجة"

func _next_question() -> void:
    if not answered:
        return
    if question_index >= question_order.size() - 1:
        _show_results()
        return
    question_index += 1
    _display_question()

func _show_results() -> void:
    showing_results = true
    games_played += 1
    if score > best_score:
        best_score = score
    _save_player_data()

    _clear_content()
    _add_heading("انتهى التحدّي!", "أحسنت! هذه حصيلتك في هذه الجولة")
    _add_stat_card("نتيجتك", "⭐  %d / %d نقطة" % [score, question_order.size() * 10])
    _add_stat_card("أفضل نتيجة شخصية", "🏆  %d نقطة" % best_score)
    var percent := int(round(float(score) / float(question_order.size() * 10) * 100.0))
    var result_text := Label.new()
    result_text.text = "نسبة الإجابات الصحيحة: %d%%" % percent
    result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_text.add_theme_font_size_override("font_size", 21)
    result_text.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
    content.add_child(result_text)

    var replay := _make_button("↻   العب من جديد")
    replay.pressed.connect(_start_game)
    content.add_child(replay)
    var home := _make_button("⌂   القائمة الرئيسية")
    home.pressed.connect(_show_main_menu)
    content.add_child(home)

func _make_button(caption: String) -> Button:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(0, 64)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_size_override("font_size", 20)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.add_theme_color_override("font_hover_color", Color(0.75, 0.9, 1.0))
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.12, 0.19, 0.38, 0.96)
    normal.border_color = Color(0.27, 0.48, 0.85, 0.9)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(18)
    normal.content_margin_left = 18
    normal.content_margin_right = 18
    normal.content_margin_top = 8
    normal.content_margin_bottom = 8
    button.add_theme_stylebox_override("normal", normal)
    var hover := normal.duplicate()
    hover.bg_color = Color(0.17, 0.28, 0.52, 1.0)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    var disabled_style := normal.duplicate()
    disabled_style.bg_color = Color(0.08, 0.11, 0.20, 0.9)
    button.add_theme_stylebox_override("disabled", disabled_style)
    return button
