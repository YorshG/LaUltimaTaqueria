#!/usr/bin/env bash
# TST-01: single reproducible entry point for the core-rules test suite.
# Runs, in one deterministic order, every existing test that covers the
# rules required by TST-01 (content validation, board, recipes,
# lane targeting/satisfaction, waves, upgrades). It does not add new
# gameplay tests; it orchestrates the ones already delivered per feature.
# Mobile spatial/presentation contracts are included to prevent silent omissions.
set -u

GODOT_BIN="${GODOT_BIN:-godot}"

CORE_SUITE_TESTS=(
  "res://tests/content_registry_test.gd"
  "res://tests/board_view_test.gd"
  "res://tests/board_input_test.gd"
  "res://tests/chain_path_test.gd"
  "res://tests/board_refill_test.gd"
  "res://tests/board_playability_test.gd"
  "res://tests/recipe_resolver_test.gd"
  "res://tests/monster_state_test.gd"
  "res://tests/lane_field_test.gd"
  "res://tests/lane_targeting_test.gd"
  "res://tests/lane_integration_test.gd"
  "res://tests/wave_director_test.gd"
  "res://tests/upgrade_selector_test.gd"
  "res://tests/upgrade_modifiers_test.gd"
  "res://tests/upg_02b_satisfaction_test.gd"
  "res://tests/upg_02c_global_speed_test.gd"
  "res://tests/upg_02d_reputation_defense_test.gd"
  "res://tests/upg_02e_survival_test.gd"
  "res://tests/upg_02f_conditionals_test.gd"
  "res://tests/upg_02g_assist_serve_test.gd"
  "res://tests/upg_02h_steady_hands_test.gd"
  "res://tests/upgrade_selector_integration_test.gd"
  "res://tests/run_loop_test.gd"
  "res://tests/ui_mobile_layout_test.gd"
  "res://tests/art_01b_layout_test.gd"
  "res://tests/art_01d_audit_test.gd"
)

output_dir="$(mktemp -d)"
trap 'rm -rf "$output_dir"' EXIT

failures=0
declare -a results=()

for test_path in "${CORE_SUITE_TESTS[@]}"; do
  echo "=== Running ${test_path} ==="
  output_file="$output_dir/$(basename "$test_path").log"
  status=0
  GODOT_BIN="${GODOT_BIN}" python3 tests/run_checked_godot.py --script "${test_path}" > "$output_file" 2>&1 || status=$?
  cat "$output_file"
  if [ "$status" -eq 0 ] && ! grep -Eiq 'SCRIPT ERROR|Parse Error|^[[:space:]]*ERROR:|leaked at exit|still in use at exit' "$output_file"; then
    results+=("PASS ${test_path}")
  else
    results+=("FAIL ${test_path} (exit $status or engine diagnostic)")
    failures=$((failures + 1))
  fi
done

echo
echo "=== TST-01 core suite summary ==="
for line in "${results[@]}"; do
  echo "${line}"
done

total=${#CORE_SUITE_TESTS[@]}
passed=$((total - failures))
echo "${passed}/${total} test files passed."

if [ "${failures}" -ne 0 ]; then
  exit 1
fi
exit 0
