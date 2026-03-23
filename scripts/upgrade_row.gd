# Builds a parchment shop row so upgrade availability, purchase state, and cost
# can refresh from data without exposing default Godot button styling.
class_name UpgradeRow
extends PanelContainer

const ROW_AFFORDABLE_BG: Color = Color("fdf6e3")
const ROW_AFFORDABLE_BORDER: Color = Color("8b6914")
const ROW_UNAFFORDABLE_BG: Color = Color("3a2a04")
const ROW_PURCHASED_BG: Color = Color("1a1005")
const BUTTON_AFFORDABLE_BG: Color = Color("f5e6b2")
const BUTTON_AFFORDABLE_TEXT: Color = Color("5c4409")
const BUTTON_UNAFFORDABLE_BG: Color = Color("2a1a02")
const LABEL_DARK_GOLD: Color = Color("5c4409")
const LABEL_GREY: Color = Color("555555")
const LABEL_PURCHASED: Color = Color("8b6914")

var _upgrade: UpgradeData
var _title_label: Label
var _description_label: Label
var _buy_button: Button


func _ready() -> void:
    _build_row()


func setup(upgrade: UpgradeData) -> void:
    _upgrade = upgrade
    if _title_label != null:
        refresh_state()


func refresh_state() -> void:
    if _upgrade == null:
        return

    var is_purchased: bool = UpgradeManager.purchased_ids.has(_upgrade.upgrade_id)
    var is_affordable: bool = UpgradeManager.is_affordable(_upgrade)
    var display_cost: int = int(round(GameManager.get_upgrade_cost(_upgrade)))

    _title_label.text = "%s ✓" % _upgrade.label if is_purchased else _upgrade.label
    _description_label.text = _upgrade.description
    _buy_button.text = "%dg" % display_cost

    if is_purchased:
        add_theme_stylebox_override("panel", _make_panel_style(ROW_PURCHASED_BG, Color(0, 0, 0, 0), 0))
        _title_label.add_theme_color_override("font_color", LABEL_PURCHASED)
        _description_label.add_theme_color_override("font_color", LABEL_PURCHASED)
        _buy_button.visible = false
        return

    _buy_button.visible = true
    _buy_button.disabled = not is_affordable

    if is_affordable:
        add_theme_stylebox_override("panel", _make_panel_style(ROW_AFFORDABLE_BG, ROW_AFFORDABLE_BORDER, 2))
        _title_label.add_theme_color_override("font_color", LABEL_DARK_GOLD)
        _description_label.add_theme_color_override("font_color", LABEL_DARK_GOLD)
        _apply_button_styles(
            _make_button_style(BUTTON_AFFORDABLE_BG, ROW_AFFORDABLE_BORDER, 2),
            _make_button_style(BUTTON_AFFORDABLE_BG.lightened(0.08), ROW_AFFORDABLE_BORDER, 2),
            BUTTON_AFFORDABLE_TEXT
        )
        return

    add_theme_stylebox_override("panel", _make_panel_style(ROW_UNAFFORDABLE_BG, Color(0, 0, 0, 0), 0))
    _title_label.add_theme_color_override("font_color", LABEL_GREY)
    _description_label.add_theme_color_override("font_color", LABEL_GREY)
    _apply_button_styles(
        _make_button_style(BUTTON_UNAFFORDABLE_BG, Color(0, 0, 0, 0), 0),
        _make_button_style(BUTTON_UNAFFORDABLE_BG, Color(0, 0, 0, 0), 0),
        LABEL_GREY
    )


func _build_row() -> void:
    custom_minimum_size = Vector2(0, 56)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    mouse_filter = Control.MOUSE_FILTER_STOP

    var content: HBoxContainer = HBoxContainer.new()
    content.name = "Content"
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 8)
    add_child(content)

    var text_column: VBoxContainer = VBoxContainer.new()
    text_column.name = "TextColumn"
    text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    text_column.add_theme_constant_override("separation", 2)
    content.add_child(text_column)

    _title_label = Label.new()
    _title_label.name = "TitleLabel"
    _title_label.add_theme_font_size_override("font_size", 15)
    text_column.add_child(_title_label)

    _description_label = Label.new()
    _description_label.name = "DescriptionLabel"
    _description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _description_label.add_theme_font_size_override("font_size", 13)
    text_column.add_child(_description_label)

    _buy_button = Button.new()
    _buy_button.name = "BuyButton"
    _buy_button.custom_minimum_size = Vector2(72, 36)
    _buy_button.focus_mode = Control.FOCUS_NONE
    _buy_button.pressed.connect(_on_buy_button_pressed)
    content.add_child(_buy_button)

    refresh_state()


func _on_buy_button_pressed() -> void:
    if _upgrade == null or not UpgradeManager.is_affordable(_upgrade):
        return
    GameManager.purchase_upgrade(_upgrade.upgrade_id)


func _apply_button_styles(base_style: StyleBoxFlat, hover_style: StyleBoxFlat, text_color: Color) -> void:
    _buy_button.add_theme_stylebox_override("normal", base_style)
    _buy_button.add_theme_stylebox_override("pressed", base_style.duplicate())
    _buy_button.add_theme_stylebox_override("focus", base_style.duplicate())
    _buy_button.add_theme_stylebox_override("disabled", base_style.duplicate())
    _buy_button.add_theme_stylebox_override("hover", hover_style)
    _buy_button.add_theme_color_override("font_color", text_color)
    _buy_button.add_theme_color_override("font_hover_color", text_color)
    _buy_button.add_theme_color_override("font_pressed_color", text_color)
    _buy_button.add_theme_color_override("font_disabled_color", text_color)
    _buy_button.add_theme_font_size_override("font_size", 14)


func _make_panel_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.border_width_left = border_width
    style.border_width_top = border_width
    style.border_width_right = border_width
    style.border_width_bottom = border_width
    style.content_margin_left = 8
    style.content_margin_top = 8
    style.content_margin_right = 8
    style.content_margin_bottom = 8
    return style


func _make_button_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.border_width_left = border_width
    style.border_width_top = border_width
    style.border_width_right = border_width
    style.border_width_bottom = border_width
    style.content_margin_left = 8
    style.content_margin_top = 6
    style.content_margin_right = 8
    style.content_margin_bottom = 6
    return style
