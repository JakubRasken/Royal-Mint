# Runs the clicker simulation loop so active clicks, passive income, upgrades,
# worker quirks, and Sigismund threat all stay in one autoloaded game state.
extends Node

signal groschen_updated(total: float, per_sec: float)
signal threat_updated(level: float)
signal coin_clicked(amount: float, is_crit: bool, combo: int)
signal seizure_fired(legacy_bonus: float)
signal worker_hired(worker: Worker)
signal journal_entry(text: String)
signal upgrade_purchased(upgrade_id: String)

const BASE_GROSCHEN_PER_CLICK: float = 1.0
const BASE_GROSCHEN_PER_SEC: float = 0.0
const BASE_LEGACY_MULTIPLIER: float = 1.0
const BASE_ALL_PRODUCTION_MULTIPLIER: float = 1.0
const COMBO_WINDOW_SEC: float = 1.5
const COMBO_UPGRADE_WINDOW_SEC: float = 2.0
const COMBO_MAX: int = 4
const CRIT_INTERVAL: int = 15
const CRIT_UPGRADE_INTERVAL: int = 12
const CRIT_MULTIPLIER: float = 10.0
const CRIT_REINFORCED_MULTIPLIER: float = 20.0
const THREAT_BASE_RATE: float = 0.5
const THREAT_AGENT_THRESHOLD: float = 50.0
const THREAT_PAYOFF_REDUCTION: float = 20.0
const THREAT_REFUSE_INCREASE: float = 15.0
const THREAT_BRIBE_REDUCTION: float = 10.0
const SEIZURE_THRESHOLD: float = 100.0
const TIER2_UNLOCK_SPEND: float = 100.0
const TIER3_UNLOCK_SPEND: float = 1000.0
const LEGACY_EARNINGS_DIVISOR: float = 10000.0
const LEGACY_PER_PRESTIGE_CAP: float = 5.0
const RADEK_BASE_MULTIPLIER: float = 1.3
const RADEK_OTHER_WORKER_BONUS: float = 0.1
const BOZENA_WORKER_MULTIPLIER: float = 1.2
const FULL_FLOOR_MULTIPLIER: float = 2.0
const FULL_FLOOR_WORKER_COUNT: int = 5
const FURNACE_BUFF_MULTIPLIER: float = 2.0
const FURNACE_BUFF_DURATION_SEC: float = 30.0
const FURNACE_FLAME_DURATION_SEC: float = 45.0
const ROYAL_CHARTER_MULTIPLIER: float = 3.0
const ROYAL_CHARTER_DURATION_SEC: float = 60.0
const ROYAL_CHARTER_COOLDOWN_SEC: float = 300.0
const NIGHT_SHIFT_MULTIPLIER: float = 1.5
const SILVER_IMPORT_PASSIVE_ADD: float = 20.0
const VANEK_SKIM_LOSS: float = 5.0
const JIRI_GOOF_DURATION_SEC: float = 5.0
const MILOTA_REST_DURATION_SEC: float = 15.0
const MILOTA_REST_INTERVAL_SEC: float = 90.0
# QUESTION: The clicker GDD defines Jiri/Vanek as "random" but gives no interval.
# These conservative timers are placeholders until explicit numbers are provided.
const JIRI_GOOF_MIN_INTERVAL_SEC: float = 25.0
const JIRI_GOOF_MAX_INTERVAL_SEC: float = 40.0
const VANEK_SKIM_MIN_INTERVAL_SEC: float = 45.0
const VANEK_SKIM_MAX_INTERVAL_SEC: float = 75.0

var groschen: float = 0.0
var total_groschen_spent: float = 0.0
var total_groschen_earned: float = 0.0
var groschen_per_click: float = BASE_GROSCHEN_PER_CLICK
var groschen_per_sec: float = BASE_GROSCHEN_PER_SEC
var legacy_multiplier: float = BASE_LEGACY_MULTIPLIER
var sigismund_threat: float = 0.0
var threat_rate: float = THREAT_BASE_RATE

