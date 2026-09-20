#!/usr/bin/env bats
#
# Covers argument parsing, validation, and the confirmation gate. Doesn't
# cover an actual deletion, that needs real Docker.

setup() {
  TEST_DIR="$(mktemp -d)"
  cp "$BATS_TEST_DIRNAME/../dispose_contrib" "$TEST_DIR/dispose_contrib"
  cp "$BATS_TEST_DIRNAME/../_lib.sh" "$TEST_DIR/_lib.sh"
  chmod +x "$TEST_DIR/dispose_contrib"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "--help exits 0 and prints usage" {
  run "$TEST_DIR/dispose_contrib" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "no arguments exits 2 and reports missing --mn" {
  run "$TEST_DIR/dispose_contrib"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--mn is required"* ]]
}

@test "unrecognized flag exits 2" {
  run "$TEST_DIR/dispose_contrib" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unrecognized argument"* ]]
}

@test "module name with a path segment is rejected" {
  run "$TEST_DIR/dispose_contrib" --mn=../evil
  [ "$status" -eq 1 ]
  [[ "$output" == *"doesn't look like a Drupal machine name"* ]]
}

@test "module name with uppercase letters is rejected" {
  run "$TEST_DIR/dispose_contrib" --mn=MyModule
  [ "$status" -eq 1 ]
  [[ "$output" == *"doesn't look like a Drupal machine name"* ]]
}

@test "wrong confirmation aborts before touching ddev or the filesystem" {
  mkdir -p "$TEST_DIR/my_module"
  touch "$TEST_DIR/my_module/marker"
  run bash -c "echo nope | '$TEST_DIR/dispose_contrib' --mn=my_module"
  [ "$status" -eq 1 ]
  [[ "$output" == *"confirmation did not match"* ]]
  [ -f "$TEST_DIR/my_module/marker" ]
}

@test "empty confirmation aborts" {
  mkdir -p "$TEST_DIR/my_module"
  run bash -c "echo '' | '$TEST_DIR/dispose_contrib' --mn=my_module"
  [ "$status" -eq 1 ]
  [[ "$output" == *"confirmation did not match"* ]]
  [ -d "$TEST_DIR/my_module" ]
}

@test "module with a .ddev dir requires ddev before deleting, without ddev on PATH nothing is removed" {
  mkdir -p "$TEST_DIR/my_module/.ddev"
  touch "$TEST_DIR/my_module/marker"
  run bash -c "PATH=/usr/bin:/bin; echo my_module | '$TEST_DIR/dispose_contrib' --mn=my_module"
  [ "$status" -eq 1 ]
  [[ "$output" == *"required command 'ddev' not found"* ]]
  [ -f "$TEST_DIR/my_module/marker" ]
}

@test "module without a .ddev dir is removed without ever requiring ddev" {
  mkdir -p "$TEST_DIR/my_module"
  touch "$TEST_DIR/my_module/marker"
  run bash -c "PATH=/usr/bin:/bin; echo my_module | '$TEST_DIR/dispose_contrib' --mn=my_module"
  [ "$status" -eq 0 ]
  [[ "$output" != *"DDEV project"* ]]
  [ ! -d "$TEST_DIR/my_module" ]
}

@test "confirmation plan only mentions a DDEV project when .ddev exists" {
  mkdir -p "$TEST_DIR/my_module"
  run bash -c "echo nope | '$TEST_DIR/dispose_contrib' --mn=my_module"
  [[ "$output" != *"DDEV project"* ]]
}

@test "nonexistent --dir is rejected" {
  run "$TEST_DIR/dispose_contrib" --mn=my_module --dir=/no/such/dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"/no/such/dir does not exist"* ]]
}

@test "--dir with a leading ~ is expanded against HOME" {
  mkdir -p "$TEST_DIR/home/workspace/my_module"
  touch "$TEST_DIR/home/workspace/my_module/marker"
  HOME="$TEST_DIR/home" run bash -c "echo nope | HOME='$TEST_DIR/home' '$TEST_DIR/dispose_contrib' --mn=my_module --dir=~/workspace"
  [ "$status" -eq 1 ]
  [[ "$output" == *"confirmation did not match"* ]]
  [ -f "$TEST_DIR/home/workspace/my_module/marker" ]
}

@test "--dir points deletion at a module outside the script's own directory" {
  mkdir -p "$TEST_DIR/elsewhere/my_module"
  touch "$TEST_DIR/elsewhere/my_module/marker"
  run bash -c "PATH=/usr/bin:/bin; echo my_module | '$TEST_DIR/dispose_contrib' --mn=my_module --dir='$TEST_DIR/elsewhere'"
  [ "$status" -eq 0 ]
  [ ! -d "$TEST_DIR/elsewhere/my_module" ]
}
