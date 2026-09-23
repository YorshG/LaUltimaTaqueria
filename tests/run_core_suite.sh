#!/usr/bin/env bash
# TST-01: single reproducible entry point for the core-rules test suite.
# Runs, in one deterministic order, every existing test that covers the
# rules required by TST-01 (content validation, board, recipes,
# lane targeting/satisfaction, waves, upgrades). It does not add new
# gameplay tests; it orchestrates the ones already delivered per feature.
set -u

GODOT_BIN="${GODOT_BIN:-godot}"

CORE_SUITE_TESTS=(
  "res://tests/content_registry_test.gd"
  "res://tests/board_view_test.gd"
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
  "res://tests/upgrade_selector_integration_test.gd"
)

failures=0
declare -a results=()

for test_path in "${CORE_SUITE_TESTS[@]}"; do
  echo "=== Running ${test_path} ==="
  if "${GODOT_BIN}" --headless --path . --script "${test_path}"; then
    results+=("PASS ${test_path}")
  else
    results+=("FAIL ${test_path}")
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