var _combo_count: int = 1
var _last_click_time: float = -COMBO_WINDOW_SEC
var _click_count: int = 0
var _combo_window_sec: float = COMBO_WINDOW_SEC
var _crit_interval: int = CRIT_INTERVAL
var _crit_multiplier: float = CRIT_MULTIPLIER
var _passive_flat_bonus: float = 0.0
var _passive_multiplier: float = 1.0
var _all_coin_multiplier: float = BASE_ALL_PRODUCTION_MULTIPLIER
var _furnace_unlocked: bool = false
var _furnace_buff_time_remaining: float = 0.0
var _royal_charter_unlocked: bool = false
var _royal_charter_active_time_remaining: float = 0.0
var _royal_charter_cooldown_remaining: float = 0.0
var _tier1_rebate_unlocked: bool = false
var _mintmasters_seal_unlocked: bool = false
var _vlassky_dvur_unlocked: bool = false
var _iron_discipline_unlocked: bool = false
var _prestige_count: int = 0
var _persistent_passive_after_seizure: float = 0.0
var _jiri_goof_time_remaining: float = 0.0
var _jiri_goof_cooldown_remaining: float = -1.0
var _milota_rest_time_remaining: float = 0.0
var _milota_rest_cooldown_remaining: float = MILOTA_REST_INTERVAL_SEC
var _vanek_skim_cooldown_remaining: float = -1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var workers_hired: Array[Worker] = []


func _ready() -> void:
    _rng.randomize()
    _refresh_passive_income()
    _emit_economy_state()
    threat_updated.emit(sigismund_threat)


func _process(delta: float) -> void:
    if delta <= 0.0:
        return

    _update_worker_quirks(delta)
    _update_temporary_multipliers(delta)
    _refresh_passive_income()
    _add_earned_groschen(groschen_per_sec * delta)
    sigismund_threat = minf(sigismund_threat + threat_rate * delta, SEIZURE_THRESHOLD)
    threat_updated.emit(sigismund_threat)
    if sigismund_threat >= SEIZURE_THRESHOLD:
        fire_seizure()


func click_coin() -> void:
    var current_time: float = Time.get_ticks_msec() / 1000.0
    if current_time - _last_click_time <= _combo_window_sec:
        _combo_count = mini(_combo_count + 1, COMBO_MAX)
    else:
        _combo_count = 1
    _last_click_time = current_time

    _click_count += 1
    var is_crit: bool = _click_count % _crit_interval == 0
    var amount: float = groschen_per_click
    if _mintmasters_seal_unlocked:
        amount += float(workers_hired.size())
    amount *= get_combo_multiplier() * legacy_multiplier * _all_coin_multiplier * _get_temporary_production_multiplier()
    if is_crit:
        amount *= _crit_multiplier

    _add_earned_groschen(amount)
    coin_clicked.emit(amount, is_crit, _combo_count)


func hire_worker(worker: Worker) -> void:
    if worker == null or worker.is_hired or not _is_worker_unlock_ready():
        return
    if groschen < float(worker.cost):
        return

    groschen -= float(worker.cost)
    total_groschen_spent += float(worker.cost)
    worker.is_hired = true
    workers_hired.append(worker)
    if worker.has_goof and _jiri_goof_cooldown_remaining < 0.0:
        _jiri_goof_cooldown_remaining = _next_jiri_goof_interval()
    if worker.has_skim and _vanek_skim_cooldown_remaining < 0.0:
        _vanek_skim_cooldown_remaining = _next_vanek_skim_interval()
    if not worker.hire_journal.is_empty():
        journal_entry.emit(worker.hire_journal)
    _refresh_passive_income()
    _emit_economy_state()
    worker_hired.emit(worker)


