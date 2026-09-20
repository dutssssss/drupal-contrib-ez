#!/usr/bin/env bats
#
# Mostly argument parsing and validation, which doesn't need `ddev`/`git`
# installed. A few tests stub both with fake executables on PATH to exercise
# behavior further into the script (like other-modules.txt handling)
# without needing real Docker.

setup() {
  TEST_DIR="$(mktemp -d)"
  cp "$BATS_TEST_DIRNAME/../setup_contrib" "$TEST_DIR/setup_contrib"
  cp "$BATS_TEST_DIRNAME/../_lib.sh" "$TEST_DIR/_lib.sh"
  chmod +x "$TEST_DIR/setup_contrib"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "--help exits 0 and prints usage" {
  run "$TEST_DIR/setup_contrib" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "no arguments exits 2 and reports missing --mn" {
  run "$TEST_DIR/setup_contrib"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--mn is required"* ]]
}

@test "missing --cv on a new module exits 2" {
  run "$TEST_DIR/setup_contrib" --mn=my_module
  [ "$status" -eq 2 ]
  [[ "$output" == *"--cv is required"* ]]
}

@test "missing --cv on an existing module with no prior .env.web exits 2" {
  mkdir -p "$TEST_DIR/my_module"
  run "$TEST_DIR/setup_contrib" --mn=my_module
  [ "$status" -eq 2 ]
  [[ "$output" == *"--cv is required"* ]]
}

@test "missing --cv on a rerun reuses DRUPAL_CORE from a previous .env.web" {
  mkdir -p "$TEST_DIR/my_module/.ddev"
  echo "DRUPAL_CORE=^11.2" > "$TEST_DIR/my_module/.ddev/.env.web"
  PATH=/usr/bin:/bin run "$TEST_DIR/setup_contrib" --mn=my_module
  [ "$status" -eq 1 ]
  [[ "$output" == *"reusing DRUPAL_CORE=^11.2"* ]]
  [[ "$output" == *"required command 'ddev' not found"* ]]
}

@test "unrecognized flag exits 2" {
  run "$TEST_DIR/setup_contrib" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unrecognized argument"* ]]
}

@test "module name with a path segment is rejected" {
  run "$TEST_DIR/setup_contrib" --mn=../evil --cv=^11.2
  [ "$status" -eq 1 ]
  [[ "$output" == *"doesn't look like a Drupal machine name"* ]]
}

@test "module name with uppercase letters is rejected" {
  run "$TEST_DIR/setup_contrib" --mn=MyModule --cv=^11.2
  [ "$status" -eq 1 ]
  [[ "$output" == *"doesn't look like a Drupal machine name"* ]]
}

@test "module name starting with a digit is rejected" {
  run "$TEST_DIR/setup_contrib" --mn=1module --cv=^11.2
  [ "$status" -eq 1 ]
  [[ "$output" == *"doesn't look like a Drupal machine name"* ]]
}

@test "unparseable core version is rejected" {
  run "$TEST_DIR/setup_contrib" --mn=my_module --cv=banana
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not parse a major version number"* ]]
}

@test "nonexistent --dir is rejected" {
  run "$TEST_DIR/setup_contrib" --mn=my_module --cv=^11.2 --dir=/no/such/dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"/no/such/dir does not exist"* ]]
}

@test "--dir with a leading ~ is expanded against HOME" {
  mkdir -p "$TEST_DIR/home/workspace"
  PATH=/usr/bin:/bin HOME="$TEST_DIR/home" run "$TEST_DIR/setup_contrib" --mn=my_module --cv=^11.2 --dir=~/workspace
  [ "$status" -eq 1 ]
  [[ "$output" == *"required command 'ddev' not found"* ]]
}

@test "valid input passes validation and fails on missing ddev" {
  PATH=/usr/bin:/bin run "$TEST_DIR/setup_contrib" --mn=my_module --cv=^11.2
  [ "$status" -eq 1 ]
  [[ "$output" == *"required command 'ddev' not found"* ]]
}

@test "valid --pn and --dir together pass validation and fail on missing ddev" {
  mkdir -p "$TEST_DIR/workspace"
  PATH=/usr/bin:/bin run "$TEST_DIR/setup_contrib" --mn=my_module --cv=^11.2 --pn=my-module-scratch --dir="$TEST_DIR/workspace"
  [ "$status" -eq 1 ]
  [[ "$output" == *"required command 'ddev' not found"* ]]
}

