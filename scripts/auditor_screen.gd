# Coordinates the Day 14 result overlay so the final pass/fail state is shown in
# a single place without embedding audit text in the state autoloads.
extends CanvasLayer

@onready var _result_title: Label = $"Overlay/ResultPanel/VBoxContainer/ResultTitle"
@onready var _result_summary: Label = $"Overlay/ResultPanel/VBoxContainer/ResultSummary"


func show_result(ending_id: String, snapshot: Dictionary) -> void:
    visible = true

    if ending_id == "ledger_bankrupt":
        _result_title.text = "The treasury runs dry"
        _result_summary.text = (
            "The wages come due and your coffers fail. Quota stands at %d / %d, "
            + "and the Crown replaces you before the auditor need lift his seal."
        ) % [int(snapshot["cumulative_output"]), int(snapshot["cumulative_target"])]
        return

    if ending_id == "workers_incapacitated":
        _result_title.text = "The mintmaster loses the floor"
        _result_summary.text = (
            "Every moneyer has collapsed at the bench. Quota stands at %d / %d, "
            + "and the Crown removes you before the furnaces cool."
        ) % [int(snapshot["cumulative_output"]), int(snapshot["cumulative_target"])]
        return

    if ending_id == "zero_output_collapse":
        _result_title.text = "The mint falls silent"
        _result_summary.text = (
            "Three fruitless shifts have broken the floor. Quota stands at %d / %d, "
            + "and the Crown closes the books before the auditor ever arrives."
        ) % [int(snapshot["cumulative_output"]), int(snapshot["cumulative_target"])]
        return

    if ending_id == "audit_pass":
        _result_title.text = "Royal auditor's report - Passed"
        _result_summary.text = (
            "The Crown accepts your books. Quota stands at %d / %d, and the "
            + "ledger remains fit for inspection."
        ) % [int(snapshot["cumulative_output"]), int(snapshot["cumulative_target"])]
        return

    _result_title.text = "Royal auditor's report - Failed"
    if not bool(snapshot["ledger_clean"]):
        _result_summary.text = (
            "The auditor rejects your work. Quota stands at %d / %d, and the "
            + "ledger carries the stain of irregular minting."
        ) % [int(snapshot["cumulative_output"]), int(snapshot["cumulative_target"])]
        return

    _result_summary.text = (
        "The auditor rejects your work. Quota stands at %d / %d, and the Crown "
        + "finds your output wanting even if the books remain clean."
    ) % [int(snapshot["cumulative_output"]), int(snapshot["cumulative_target"])]