func purchase_upgrade(upgrade_id: String) -> void:
    var selected_upgrade: UpgradeData = null
    for upgrade: UpgradeData in UpgradeManager.all_upgrades:
        if upgrade != null and upgrade.upgrade_id == upgrade_id:
            selected_upgrade = upgrade
            break

    if selected_upgrade == null or UpgradeManager.purchased_ids.has(upgrade_id):
        return
    if not _is_upgrade_unlocked(selected_upgrade):
        return

    var upgrade_cost: float = _get_upgrade_cost(selected_upgrade)
    if groschen < upgrade_cost:
        return

    groschen -= upgrade_cost
    total_groschen_spent += upgrade_cost
    UpgradeManager.apply_upgrade(selected_upgrade)

    match selected_upgrade.effect_type:
        "click_add":
            groschen_per_click += selected_upgrade.effect_value
        "click_mul":
            groschen_per_click *= selected_upgrade.effect_value
        "passive_add":
            _passive_flat_bonus += selected_upgrade.effect_value
        "passive_mul":
            _passive_multiplier *= selected_upgrade.effect_value
        "unlock":
            _apply_unlock_upgrade(selected_upgrade)
        _:
            _apply_unlock_upgrade(selected_upgrade)

    _refresh_passive_income()
    _emit_economy_state()
    upgrade_purchased.emit(upgrade_id)


func pay_sigismund(amount: float) -> void:
    if amount <= 0.0 or groschen < amount:
        return
    groschen -= amount
    sigismund_threat = maxf(sigismund_threat - THREAT_PAYOFF_REDUCTION, 0.0)
    _emit_economy_state()
    threat_updated.emit(sigismund_threat)
    journal_entry.emit("I told myself it was just this once.")


func fire_seizure() -> void:
    var prestige_bonus: float = minf(
        BASE_LEGACY_MULTIPLIER + total_groschen_earned / LEGACY_EARNINGS_DIVISOR,
        LEGACY_PER_PRESTIGE_CAP
    )
    var seizure_passive_carryover: float = groschen_per_sec if _vlassky_dvur_unlocked else 0.0
    legacy_multiplier *= prestige_bonus
    _prestige_count += 1

    groschen = 0.0
    total_groschen_spent = 0.0
    total_groschen_earned = 0.0
    groschen_per_click = BASE_GROSCHEN_PER_CLICK
    sigismund_threat = 0.0
    threat_rate = THREAT_BASE_RATE
    _combo_count = 1
    _last_click_time = -COMBO_WINDOW_SEC
    _click_count = 0
    _combo_window_sec = COMBO_WINDOW_SEC
    _crit_interval = CRIT_INTERVAL
    _crit_multiplier = CRIT_MULTIPLIER
    _passive_flat_bonus = 0.0
    _passive_multiplier = 1.0
    _all_coin_multiplier = BASE_ALL_PRODUCTION_MULTIPLIER
    _furnace_unlocked = false
    _furnace_buff_time_remaining = 0.0
    _royal_charter_unlocked = false
    _royal_charter_active_time_remaining = 0.0
    _royal_charter_cooldown_remaining = 0.0
    _tier1_rebate_unlocked = false
    _mintmasters_seal_unlocked = false
    _vlassky_dvur_unlocked = false
    _iron_discipline_unlocked = false
    _persistent_passive_after_seizure = seizure_passive_carryover
    _jiri_goof_time_remaining = 0.0
    _jiri_goof_cooldown_remaining = -1.0
    _milota_rest_time_remaining = 0.0
    _milota_rest_cooldown_remaining = MILOTA_REST_INTERVAL_SEC
    _vanek_skim_cooldown_remaining = -1.0

    for worker: Worker in workers_hired:
        worker.is_hired = false
    workers_hired.clear()
    UpgradeManager.purchased_ids.clear()
    _refresh_passive_income()
    _emit_economy_state()
    threat_updated.emit(sigismund_threat)
    journal_entry.emit("They took the mint. But they couldn't take what I know.")
    seizure_fired.emit(prestige_bonus)


func activate_furnace_bonus() -> void:
    if not _furnace_unlocked:
        return
    _furnace_buff_time_remaining = FURNACE_BUFF_DURATION_SEC
    _refresh_passive_income()
    _emit_economy_state()