@test "other-modules.txt: drupal/ entries are enabled, other vendors are not, a bad guess doesn't abort the run" {
  local fake_bin="$TEST_DIR/fake_bin"
  local ddev_log="$TEST_DIR/ddev.log"
  mkdir -p "$fake_bin" "$TEST_DIR/workspace/my_module/.ddev" "$TEST_DIR/overrides/my_module"
  echo "DRUPAL_CORE=^11.2" > "$TEST_DIR/workspace/my_module/.ddev/.env.web"

  cat > "$fake_bin/git" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  cat > "$fake_bin/ddev" <<STUB
#!/usr/bin/env bash
echo "ddev \$*" >> "$ddev_log"
if [[ "\$*" == *"pm:enable broken_guess"* ]]; then
  exit 1
fi
exit 0
STUB
  chmod +x "$fake_bin/git" "$fake_bin/ddev"

  cat > "$TEST_DIR/overrides/my_module/other-modules.txt" <<'LIST'
drupal/ai_provider_openai
drupal/ai_provider_anthropic:^1.0
drupal/broken_guess
some-vendor/not-a-drupal-package
LIST

  PATH="$fake_bin:/usr/bin:/bin" run "$TEST_DIR/setup_contrib" --mn=my_module --si --dir="$TEST_DIR/workspace"

  [ "$status" -eq 0 ]
  [[ "$output" == *"could not enable 'broken_guess'"* ]]
  grep -qF "pm:enable ai_provider_openai -y" "$ddev_log"
  grep -qF "pm:enable ai_provider_anthropic -y" "$ddev_log"
  grep -qF "pm:enable broken_guess -y" "$ddev_log"
  ! grep -qF "pm:enable not-a-drupal-package" "$ddev_log"
}

@test "overrides/ is read from next to the script, not from --dir" {
  local fake_bin="$TEST_DIR/fake_bin"
  local ddev_log="$TEST_DIR/ddev.log"
  mkdir -p "$fake_bin" "$TEST_DIR/workspace/my_module/.ddev" "$TEST_DIR/overrides/my_module" \
    "$TEST_DIR/workspace/overrides/my_module"
  echo "DRUPAL_CORE=^11.2" > "$TEST_DIR/workspace/my_module/.ddev/.env.web"

  cat > "$fake_bin/git" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  cat > "$fake_bin/ddev" <<STUB
#!/usr/bin/env bash
echo "ddev \$*" >> "$ddev_log"
exit 0
STUB
  chmod +x "$fake_bin/git" "$fake_bin/ddev"

  echo "drupal/ai_provider_openai" > "$TEST_DIR/overrides/my_module/other-modules.txt"
  echo "drupal/should_not_be_used" > "$TEST_DIR/workspace/overrides/my_module/other-modules.txt"

  PATH="$fake_bin:/usr/bin:/bin" run "$TEST_DIR/setup_contrib" --mn=my_module --si --dir="$TEST_DIR/workspace"

  [ "$status" -eq 0 ]
  grep -qF "pm:enable ai_provider_openai -y" "$ddev_log"
  ! grep -qF "pm:enable should_not_be_used" "$ddev_log"
}

@test "web-build/ contents are copied into .ddev/web-build/ before ddev start" {
  local fake_bin="$TEST_DIR/fake_bin"
  mkdir -p "$fake_bin" "$TEST_DIR/workspace/my_module/.ddev" \
    "$TEST_DIR/overrides/my_module/web-build"
  echo "DRUPAL_CORE=^11.2" > "$TEST_DIR/workspace/my_module/.ddev/.env.web"

  cat > "$fake_bin/git" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  cat > "$fake_bin/ddev" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  chmod +x "$fake_bin/git" "$fake_bin/ddev"

  echo "RUN echo hi" > "$TEST_DIR/overrides/my_module/web-build/pre.Dockerfile"
  echo "fake-cert" > "$TEST_DIR/overrides/my_module/web-build/cloudflare-ca.crt"

  PATH="$fake_bin:/usr/bin:/bin" run "$TEST_DIR/setup_contrib" --mn=my_module --si --dir="$TEST_DIR/workspace"

  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/workspace/my_module/.ddev/web-build/pre.Dockerfile" ]
  [ -f "$TEST_DIR/workspace/my_module/.ddev/web-build/cloudflare-ca.crt" ]
  grep -qF "RUN echo hi" "$TEST_DIR/workspace/my_module/.ddev/web-build/pre.Dockerfile"
}

@test "web-build files keep their source mtime, so an unchanged rerun doesn't look modified to ddev" {
  local fake_bin="$TEST_DIR/fake_bin"
  local src="$TEST_DIR/overrides/my_module/web-build/pre.Dockerfile"
  local dest="$TEST_DIR/workspace/my_module/.ddev/web-build/pre.Dockerfile"
  mkdir -p "$fake_bin" "$TEST_DIR/workspace/my_module/.ddev" \
    "$TEST_DIR/overrides/my_module/web-build"
  echo "DRUPAL_CORE=^11.2" > "$TEST_DIR/workspace/my_module/.ddev/.env.web"

  cat > "$fake_bin/git" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  cat > "$fake_bin/ddev" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  chmod +x "$fake_bin/git" "$fake_bin/ddev"

  echo "RUN echo hi" > "$src"
  touch -t 202001010000 "$src"

  mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1"; }
  local src_mtime
  src_mtime="$(mtime "$src")"

  PATH="$fake_bin:/usr/bin:/bin" run "$TEST_DIR/setup_contrib" --mn=my_module --si --dir="$TEST_DIR/workspace"
  [ "$status" -eq 0 ]

  local dest_mtime
  dest_mtime="$(mtime "$dest")"
  [ "$dest_mtime" = "$src_mtime" ]
}

