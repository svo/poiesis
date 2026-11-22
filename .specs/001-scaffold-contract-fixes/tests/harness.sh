#!/usr/bin/env bash
#
# Shared assertions and runners for the 001 checks. Sourced, not run.
#
# The variables set here are read by the tests that source it.
# shellcheck disable=SC2034

TESTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${TESTS_DIR}/../../.." && pwd)"
FIXTURES_DIR="${TESTS_DIR}/fixtures"

ROLE_DIR="${REPO_ROOT}/infrastructure/ansible/roles/claude-code-service"
PROMPTS_DIR="${ROLE_DIR}/files/prompts"
SKILLS_DIR="${ROLE_DIR}/files/skills"
ENTRYPOINT="${ENTRYPOINT:-${REPO_ROOT}/infrastructure/ansible/roles/openclaw/files/entrypoint.sh}"
PURGE_CHECK="${PURGE_CHECK:-${ROLE_DIR}/files/bin/poiesis-purge-check}"

# The bash running the checks. Scripts under test are started with it rather
# than whatever "bash" a stripped PATH finds, which on macOS is bash 3.2.
SHELL_UNDER_TEST="${BASH:-bash}"

TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_CASE=""
CASE_FAILURES=0

TMP_ROOT="$(mktemp -d)"
BIN_DIR="${TMP_ROOT}/bin"
mkdir -p "$BIN_DIR"
for stub in "${TESTS_DIR}"/stubs/*; do
  cp "$stub" "${BIN_DIR}/$(basename "$stub")"
  chmod +x "${BIN_DIR}/$(basename "$stub")"
done

cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

case_start() {
  CURRENT_CASE="$1"
  CASE_FAILURES=0
}

case_end() {
  if [ "$CASE_FAILURES" -eq 0 ]; then
    printf 'PASS %s\n' "$CURRENT_CASE"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

fail() {
  if [ "$CASE_FAILURES" -eq 0 ]; then
    printf 'FAIL %s\n' "$CURRENT_CASE" >&2
  fi
  CASE_FAILURES=$((CASE_FAILURES + 1))
  printf '     %s\n' "$1" >&2
}

assert_equals() {
  if [ "$2" != "$3" ]; then
    fail "$1"
    printf '       expected: %s\n' "$2" >&2
    printf '       actual:   %s\n' "$3" >&2
  fi
}

assert_not_equals() {
  if [ "$2" = "$3" ]; then
    fail "$1"
    printf '       expected anything but: %s\n' "$2" >&2
  fi
}

assert_contains() {
  case "$2" in
    *"$3"*) ;;
    *)
      fail "$1"
      printf '       expected to contain: %s\n' "$3" >&2
      printf '       actual:\n%s\n' "$(printf '%s\n' "$2" | sed 's/^/         /')" >&2
      ;;
  esac
}

assert_not_contains() {
  case "$2" in
    *"$3"*)
      fail "$1"
      printf '       expected NOT to contain: %s\n' "$3" >&2
      printf '       actual:\n%s\n' "$(printf '%s\n' "$2" | sed 's/^/         /')" >&2
      ;;
  esac
}

# assert_no_match <message> <extended-regex> <file>...
# Fails, listing every matching line, when any file has a line matching the regex.
assert_no_match() {
  local message="$1" pattern="$2" hits
  shift 2
  hits="$(grep -HnE -e "$pattern" "$@" 2>/dev/null)"
  if [ -n "$hits" ]; then
    fail "$message"
    printf '%s\n' "$hits" | sed "s|${REPO_ROOT}/||; s/^/       /" >&2
  fi
}

# assert_match <message> <extended-regex> <file>
assert_match() {
  if ! grep -qE -e "$2" "$3" 2>/dev/null; then
    fail "$1"
    printf '       no line in %s matches: %s\n' "${3#"${REPO_ROOT}"/}" "$2" >&2
  fi
}

report_totals() {
  printf '\n%s: %d passed, %d failed\n' "$1" "$TESTS_PASSED" "$TESTS_FAILED"
  [ "$TESTS_FAILED" -eq 0 ]
}

# ---------------------------------------------------------------------------
# poiesis-purge-check

# copy_fixture <name> — a private, writable copy of a fixture tree. Prints its path.
copy_fixture() {
  local dir
  dir="$(mktemp -d "${TMP_ROOT}/tree.XXXXXX")"
  if [ -n "${1:-}" ]; then
    cp -R "${FIXTURES_DIR}/$1/." "$dir/"
  fi
  printf '%s\n' "$dir"
}

# run_purge_check <args>... — sets CHECK_STATUS, CHECK_OUT and CHECK_ERR.
run_purge_check() {
  local out_file err_file
  out_file="$(mktemp "${TMP_ROOT}/out.XXXXXX")"
  err_file="$(mktemp "${TMP_ROOT}/err.XXXXXX")"
  if [ -f "$PURGE_CHECK" ]; then
    "$SHELL_UNDER_TEST" "$PURGE_CHECK" "$@" >"$out_file" 2>"$err_file"
    CHECK_STATUS=$?
  else
    printf 'harness: %s does not exist\n' "$PURGE_CHECK" >"$err_file"
    CHECK_STATUS=127
  fi
  CHECK_OUT="$(cat "$out_file")"
  CHECK_ERR="$(cat "$err_file")"
}

# Only the finding lines from stderr: "purge-check: <file>: <reason>".
check_findings() {
  printf '%s\n' "$CHECK_ERR" | grep -E '^purge-check: [^ ]+: ' || true
}

# ---------------------------------------------------------------------------
# entrypoint.sh

DEFAULT_ENV=(
  ANTHROPIC_API_KEY=sk-ant-stub
  GITHUB_TOKEN=ghp_stub
  POIESIS_BLOG_URL=https://blog.example/posts
  POIESIS_GITHUB_OWNER=svo
  "POIESIS_CRON_SCHEDULE=0 8 * * 1"
  POIESIS_TIMEZONE=UTC
)

# run_entrypoint [--omit VAR]... [VAR=value]...
# Runs the real entrypoint against the stubs, in a private HOME and an
# environment holding only DEFAULT_ENV (less what is omitted) and the
# arguments. Sets RUN_STATUS, RUN_OUT, RUN_ERR, RUN_DIR, RUN_HOME, RUN_AGENTS.
run_entrypoint() {
  local run_dir home entry name candidate skip
  local -a omit=() env_args=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --omit) omit+=("$2"); shift 2 ;;
      *) break ;;
    esac
  done

  run_dir="$(mktemp -d "${TMP_ROOT}/run.XXXXXX")"
  home="${run_dir}/home"
  mkdir -p "$home"

  for entry in "${DEFAULT_ENV[@]}"; do
    name="${entry%%=*}"
    skip=""
    for candidate in ${omit[@]+"${omit[@]}"}; do
      if [ "$candidate" = "$name" ]; then
        skip="yes"
        break
      fi
    done
    if [ -z "$skip" ]; then
      env_args+=("$entry")
    fi
  done

  env -i \
    HOME="$home" \
    PATH="${BIN_DIR}:/usr/bin:/bin:/usr/sbin:/sbin" \
    STUB_MARKERS="$run_dir" \
    "${env_args[@]}" \
    "$@" \
    "$SHELL_UNDER_TEST" "$ENTRYPOINT" >"${run_dir}/stdout" 2>"${run_dir}/stderr"
  RUN_STATUS=$?

  RUN_DIR="$run_dir"
  RUN_HOME="$home"
  RUN_AGENTS="${home}/.openclaw/workspace/AGENTS.md"
  RUN_OUT="$(cat "${run_dir}/stdout")"
  RUN_ERR="$(cat "${run_dir}/stderr")"
}

gateway_started() {
  [ -f "${RUN_DIR}/gateway-started" ]
}

agents_md() {
  if [ -f "$RUN_AGENTS" ]; then
    cat "$RUN_AGENTS"
  fi
}

# The fenced bash block under "## Each Cycle" in the generated AGENTS.md.
cycle_command() {
  agents_md | awk '
    /^## Each Cycle/ { in_section = 1; next }
    /^## / { in_section = 0 }
    in_section && /^```bash/ { in_block = 1; next }
    in_block && /^```/ { exit }
    in_block { print }
  '
}

# The "## Scaffolding configuration" section of the generated AGENTS.md.
scaffolding_section() {
  agents_md | awk '
    /^## Scaffolding configuration/ { in_section = 1; print; next }
    /^## / { in_section = 0 }
    in_section { print }
  '
}

# run_cycle_command — runs the generated cycle command with the stubs on PATH
# and nothing else in its environment, so whatever reaches the stub claude
# came from the command itself. Sets CYCLE_STATUS and CYCLE_ENV (the POIESIS_*
# variables the stub claude saw, sorted).
run_cycle_command() {
  local command cycle_dir
  command="$(cycle_command)"
  cycle_dir="$(mktemp -d "${TMP_ROOT}/cycle.XXXXXX")"
  env -i \
    HOME="${cycle_dir}" \
    PATH="${BIN_DIR}:/usr/bin:/bin" \
    STUB_MARKERS="$cycle_dir" \
    "$SHELL_UNDER_TEST" -c "$command" >"${cycle_dir}/stdout" 2>"${cycle_dir}/stderr"
  CYCLE_STATUS=$?
  CYCLE_ENV="$(cat "${cycle_dir}/claude-env" 2>/dev/null)"
  CYCLE_RUNUSER="$(cat "${cycle_dir}/runuser-calls" 2>/dev/null)"
}
