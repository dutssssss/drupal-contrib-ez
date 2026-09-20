#!/usr/bin/env bash
# Shared helpers for setup_contrib, dispose_contrib, setup_canvas_dev, and
# dispose_canvas_dev. Sourced, not run directly.

log() {
  printf '==> %s\n' "$*" >&2
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command '$1' not found on PATH."
}

validate_machine_name() {
  local flag="$1" value="$2"
  [[ "$value" =~ ^[a-z][a-z0-9_]*$ ]] \
    || die "$flag '$value' doesn't look like a Drupal machine name (lowercase letters, digits, underscores, starting with a letter)."
}

# Bash only expands a bare ~ at the start of an unquoted word, so --dir=~/foo
# never gets expanded by the shell itself; expand it by hand here.
expand_tilde() {
  local path="$1"
  # Case match against a literal string, not a shell expansion, so SC2088
  # doesn't apply here.
  # shellcheck disable=SC2088
  case "$path" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s\n' "$HOME/${path#"~/"}" ;;
    *) printf '%s\n' "$path" ;;
  esac
}

# Strips a #-comment and surrounding whitespace from a requirements-file
# line. Shared by other-modules.txt and recipes.txt parsing.
trim_requirement_line() {
  local line="$1"
  line="${line%%#*}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  printf '%s' "$line"
}

# Same literal-string idempotency idiom as the drush and plugin-approval
# checks in setup_contrib. A blank constraint just checks the package is
# declared at all. Must be run from the project directory (composer.json).
requirement_satisfied() {
  local package="$1" constraint="$2"
  [[ -f composer.json ]] || return 1
  if [[ -n "$constraint" ]]; then
    grep -qF "\"$package\": \"$constraint\"" composer.json
  else
    grep -qF "\"$package\":" composer.json
  fi
}
