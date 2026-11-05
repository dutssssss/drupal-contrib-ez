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

# Whether composer.json declares a package under require or require-dev,
# optionally with exactly that constraint. Only those two sections count: a
# plain grep also matches "conflict" entries (entity_reference_revisions has
# "drush/drush": "<12.5.1"), which would wrongly skip the require. Parsed with
# the container's PHP so the host needs no JSON tool; --raw stops ddev
# re-running it through bash, which would expand the PHP $vars. Must be run
# from the project directory (composer.json) after `ddev start`.
requirement_satisfied() {
  local package="$1" constraint="$2"
  [[ -f composer.json ]] || return 1
  # shellcheck disable=SC2016 # PHP code, $vars must not expand
  ddev exec --raw -- php -r '
    $j = json_decode(file_get_contents("composer.json"), true);
    foreach (["require", "require-dev"] as $section) {
      if (isset($j[$section][$argv[1]]) && ($argv[2] === "" || $j[$section][$argv[1]] === $argv[2])) {
        exit(0);
      }
    }
    exit(1);
  ' "$package" "$constraint" >/dev/null 2>&1
}