func activate_royal_charter() -> void:
    if not _royal_charter_unlocked or _royal_charter_cooldown_remaining > 0.0:
        return
    _royal_charter_active_time_remaining = ROYAL_CHARTER_DURATION_SEC
    _royal_charter_cooldown_remaining = ROYAL_CHARTER_COOLDOWN_SEC
    _refresh_passive_income()
    _emit_economy_state()


func get_combo_multiplier() -> float:
    return float(_combo_count)


func _add_earned_groschen(amount: float) -> void:
    if amount <= 0.0:
        return
    groschen += amount
    total_groschen_earned += amount
    _emit_economy_state()


func _emit_economy_state() -> void:
    groschen_updated.emit(groschen, groschen_per_sec)


func _refresh_passive_income() -> void:
    var passive_total: float = 0.0
    for worker: Worker in workers_hired:
        passive_total += _get_worker_output(worker)

    if _has_worker("Radek"):
        passive_total *= RADEK_BASE_MULTIPLIER + RADEK_OTHER_WORKER_BONUS * float(maxi(workers_hired.size() - 1, 0))
    if _has_worker("Bozena"):
        passive_total *= BOZENA_WORKER_MULTIPLIER
    if workers_hired.size() >= FULL_FLOOR_WORKER_COUNT:
        passive_total *= FULL_FLOOR_MULTIPLIER

    passive_total += _passive_flat_bonus
    passive_total *= _passive_multiplier * legacy_multiplier * _get_temporary_production_multiplier()
    groschen_per_sec = passive_total + _persistent_passive_after_seizure


func _get_worker_output(worker: Worker) -> float:
    if worker == null:
        return 0.0

    var output: float = worker.groschen_per_sec
    if worker.has_goof and not _is_jiri_stable() and _jiri_goof_time_remaining > 0.0:
        output = 0.0
    if worker.has_rest and not _iron_discipline_unlocked and _milota_rest_time_remaining > 0.0:
        output *= 0.5
    return output


func _get_temporary_production_multiplier() -> float:
    var multiplier: float = 1.0
    if _furnace_buff_time_remaining > 0.0:
        multiplier *= FURNACE_BUFF_MULTIPLIER
    if _royal_charter_active_time_remaining > 0.0:
        multiplier *= ROYAL_CHARTER_MULTIPLIER
    return multiplier


func _update_worker_quirks(delta: float) -> void:
    if _has_worker("Jiri") and not _is_jiri_stable():
        if _jiri_goof_time_remaining > 0.0:
            _jiri_goof_time_remaining = maxf(_jiri_goof_time_remaining - delta, 0.0)
        else:
            if _jiri_goof_cooldown_remaining < 0.0:
                _jiri_goof_cooldown_remaining = _next_jiri_goof_interval()
            _jiri_goof_cooldown_remaining = maxf(_jiri_goof_cooldown_remaining - delta, 0.0)
            if _jiri_goof_cooldown_remaining <= 0.0:
                _jiri_goof_time_remaining = JIRI_GOOF_DURATION_SEC
                _jiri_goof_cooldown_remaining = _next_jiri_goof_interval()
    else:
        _jiri_goof_time_remaining = 0.0

    if _has_worker("Milota") and not _iron_discipline_unlocked:
        if _milota_rest_time_remaining > 0.0:
            _milota_rest_time_remaining = maxf(_milota_rest_time_remaining - delta, 0.0)
        else:
            _milota_rest_cooldown_remaining = maxf(_milota_rest_cooldown_remaining - delta, 0.0)
            if _milota_rest_cooldown_remaining <= 0.0:
                _milota_rest_time_remaining = MILOTA_REST_DURATION_SEC
                _milota_rest_cooldown_remaining = MILOTA_REST_INTERVAL_SEC
    else:
        _milota_rest_time_remaining = 0.0
        _milota_rest_cooldown_remaining = MILOTA_REST_INTERVAL_SEC

    if _has_worker("Vanek") and not _is_vanek_stable():
        if _vanek_skim_cooldown_remaining < 0.0:
            _vanek_skim_cooldown_remaining = _next_vanek_skim_interval()
        _vanek_skim_cooldown_remaining = maxf(_vanek_skim_cooldown_remaining - delta, 0.0)
        if _vanek_skim_cooldown_remaining <= 0.0:
            groschen = maxf(groschen - VANEK_SKIM_LOSS, 0.0)
            _emit_economy_state()
            _vanek_skim_cooldown_remaining = _next_vanek_skim_interval()
    else:
        _vanek_skim_cooldown_remaining = -1.0


