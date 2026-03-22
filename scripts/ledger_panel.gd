# Coordinates the ledger sidebar so it reflects the current day, quota, and
# balance using the Ledger and GameManager autoload state.
extends PanelContainer

const FINAL_AUDIT_DAY: int = 14

@onready var _quota_label: Label = $"VBoxContainer/QuotaSection/QuotaLabel"
@onready var _quota_bar: ProgressBar = $"VBoxContainer/QuotaSection/QuotaBar"
@onready var _quota_status_label: Label = $"VBoxContainer/QuotaSection/QuotaStatusLabel"
@onready var _balance_value: Label = $"VBoxContainer/StatsGrid/BalanceValue"
@onready var _days_value: Label = $"VBoxContainer/StatsGrid/DaysValue"


func _ready() -> void:
    Ledger.quota_updated.connect(_on_quota_updated)
    Ledger.balance_changed.connect(_on_balance_changed)
    GameManager.day_started.connect(_on_day_started)
    _refresh_from_state()


func _on_quota_updated(current: int, target: int) -> void:
    _quota_label.text = "Daily quota: %d / %d groschen" % [current, target]
    _quota_bar.max_value = maxi(target, 1)
    _quota_bar.value = clampi(current, 0, target)
    _quota_status_label.text = "Quota met" if current >= target and target > 0 else "Quota unmet"
    _quota_status_label.modulate = Color(1, 1, 1, 1)
    _quota_status_label.add_theme_color_override(
        "font_color",
        Color("2a5a2a") if current >= target and target > 0 else Color("8b1a1a")
    )


func _on_balance_changed(amount: int) -> void:
    _balance_value.text = "%d groschen" % amount


func _on_day_started(day_num: int) -> void:
    _days_value.text = str(maxi(FINAL_AUDIT_DAY - day_num + 1, 0))


func _refresh_from_state() -> void:
    var snapshot: Dictionary = Ledger.get_audit_snapshot()
    _on_quota_updated(int(snapshot["daily_output"]), int(snapshot["daily_target"]))
    _on_balance_changed(int(snapshot["balance"]))
    _days_value.text = str(maxi(FINAL_AUDIT_DAY - GameManager.current_day + 1, 0))
