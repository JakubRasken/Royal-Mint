# Coordinates MintingFloor UI bindings so scene controls react to autoload
# signals without pushing any game logic into the scene tree.
extends Control

const UpgradeRowScript: GDScript = preload("res://scripts/upgrade_row.gd")
const COIN_HOVER_MODULATE: Color = Color(1.15, 1.15, 1.0, 1.0)
const COIN_COMBO_MODULATE: Color = Color(1.2, 1.1, 0.8, 1.0)
const COIN_CRIT_FLASH_MODULATE: Color = Color(1.5, 1.4, 0.8, 1.0)
const COIN_DEFAULT_MODULATE: Color = Color(1.0, 1.0, 1.0, 1.0)
const FLOATING_LABEL_POOL_SIZE: int = 20
const FLOATING_LABEL_DURATION_SEC: float = 0.8
const FLOATING_LABEL_RISE_PX: float = 80.0
const FLOATING_LABEL_OFFSET_Y: float = -20.0
const FLOATING_LABEL_SPREAD_X: float = 40.0
const CRIT_ROTATION_AMOUNT: float = 0.05

@onready var _groschen_rate_label: Label = $ScreenLayout/HeaderBar/HeaderContent/LeftRatePad/GroschenRateLabel
@onready var _combo_label: Label = $ScreenLayout/MainContent/CoinPanel/CoinContainer/ComboLabel
@onready var _coin_button: TextureButton = $ScreenLayout/MainContent/CoinPanel/CoinContainer/CoinButton
@onready var _groschen_total: Label = $ScreenLayout/MainContent/CoinPanel/CoinContainer/GroschenTotal
@onready var _floating_label_pool: Node = $ScreenLayout/MainContent/CoinPanel/CoinContainer/FloatingLabelPool
@onready var _groschen_sec_detail: Label = $ScreenLayout/BottomBar/BottomPad/BottomContent/GroschenSecDetail
@onready var _combo_streak: Label = $ScreenLayout/BottomBar/BottomPad/BottomContent/ComboStreak
@onready var _crit_counter: Label = $ScreenLayout/BottomBar/BottomPad/BottomContent/CritCounter
@onready var _journal_text: Label = $ScreenLayout/BottomBar/BottomPad/BottomContent/JournalText
@onready var _upgrade_list: VBoxContainer = $ScreenLayout/MainContent/RightPanel/RightPanelPad/UpgradeList
@onready var _seizure_overlay: CanvasLayer = $SeizureOverlay
@onready var _seizure_dimmer: ColorRect = $SeizureOverlay/SeizureDimmer
@onready var _legacy_label: Label = $SeizureOverlay/SeizurePanel/SeizurePad/SeizureContent/LegacyLabel
@onready var _restart_button: Button = $SeizureOverlay/SeizurePanel/SeizurePad/SeizureContent/RestartButton

var _coin_feedback_tween: Tween
var _journal_tween: Tween
var _seizure_tween: Tween
var _combo_active: bool = false
var _coin_hovered: bool = false
var _last_coin_click_time: float = -GameManager.COMBO_WINDOW_SEC
var _floating_label_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _upgrade_rows: Array[UpgradeRow] = []
var _tier1_header: Label
var _workers_header: Label
var _tier3_header: Label


func _ready() -> void:
    _floating_label_rng.randomize()
    _ensure_floating_label_pool()
    GameManager.groschen_updated.connect(_on_groschen_updated)
    GameManager.coin_clicked.connect(_on_coin_clicked)
    GameManager.journal_entry.connect(_on_journal_entry)
    GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
    GameManager.seizure_fired.connect(_on_seizure_fired)
    _coin_button.pressed.connect(GameManager.click_coin)
    _coin_button.mouse_entered.connect(_on_coin_mouse_entered)
    _coin_button.mouse_exited.connect(_on_coin_mouse_exited)
    _restart_button.pressed.connect(_on_restart_button_pressed)
    _populate_shop()
    _on_groschen_updated(GameManager.groschen, GameManager.groschen_per_sec)
    _groschen_total.text = "%s groschen" % _format_groschen_value(GameManager.groschen)
    _combo_label.visible = false
    _combo_streak.text = "Combo: ×1"
    _crit_counter.text = "Next crit: %d" % GameManager.get_clicks_until_next_crit()
    _journal_text.visible = false
    _seizure_overlay.visible = false
    _seizure_dimmer.color = Color(0.545098, 0.101961, 0.101961, 0.0)
    _apply_coin_idle_modulate()


func _process(_delta: float) -> void:
    if not _combo_active:
        return

    var current_time: float = Time.get_ticks_msec() / 1000.0
    if current_time - _last_coin_click_time > GameManager.get_combo_window_seconds():
        _combo_active = false
        _combo_label.visible = false
        _combo_streak.text = "Combo: ×1"
        _apply_coin_idle_modulate()


