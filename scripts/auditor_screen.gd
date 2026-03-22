# Coordinates the Day 14 result overlay so the final pass/fail state is shown in
# a single place without embedding audit text in the state autoloads.
extends CanvasLayer

@onready var _result_title: Label = $"Overlay/ResultPanel/VBoxContainer/ResultTitle"
@onready var _result_summary: Label = $"Overlay/ResultPanel/VBoxContainer/ResultSummary"


func show_result(ending_id: String, snapshot: Dictionary) -> void:
    visible = true

    if ending_id == "audit_pass":
        _result_title.text = "Royal auditor's report - Passed"
        _result_summary.text = (
            "The Crown accepts your books. Quota stands at %d / %d, and the "
            + "ledger remains fit for inspection."
        ) % [int(snapshot["cumulative_output"]), int(snapshot["cumulative_target"])]
        return

    _result_title.text = "Royal auditor's report - Failed"
    _result_summary.text = (
        "The auditor rejects your work. Quota stands at %d / %d, and the "
        + "ledger carries the stain of irregular minting."
    ) % [int(snapshot["cumulative_output"]), int(snapshot["cumulative_target"])]