@test "a web-build file identical to what's already there is not recopied, a changed one is" {
  local fake_bin="$TEST_DIR/fake_bin"
  local src="$TEST_DIR/overrides/my_module/web-build/pre.Dockerfile"
  local dest="$TEST_DIR/workspace/my_module/.ddev/web-build/pre.Dockerfile"
  mkdir -p "$fake_bin" "$TEST_DIR/workspace/my_module/.ddev" \
    "$TEST_DIR/overrides/my_module/web-build"
  echo "DRUPAL_CORE=^11.2" > "$TEST_DIR/workspace/my_module/.ddev/.env.web"

  cat > "$fake_bin/git" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  cat > "$fake_bin/ddev" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  chmod +x "$fake_bin/git" "$fake_bin/ddev"

  echo "RUN echo hi" > "$src"

  PATH="$fake_bin:/usr/bin:/bin" run "$TEST_DIR/setup_contrib" --mn=my_module --si --dir="$TEST_DIR/workspace"
  [ "$status" -eq 0 ]
  [[ "$output" == *"copying web-build file pre.Dockerfile"* ]]

  # Unchanged rerun: same content, should be skipped, not recopied.
  PATH="$fake_bin:/usr/bin:/bin" run "$TEST_DIR/setup_contrib" --mn=my_module --si --dir="$TEST_DIR/workspace"
  [ "$status" -eq 0 ]
  [[ "$output" != *"copying web-build file pre.Dockerfile"* ]]
  grep -qF "RUN echo hi" "$dest"

  # Changed source: should be recopied.
  echo "RUN echo changed" > "$src"
  PATH="$fake_bin:/usr/bin:/bin" run "$TEST_DIR/setup_contrib" --mn=my_module --si --dir="$TEST_DIR/workspace"
  [ "$status" -eq 0 ]
  [[ "$output" == *"copying web-build file pre.Dockerfile"* ]]
  grep -qF "RUN echo changed" "$dest"
}

@test "rerun against an already-configured project skips add-on/repo/plugin setup and the second symlink" {
  local fake_bin="$TEST_DIR/fake_bin"
  local ddev_log="$TEST_DIR/ddev.log"
  local mod="$TEST_DIR/workspace/my_module"
  mkdir -p "$fake_bin" "$mod/.ddev/addon-metadata/ddev-drupal-contrib" "$mod/vendor"
  touch "$mod/vendor/autoload.php"
  echo "DRUPAL_CORE=^11.2" > "$mod/.ddev/.env.web"

  cat > "$mod/composer.json" <<'JSON'
{
    "require": {
        "drush/drush": "^13"
    },
    "config": {
        "allow-plugins": {
            "php-http/discovery": true,
            "tbachert/spi": true,
            "phpstan/extension-installer": true,
            "symfony/runtime": true,
            "drupal/core-composer-scaffold": true,
            "composer/installers": true,
            "dealerdirect/phpcodesniffer-composer-installer": true,
            "cweagans/composer-patches": true
        }
    },
    "repositories": {
        "drupal": {
            "type": "composer",
            "url": "https://packages.drupal.org/8"
        }
    }
}
JSON

  cat > "$fake_bin/git" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  cat > "$fake_bin/ddev" <<STUB
#!/usr/bin/env bash
echo "ddev \$*" >> "$ddev_log"
exit 0
STUB
  chmod +x "$fake_bin/git" "$fake_bin/ddev"

  PATH="$fake_bin:/usr/bin:/bin" run "$TEST_DIR/setup_contrib" --mn=my_module --si --dir="$TEST_DIR/workspace"

  [ "$status" -eq 0 ]
  ! grep -qF "add-on get" "$ddev_log"
  ! grep -qF "composer config repositories.drupal" "$ddev_log"
  ! grep -qF "composer config allow-plugins" "$ddev_log"
  ! grep -qF "symlink-project" "$ddev_log"
  grep -qF "poser" "$ddev_log"
}