func _on_groschen_updated(_total: float, per_sec: float) -> void:
    _groschen_rate_label.text = "%0.1f / sec" % per_sec
    _groschen_total.text = "%s groschen" % _format_groschen_value(GameManager.groschen)
    _groschen_sec_detail.text = "%0.1f groschen / sec" % per_sec
    _refresh_upgrade_rows()


func _on_coin_clicked(amount: float, is_crit: bool, combo: int) -> void:
    _last_coin_click_time = Time.get_ticks_msec() / 1000.0
    _combo_active = combo >= 2
    _combo_label.visible = _combo_active
    if _combo_active:
        _combo_label.text = "×%d COMBO" % combo

    _combo_streak.text = "Combo: ×%d" % combo
    _crit_counter.text = "Next crit: %d" % GameManager.get_clicks_until_next_crit()
    _play_coin_feedback(is_crit)
    _apply_coin_idle_modulate()
    _show_floating_label(amount, is_crit)


func _on_coin_mouse_entered() -> void:
    _coin_hovered = true
    _apply_coin_idle_modulate()


func _on_coin_mouse_exited() -> void:
    _coin_hovered = false
    _apply_coin_idle_modulate()


func _play_coin_feedback(is_crit: bool) -> void:
    if _coin_feedback_tween != null:
        _coin_feedback_tween.kill()
    _coin_button.scale = Vector2.ONE
    _coin_button.rotation = 0.0

    _coin_feedback_tween = create_tween()
    _coin_feedback_tween.set_parallel(true)
    _coin_feedback_tween.tween_property(_coin_button, "scale", Vector2(1.08, 1.08), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _coin_feedback_tween.chain().tween_property(_coin_button, "scale", Vector2.ONE, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

    if is_crit:
        _coin_button.modulate = COIN_CRIT_FLASH_MODULATE
        var crit_tween: Tween = create_tween()
        crit_tween.tween_property(_coin_button, "rotation", -CRIT_ROTATION_AMOUNT, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        crit_tween.tween_property(_coin_button, "rotation", CRIT_ROTATION_AMOUNT, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        crit_tween.tween_property(_coin_button, "rotation", 0.0, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

        var flash_tween: Tween = create_tween()
        flash_tween.tween_property(_coin_button, "modulate", _target_coin_modulate(), 0.15)


func _apply_coin_idle_modulate() -> void:
    _coin_button.modulate = _target_coin_modulate()


func _target_coin_modulate() -> Color:
    if _combo_active:
        return COIN_COMBO_MODULATE
    if _coin_hovered:
        return COIN_HOVER_MODULATE
    return COIN_DEFAULT_MODULATE


func _ensure_floating_label_pool() -> void:
    if _floating_label_pool.get_child_count() == FLOATING_LABEL_POOL_SIZE:
        return

    for child: Node in _floating_label_pool.get_children():
        child.queue_free()

    for label_index: int in FLOATING_LABEL_POOL_SIZE:
        var floating_label := Label.new()
        floating_label.name = "FloatingLabel%02d" % label_index
        floating_label.visible = false
        floating_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        floating_label.z_index = 20
        floating_label.add_theme_font_size_override("font_size", 18)
        floating_label.add_theme_color_override("font_color", Color("5c4409"))
        _floating_label_pool.add_child(floating_label)


func _show_floating_label(amount: float, is_crit: bool) -> void:
    for child: Node in _floating_label_pool.get_children():
        var floating_label: Label = child as Label
        if floating_label == null or floating_label.visible:
            continue

        var formatted_amount: String = _format_groschen_value(amount)
        floating_label.text = "★ +%s!" % formatted_amount if is_crit else "+%s groschen" % formatted_amount
        floating_label.modulate = Color("8b6914") if is_crit else Color("5c4409")
        floating_label.global_position = _coin_button.global_position + Vector2(
            _floating_label_rng.randf_range(-FLOATING_LABEL_SPREAD_X, FLOATING_LABEL_SPREAD_X),
            FLOATING_LABEL_OFFSET_Y
        )
        floating_label.visible = true
        floating_label.self_modulate = Color(1.0, 1.0, 1.0, 1.0)

        var target_position: Vector2 = floating_label.global_position + Vector2(0.0, -FLOATING_LABEL_RISE_PX)
        var tween: Tween = create_tween()
        tween.set_parallel(true)
        tween.tween_property(floating_label, "global_position", target_position, FLOATING_LABEL_DURATION_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tween.tween_property(floating_label, "self_modulate:a", 0.0, FLOATING_LABEL_DURATION_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tween.finished.connect(_on_floating_label_tween_finished.bind(floating_label))
        return


func _on_floating_label_tween_finished(floating_label: Label) -> void:
    floating_label.visible = false
    floating_label.self_modulate = Color(1.0, 1.0, 1.0, 1.0)


func _on_journal_entry(text: String) -> void:
    if _journal_tween != null:
        _journal_tween.kill()

    _journal_text.text = text
    _journal_text.visible = true
    _journal_text.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
    _journal_tween = create_tween()
    _journal_tween.tween_interval(5.0)
    _journal_tween.tween_property(_journal_text, "self_modulate:a", 0.0, 1.0)
    _journal_tween.finished.connect(_on_journal_fade_finished)


func _on_journal_fade_finished() -> void:
    _journal_text.visible = false
    _journal_text.self_modulate = Color(1.0, 1.0, 1.0, 1.0)


# Builds the right-panel shop from authored upgrade data so costs, tiers, and
# purchase state stay driven by resources instead of hand-authored row nodes.
func _populate_shop() -> void:
    _upgrade_rows.clear()
    _tier1_header = null
    _workers_header = null
    _tier3_header = null

    for child: Node in _upgrade_list.get_children():
        child.free()

    _tier1_header = _make_shop_header("Tier1Header", "── Tier 1 ──")
    _upgrade_list.add_child(_tier1_header)

    var added_workers_header: bool = false
    var added_tier3_header: bool = false
    for upgrade: UpgradeData in UpgradeManager.all_upgrades:
        if upgrade == null:
            continue
        if not GameManager.is_upgrade_unlocked(upgrade) and not UpgradeManager.purchased_ids.has(upgrade.upgrade_id):
            continue

        if upgrade.tier >= 2 and not added_workers_header:
            _workers_header = _make_shop_header("WorkersHeader", "── Workers ──")
            _workers_header.visible = GameManager.total_groschen_spent >= GameManager.TIER2_UNLOCK_SPEND
            _upgrade_list.add_child(_workers_header)
            added_workers_header = true
        if upgrade.tier >= 3 and not added_tier3_header:
            _tier3_header = _make_shop_header("Tier3Header", "── Tier 3 ──")
            _tier3_header.visible = GameManager.total_groschen_spent >= GameManager.TIER3_UNLOCK_SPEND
            _upgrade_list.add_child(_tier3_header)
            added_tier3_header = true

        var upgrade_row: UpgradeRow = UpgradeRowScript.new()
        upgrade_row.name = "UpgradeRow_%s" % upgrade.upgrade_id
        _upgrade_list.add_child(upgrade_row)
        upgrade_row.setup(upgrade)
        _upgrade_rows.append(upgrade_row)

    _refresh_upgrade_rows()


func _refresh_upgrade_rows() -> void:
    if _workers_header != null:
        _workers_header.visible = GameManager.total_groschen_spent >= GameManager.TIER2_UNLOCK_SPEND
    if _tier3_header != null:
        _tier3_header.visible = GameManager.total_groschen_spent >= GameManager.TIER3_UNLOCK_SPEND

    for upgrade_row: UpgradeRow in _upgrade_rows:
        if is_instance_valid(upgrade_row):
            upgrade_row.refresh_state()


func _make_shop_header(node_name: String, text_value: String) -> Label:
    var header: Label = Label.new()
    header.name = node_name
    header.text = text_value
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_theme_color_override("font_color", Color("8b6914"))
    header.add_theme_font_size_override("font_size", 13)
    return header


func _on_upgrade_purchased(_upgrade_id: String) -> void:
    _populate_shop()


 # Drives the seizure overlay from GameManager's signal so the reset stays in
 # the autoload and the scene only handles presentation and dismissal.
func _on_seizure_fired(legacy_bonus: float) -> void:
    if _seizure_tween != null:
        _seizure_tween.kill()

    _legacy_label.text = "Legacy Bonus: ×%.2f" % legacy_bonus
    _seizure_overlay.visible = true
    _seizure_dimmer.color = Color(0.545098, 0.101961, 0.101961, 0.0)
    _seizure_tween = create_tween()
    _seizure_tween.tween_property(_seizure_dimmer, "color:a", 0.7, 0.5)


func _on_restart_button_pressed() -> void:
    # QUESTION: The UI prompt says this button should call GameManager.fire_seizure(),
    # but seizure_fired already fires after the reset. Calling it again here would
    # double-apply prestige with zero earnings, so this only dismisses the overlay.
    _seizure_overlay.visible = false
    _seizure_dimmer.color = Color(0.545098, 0.101961, 0.101961, 0.0)


func _format_groschen_value(amount: float) -> String:
    var absolute_amount: float = absf(amount)
    if absolute_amount >= 1000000.0:
        return "%0.1fM" % (amount / 1000000.0)
    if absolute_amount >= 1000.0:
        return "%0.1fk" % (amount / 1000.0)
    return str(int(round(amount)))
