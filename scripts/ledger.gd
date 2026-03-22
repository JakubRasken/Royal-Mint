# Implements the ledger autoload for quota and balance tracking so the daily
# economy can be evaluated without any direct dependency on UI scenes.
extends Node

signal quota_updated(current: int, target: int)
signal balance_changed(amount: int)

const QUOTA_DAYS_1_TO_4: int = 20
const QUOTA_DAYS_5_TO_9: int = 30
const QUOTA_DAYS_10_TO_14: int = 40

# QUESTION: The GDD does not define a starting balance or wage values yet, so
# the ledger defaults to zero balance until those numbers are specified.
var _balance: int = 0
var _current_day: int = 0
var _current_quota_target: int = 0
var _current_merchant_output: int = 0
var _cumulative_quota_target: int = 0
var _cumulative_merchant_output: int = 0
var _integrity_flags: Array[String] = []


func reset(starting_balance: int = 0) -> void:
    _balance = starting_balance
    _current_day = 0
    _current_quota_target = 0
    _current_merchant_output = 0
    _cumulative_quota_target = 0
    _cumulative_merchant_output = 0
    _integrity_flags.clear()
    quota_updated.emit(_current_merchant_output, _current_quota_target)
    balance_changed.emit(_balance)


func start_day(day_num: int) -> void:
    _current_day = day_num
    _current_merchant_output = 0
    _current_quota_target = get_quota_target(day_num)
    _cumulative_quota_target += _current_quota_target
    quota_updated.emit(_current_merchant_output, _current_quota_target)


func get_quota_target(day_num: int) -> int:
    if day_num <= 4:
        return QUOTA_DAYS_1_TO_4
    if day_num <= 9:
        return QUOTA_DAYS_5_TO_9
    return QUOTA_DAYS_10_TO_14


func set_daily_output(merchant_grade_count: int) -> void:
    _current_merchant_output = maxi(merchant_grade_count, 0)
    _cumulative_merchant_output += _current_merchant_output
    quota_updated.emit(_current_merchant_output, _current_quota_target)


func add_income(amount: int) -> void:
    _set_balance(_balance + maxi(amount, 0))


func subtract_expense(amount: int) -> void:
    _set_balance(_balance - maxi(amount, 0))


func record_integrity_issue(flag_id: String) -> void:
    if flag_id.is_empty():
        return
    if not _integrity_flags.has(flag_id):
        _integrity_flags.append(flag_id)


func has_clean_ledger() -> bool:
    return _integrity_flags.is_empty()


func get_balance() -> int:
    return _balance


func did_meet_daily_quota() -> bool:
    return _current_merchant_output >= _current_quota_target


func did_meet_cumulative_quota() -> bool:
    return _cumulative_merchant_output >= _cumulative_quota_target


func get_audit_snapshot() -> Dictionary:
    return {
        "day": _current_day,
        "balance": _balance,
        "daily_output": _current_merchant_output,
        "daily_target": _current_quota_target,
        "cumulative_output": _cumulative_merchant_output,
        "cumulative_target": _cumulative_quota_target,
        "ledger_clean": has_clean_ledger(),
        "integrity_flags": _integrity_flags.duplicate()
    }


func _set_balance(new_amount: int) -> void:
    _balance = new_amount
    balance_changed.emit(_balance)
