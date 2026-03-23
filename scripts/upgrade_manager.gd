# Loads authored upgrade resources for the clicker rebuild so shop data stays
# in .tres files and purchase state can be tracked centrally.
extends Node

const UPGRADE_DIRECTORY: String = "res://data/upgrades"

var all_upgrades: Array[UpgradeData] = []
var purchased_ids: Array[String] = []


func _ready() -> void:
    _load_upgrades()


func get_available_upgrades() -> Array[UpgradeData]:
    var available_upgrades: Array[UpgradeData] = []
    for upgrade: UpgradeData in all_upgrades:
        if upgrade == null or purchased_ids.has(upgrade.upgrade_id):
            continue
        available_upgrades.append(upgrade)
    return available_upgrades


func is_affordable(upgrade: UpgradeData) -> bool:
    return upgrade != null and not purchased_ids.has(upgrade.upgrade_id) and GameManager.groschen >= float(upgrade.cost)


func purchase_upgrade(upgrade_id: String) -> void:
    GameManager.purchase_upgrade(upgrade_id)


func apply_upgrade(upgrade: UpgradeData) -> void:
    if upgrade == null or purchased_ids.has(upgrade.upgrade_id):
        return
    purchased_ids.append(upgrade.upgrade_id)


func _load_upgrades() -> void:
    all_upgrades.clear()

    var directory: DirAccess = DirAccess.open(UPGRADE_DIRECTORY)
    if directory == null:
        return

    directory.list_dir_begin()
    while true:
        var file_name: String = directory.get_next()
        if file_name.is_empty():
            break
        if directory.current_is_dir() or not file_name.ends_with(".tres"):
            continue

        var resource_path: String = "%s/%s" % [UPGRADE_DIRECTORY, file_name]
        var upgrade: UpgradeData = load(resource_path) as UpgradeData
        if upgrade != null:
            all_upgrades.append(upgrade)

    directory.list_dir_end()
    all_upgrades.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool:
        if a.tier == b.tier:
            return a.cost < b.cost
        return a.tier < b.tier
    )
