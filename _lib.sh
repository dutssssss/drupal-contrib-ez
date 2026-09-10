#!/usr/bin/env bash
# Shared helpers for setup_contrib and dispose_contrib. Sourced, not run directly.

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

# Expands a leading ~ or ~/ in a --dir=-style path argument. Bash only expands
# a bare ~ when it's at the very start of an unquoted word, so --dir=~/foo is
# never expanded by the shell itself; do it by hand here instead.
expand_tilde() {
  local path="$1"
  # The ~/ pattern below is a case match against a literal string, not a
  # shell expansion, so shellcheck's "tilde doesn't expand in quotes" warning
  # doesn't apply here.
  # shellcheck disable=SC2088
  case "$path" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s\n' "$HOME/${path#"~/"}" ;;
    *) printf '%s\n' "$path" ;;
  esac
}