@test "passing --as forces the add-on to be refetched even if already installed" {
  local fake_bin="$TEST_DIR/fake_bin"
  local ddev_log="$TEST_DIR/ddev.log"
  local mod="$TEST_DIR/workspace/my_module"
  mkdir -p "$fake_bin" "$mod/.ddev/addon-metadata/ddev-drupal-contrib"
  echo "DRUPAL_CORE=^11.2" > "$mod/.ddev/.env.web"

  cat > "$fake_bin/git" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  cat > "$fake_bin/ddev" <<STUB
#!/usr/bin/env bash
echo "ddev \$*" >> "$ddev_log"
exit 0
STUB
  chmod +x "$fake_bin/git" "$fake_bin/ddev"

  PATH="$fake_bin:/usr/bin:/bin" run "$TEST_DIR/setup_contrib" --mn=my_module --si --dir="$TEST_DIR/workspace" \
    --as=https://github.com/tormi/ddev-drupal-contrib/tarball/GH-177

  [ "$status" -eq 0 ]
  grep -qF "add-on get https://github.com/tormi/ddev-drupal-contrib/tarball/GH-177" "$ddev_log"
}

@test "--profile is passed to site:install, defaulting to standard" {
  local fake_bin="$TEST_DIR/fake_bin"
  local ddev_log="$TEST_DIR/ddev.log"
  mkdir -p "$fake_bin" "$TEST_DIR/workspace/my_module/.ddev"
  echo "DRUPAL_CORE=^11.2" > "$TEST_DIR/workspace/my_module/.ddev/.env.web"

  cat > "$fake_bin/git" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  cat > "$fake_bin/ddev" <<STUB
#!/usr/bin/env bash
echo "ddev \$*" >> "$ddev_log"
exit 0
STUB
  chmod +x "$fake_bin/git" "$fake_bin/ddev"

  PATH="$fake_bin:/usr/bin:/bin" run "$TEST_DIR/setup_contrib" --mn=my_module --dir="$TEST_DIR/workspace"
  [ "$status" -eq 0 ]
  grep -qF "site:install standard" "$ddev_log"

  : > "$ddev_log"
  PATH="$fake_bin:/usr/bin:/bin" run "$TEST_DIR/setup_contrib" --mn=my_module --dir="$TEST_DIR/workspace" --profile=minimal
  [ "$status" -eq 0 ]
  grep -qF "site:install minimal" "$ddev_log"
}

@test "recipes.txt: packages are required and applied with drush recipe, not pm:enable" {
  local fake_bin="$TEST_DIR/fake_bin"
  local ddev_log="$TEST_DIR/ddev.log"
  mkdir -p "$fake_bin" "$TEST_DIR/workspace/my_module/.ddev" "$TEST_DIR/overrides/my_module"
  echo "DRUPAL_CORE=^11.2" > "$TEST_DIR/workspace/my_module/.ddev/.env.web"

  cat > "$fake_bin/git" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  cat > "$fake_bin/ddev" <<STUB
#!/usr/bin/env bash
echo "ddev \$*" >> "$ddev_log"
exit 0
STUB
  chmod +x "$fake_bin/git" "$fake_bin/ddev"

  cat > "$TEST_DIR/overrides/my_module/recipes.txt" <<'LIST'
drupal/byte
LIST

  PATH="$fake_bin:/usr/bin:/bin" run "$TEST_DIR/setup_contrib" --mn=my_module --si --dir="$TEST_DIR/workspace"

  [ "$status" -eq 0 ]
  grep -qF "composer require --no-update --quiet drupal/byte --no-interaction" "$ddev_log"
  grep -qF "drush recipe ../recipes/byte -y" "$ddev_log"
  ! grep -qF "pm:enable byte" "$ddev_log"
}

@test "recipes.txt is applied on a --si rerun, and coexists with other-modules.txt" {
  local fake_bin="$TEST_DIR/fake_bin"
  local ddev_log="$TEST_DIR/ddev.log"
  mkdir -p "$fake_bin" "$TEST_DIR/workspace/my_module/.ddev" "$TEST_DIR/overrides/my_module"
  echo "DRUPAL_CORE=^11.2" > "$TEST_DIR/workspace/my_module/.ddev/.env.web"

  cat > "$fake_bin/git" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  cat > "$fake_bin/ddev" <<STUB
#!/usr/bin/env bash
echo "ddev \$*" >> "$ddev_log"
exit 0
STUB
  chmod +x "$fake_bin/git" "$fake_bin/ddev"

  echo "drupal/ai_provider_openai" > "$TEST_DIR/overrides/my_module/other-modules.txt"
  echo "drupal/byte" > "$TEST_DIR/overrides/my_module/recipes.txt"

  PATH="$fake_bin:/usr/bin:/bin" run "$TEST_DIR/setup_contrib" --mn=my_module --si --dir="$TEST_DIR/workspace"

  [ "$status" -eq 0 ]
  grep -qF "pm:enable ai_provider_openai -y" "$ddev_log"
  grep -qF "drush recipe ../recipes/byte -y" "$ddev_log"
}
