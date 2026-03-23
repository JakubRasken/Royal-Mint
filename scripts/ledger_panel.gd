# Coordinates the ledger sidebar so it reflects the current day, quota, and
# balance using the Ledger and GameManager autoload state.
extends PanelContainer

const FINAL_AUDIT_DAY: int = 14
const BANNER_TEXT_COLOR: Color = Color("fdf6e3")
const QUOTA_MET_COLOR: Color = Color("2a5a2a")
const QUOTA_UNMET_COLOR: Color = Color("8b1a1a")
const BANNER_BORDER_COLOR: Color = Color("5c4409")
const GRACE_NOTCH_REMAINING_COLOR: Color = Color("fdf6e3")
const GRACE_NOTCH_USED_COLOR: Color = Color("8b1a1a")

@onready var _quota_label: Label = $"VBoxContainer/QuotaSection/QuotaLabel"
@onready var _quota_bar: ProgressBar = $"VBoxContainer/QuotaSection/QuotaBar"
@onready var _quota_status_banner: PanelContainer = $"VBoxContainer/QuotaSection/QuotaStatusBanner"
@onready var _quota_status_label: Label = $"VBoxContainer/QuotaSection/QuotaStatusBanner/BannerContent/QuotaStatusLabel"
@onready var _grace_notches: HBoxContainer = $"VBoxContainer/QuotaSection/QuotaStatusBanner/BannerContent/GraceNotches"
@onready var _grace_notch_rects: Array[ColorRect] = [
    $"VBoxContainer/QuotaSection/QuotaStatusBanner/BannerContent/GraceNotches/GraceNotch1",
    $"VBoxContainer/QuotaSection/QuotaStatusBanner/BannerContent/GraceNotches/GraceNotch2",
    $"VBoxContainer/QuotaSection/QuotaStatusBanner/BannerContent/GraceNotches/GraceNotch3"
]
@onready var _balance_value: Label = $"VBoxContainer/StatsGrid/BalanceValue"
@onready var _days_value: Label = $"VBoxContainer/StatsGrid/DaysValue"


func _ready() -> void:
    Ledger.quota_updated.connect(_on_quota_updated)
    Ledger.balance_changed.connect(_on_balance_changed)
    GameManager.day_started.connect(_on_day_started)
    _refresh_from_state()


func _on_quota_updated(current: int, target: int) -> void:
    var quota_met: bool = current >= target and target > 0
    var quota_failure_streak: int = Ledger.get_consecutive_quota_failures()
    var show_grace_countdown: bool = not quota_met and quota_failure_streak >= 2
    _quota_label.text = "Daily quota: %d / %d groschen" % [current, target]
    _quota_bar.max_value = maxi(target, 1)
    _quota_bar.value = clampi(current, 0, target)
    if quota_met:
        _quota_status_label.text = "Quota met"
    elif show_grace_countdown:
        _quota_status_label.text = "Quota unmet - Day %d of grace remaining" % Ledger.get_quota_grace_remaining()
    else:
        _quota_status_label.text = "Quota unmet"
    _quota_status_label.modulate = Color(1, 1, 1, 1)
    _quota_status_label.add_theme_color_override("font_color", BANNER_TEXT_COLOR)
    _quota_status_banner.add_theme_stylebox_override("panel", _build_banner_stylebox(quota_met))
    _update_grace_notches(show_grace_countdown, quota_failure_streak)


func _on_balance_changed(amount: int) -> void:
    _balance_value.text = "%d groschen" % amount


func _on_day_started(day_num: int) -> void:
    _days_value.text = str(maxi(FINAL_AUDIT_DAY - day_num + 1, 0))


func _refresh_from_state() -> void:
    var snapshot: Dictionary = Ledger.get_audit_snapshot()
    _on_quota_updated(int(snapshot["daily_output"]), int(snapshot["daily_target"]))
    _on_balance_changed(int(snapshot["balance"]))
    _days_value.text = str(maxi(FINAL_AUDIT_DAY - GameManager.current_day + 1, 0))


func _build_banner_stylebox(quota_met: bool) -> StyleBoxFlat:
    var stylebox := StyleBoxFlat.new()
    stylebox.bg_color = QUOTA_MET_COLOR if quota_met else QUOTA_UNMET_COLOR
    stylebox.border_color = BANNER_BORDER_COLOR
    stylebox.border_width_left = 2
    stylebox.border_width_top = 2
    stylebox.border_width_right = 2
    stylebox.border_width_bottom = 2
    stylebox.content_margin_left = 8.0
    stylebox.content_margin_top = 6.0
    stylebox.content_margin_right = 8.0
    stylebox.content_margin_bottom = 6.0
    stylebox.shadow_color = Color("2a1a02", 0.25)
    stylebox.shadow_size = 1
    return stylebox


func _update_grace_notches(show_grace_countdown: bool, quota_failure_streak: int) -> void:
    _grace_notches.visible = show_grace_countdown
    if not show_grace_countdown:
        return

    for notch_index: int in _grace_notch_rects.size():
        var notch: ColorRect = _grace_notch_rects[notch_index]
        notch.color = GRACE_NOTCH_USED_COLOR if notch_index < quota_failure_streak else GRACE_NOTCH_REMAINING_COLOR