func _update_temporary_multipliers(delta: float) -> void:
    if _furnace_buff_time_remaining > 0.0:
        _furnace_buff_time_remaining = maxf(_furnace_buff_time_remaining - delta, 0.0)
    if _royal_charter_active_time_remaining > 0.0:
        _royal_charter_active_time_remaining = maxf(_royal_charter_active_time_remaining - delta, 0.0)
    if _royal_charter_cooldown_remaining > 0.0:
        _royal_charter_cooldown_remaining = maxf(_royal_charter_cooldown_remaining - delta, 0.0)


func _apply_unlock_upgrade(upgrade: UpgradeData) -> void:
    match upgrade.upgrade_id:
        "upgrade_good_posture":
            _combo_window_sec = COMBO_UPGRADE_WINDOW_SEC
        "upgrade_sharp_eye":
            _crit_interval = CRIT_UPGRADE_INTERVAL
        "upgrade_worn_apron":
            _tier1_rebate_unlocked = true
        "upgrade_new_furnace":
            _furnace_unlocked = true
        "upgrade_silver_import_route":
            _passive_flat_bonus += SILVER_IMPORT_PASSIVE_ADD
        "upgrade_royal_charter":
            _royal_charter_unlocked = true
        "upgrade_reinforced_dies":
            _crit_multiplier = CRIT_REINFORCED_MULTIPLIER
        "upgrade_night_shift":
            _passive_multiplier *= NIGHT_SHIFT_MULTIPLIER
        "upgrade_mintmasters_seal":
            _mintmasters_seal_unlocked = true
        "upgrade_forge_the_kings_groschen":
            _all_coin_multiplier *= 3.0
        "upgrade_the_vlassky_dvur":
            _vlassky_dvur_unlocked = true
        "upgrade_iron_discipline":
            _iron_discipline_unlocked = true
        _:
            pass


func _get_upgrade_cost(upgrade: UpgradeData) -> float:
    if upgrade == null:
        return 0.0
    if _tier1_rebate_unlocked and upgrade.tier == 1 and upgrade.upgrade_id != "upgrade_worn_apron":
        return floorf(float(upgrade.cost) * 0.8)
    return float(upgrade.cost)


func _is_upgrade_unlocked(upgrade: UpgradeData) -> bool:
    if upgrade == null:
        return false

    match upgrade.tier:
        1:
            return true
        2:
            return total_groschen_spent >= TIER2_UNLOCK_SPEND
        3:
            return total_groschen_spent >= TIER3_UNLOCK_SPEND
        4:
            return _prestige_count > 0
        _:
            return false


func _is_worker_unlock_ready() -> bool:
    return total_groschen_spent >= TIER2_UNLOCK_SPEND


func _is_jiri_stable() -> bool:
    return _iron_discipline_unlocked or _has_worker("Bozena")


func _is_vanek_stable() -> bool:
    return _iron_discipline_unlocked or _has_worker("Bozena")


func _has_worker(worker_name: String) -> bool:
    for worker: Worker in workers_hired:
        if worker.worker_name == worker_name:
            return true
    return false


func _next_jiri_goof_interval() -> float:
    return _rng.randf_range(JIRI_GOOF_MIN_INTERVAL_SEC, JIRI_GOOF_MAX_INTERVAL_SEC)


func _next_vanek_skim_interval() -> float:
    return _rng.randf_range(VANEK_SKIM_MIN_INTERVAL_SEC, VANEK_SKIM_MAX_INTERVAL_SEC)
