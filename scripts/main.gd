extends Node3D

const QUESTIONS_PATH := "res://data/questions.json"

var questions: Array = []
var question_order: Array[int] = []
var question_index := 0
var score := 0
var answered := false
var question_label: Label
var category_label: Label
var progress_label: Label
var score_label: Label
var answers_box: VBoxContainer
var feedback_label: Label
var next_button: Button
var start_panel: VBoxContainer

func _ready() -> void:
    _build_3d_world()
    _load_questions()
    _build_interface()
    _show_welcome()

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
    for i in range(9):
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
        var angle := TAU * float(i) / 9.0
        orb.position = Vector3(cos(angle) * 4.2, sin(angle * 1.7) * 2.8, -1.5)
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

func _build_interface() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.layout_direction = Control.LAYOUT_DIRECTION_RTL
    layer.add_child(root)

    var tint := ColorRect.new()
    tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    tint.color = Color(0.025, 0.035, 0.10, 0.78)
    root.add_child(tint)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 34)
    margin.add_theme_constant_override("margin_right", 34)
    margin.add_theme_constant_override("margin_top", 48)
    margin.add_theme_constant_override("margin_bottom", 42)
    root.add_child(margin)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 22)
    margin.add_child(column)

    var header := HBoxContainer.new()
    header.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_child(header)

    var title := Label.new()
    title.text = "تَحَدّي العَباقِرَة"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 38)
    title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
    header.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "اختبر ذكاءك… واصنع إنجازك"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 19)
    subtitle.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
    column.add_child(subtitle)

    var spacer := Control.new()
    spacer.custom_minimum_size.y = 24
    column.add_child(spacer)

    start_panel = VBoxContainer.new()
    start_panel.add_theme_constant_override("separation", 18)
    column.add_child(start_panel)

    category_label = Label.new()
    category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    category_label.add_theme_font_size_override("font_size", 20)
    category_label.add_theme_color_override("font_color", Color(0.42, 0.85, 1.0))
    column.add_child(category_label)

    question_label = Label.new()
    question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    question_label.custom_minimum_size.y = 150
    question_label.add_theme_font_size_override("font_size", 28)
    question_label.add_theme_color_override("font_color", Color.WHITE)
    column.add_child(question_label)

    answers_box = VBoxContainer.new()
    answers_box.add_theme_constant_override("separation", 13)
    column.add_child(answers_box)

    feedback_label = Label.new()
    feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feedback_label.custom_minimum_size.y = 56
    feedback_label.add_theme_font_size_override("font_size", 19)
    feedback_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.75))
    column.add_child(feedback_label)

    var footer := HBoxContainer.new()
    footer.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_child(footer)

    progress_label = Label.new()
    progress_label.add_theme_font_size_override("font_size", 18)
    progress_label.add_theme_color_override("font_color", Color(0.78, 0.84, 1.0))
    footer.add_child(progress_label)

    var gap := Control.new()
    gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    footer.add_child(gap)

    score_label = Label.new()
    score_label.add_theme_font_size_override("font_size", 18)
    score_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
    footer.add_child(score_label)

    next_button = _make_button("السؤال التالي  ←")
    next_button.pressed.connect(_next_question)
    column.add_child(next_button)

func _show_welcome() -> void:
    category_label.text = "مستعد للتحدّي؟"
    question_label.text = "مجموعة أسئلة متنوعة في العلوم والتاريخ والجغرافيا والمنطق"
    feedback_label.text = "اللعبة تعمل دون إنترنت"
    progress_label.text = "10 أسئلة"
    score_label.text = "⭐ 0 نقطة"
    _clear_answers()
    var play := _make_button("ابدأ التحدّي")
    play.pressed.connect(_start_game)
    answers_box.add_child(play)
    next_button.hide()

func _start_game() -> void:
    if questions.is_empty():
        feedback_label.text = "تعذّر تحميل الأسئلة. تحقق من ملف البيانات."
        return
    score = 0
    question_index = 0
    question_order.clear()
    for i in range(questions.size()):
        question_order.append(i)
    question_order.shuffle()
    next_button.show()
    _display_question()

func _display_question() -> void:
    answered = false
    feedback_label.text = ""
    _clear_answers()
    var item: Dictionary = questions[question_order[question_index]]
    category_label.text = "✦ " + str(item.get("category", "تحدّي عام")) + " ✦"
    question_label.text = str(item.get("question", ""))
    progress_label.text = "السؤال %d / %d" % [question_index + 1, question_order.size()]
    score_label.text = "⭐ %d نقطة" % score
    var options: Array = item.get("answers", [])
    for i in range(options.size()):
        var answer_text := str(options[i])
        var answer_button := _make_button(answer_text)
        answer_button.pressed.connect(func(): _select_answer(answer_text))
        answers_box.add_child(answer_button)
    next_button.text = "السؤال التالي  ←"
    next_button.disabled = true

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
        feedback_label.text = "إجابة صحيحة! أحسنت +10 ⭐\n" + str(item.get("explanation", ""))
        feedback_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.68))
    else:
        feedback_label.text = "ليست الإجابة الصحيحة. الجواب: " + correct_answer + "\n" + str(item.get("explanation", ""))
        feedback_label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.55))
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
    _clear_answers()
    category_label.text = "انتهى التحدّي!"
    question_label.text = "نتيجتك: %d من %d نقطة" % [score, question_order.size() * 10]
    feedback_label.text = "رائع! واصل التعلّم وارجع لتحدٍّ جديد."
    progress_label.text = "🏆 إنجاز جديد"
    next_button.text = "العب من جديد"
    next_button.disabled = false
    next_button.pressed.disconnect(_next_question)
    next_button.pressed.connect(_start_game)

func _clear_answers() -> void:
    for child in answers_box.get_children():
        child.queue_free()

func _make_button(caption: String) -> Button:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(0, 68)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_size_override("font_size", 22)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.add_theme_color_override("font_hover_color", Color(0.75, 0.9, 1.0))
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.12, 0.19, 0.38, 0.94)
    normal.border_color = Color(0.27, 0.48, 0.85, 0.9)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(18)
    normal.content_margin_left = 18
    normal.content_margin_right = 18
    button.add_theme_stylebox_override("normal", normal)
    var hover := normal.duplicate()
    hover.bg_color = Color(0.17, 0.28, 0.52, 1.0)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    return button
