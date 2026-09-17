# ddev-contrib-ez

**A simple script that sets up a local DDEV site for a Drupal contrib module.**

`ddev-contrib-ez` is a small wrapper around the
[`ddev-drupal-contrib`](https://github.com/ddev/ddev-drupal-contrib) add-on
that automates the Drupal-specific setup needed to try out a contrib module
locally.

It is designed for **throwaway development environments**, not production
sites. Use it when you want to quickly explore a contrib module, test a
feature, or reproduce an issue before filing it, without having to set
everything up by hand.

## Requirements

* [DDEV](https://ddev.com/) — DDEV uses Docker to run the local site. See
  [DDEV's installation guide](https://ddev.com/get-started/) if you haven't
  installed it yet.
* `git` — usually already installed. Check with:

  ```bash
  git --version
  ```

## Quick start

The following example sets up a local Drupal site for the `webform` module.

### 1. Clone this repository

```bash
git clone https://github.com/rodzy03/ddev-contrib-ez.git
cd ddev-contrib-ez
```

### 2. Set up a contrib module

Run `setup_contrib` with the module's machine name and the Drupal core
version you want to use:

```bash
./setup_contrib --mn=webform --cv=^11.2
```

Where:

* `--mn` is the module's **machine name**, as used by the module on
  [drupal.org](https://www.drupal.org/).
* `--cv` is the **Drupal core version constraint** to use for the test site,
  such as `^11.2`.
* `--dir` (optional) is the directory to clone/look for the module in,
  instead of next to `setup_contrib` itself. Must already exist.

The script will:

1. Download the contrib module.
2. Create the DDEV project.
3. Set up the Drupal dependencies.
4. Build and install Drupal.
5. Enable the contrib module.

When it finishes, you'll have a running Drupal site with the module ready to
test.

### 3. Log in

Use the default development account:

```text
Username: admin
Password: admin
```

The requested contrib module is already enabled.

### 4. Tear it down

When you're finished, remove the test environment and its files:

```bash
./dispose_contrib --mn=webform
```

If you ran `setup_contrib` with `--dir`, pass the same `--dir` here too, so
`dispose_contrib` can find the module directory.

You'll be asked to type `webform` again to confirm. The script then removes
the DDEV project and the module's files.

**This is permanent and cannot be undone.**

That's the whole workflow:

```text
setup_contrib  →  try the module  →  dispose_contrib
```

## Documentation

For more specific use cases and details:

* [How it works](docs/how-it-works.md) — what `ddev-drupal-contrib` sets up,
  what `setup_contrib` adds on top, and how the workspace is structured.
* [Reference](docs/reference.md) — complete `setup_contrib` and
  `dispose_contrib` options, using the scripts without cloning the repository,
  and running the test suite.
* [Advanced examples](docs/advanced-example.md) — adding Composer
  dependencies, using an unmerged add-on branch, and customizing
  `.ddev/web-build/` with files such as `pre.Dockerfile` or a CA certificate.
* [Local overrides](overrides/README.md) — how to use the gitignored
  `overrides/` directory for local customizations.

## Why use this?

The `ddev-drupal-contrib` add-on provides the foundation for working with
Drupal contrib projects in DDEV. `ddev-contrib-ez` adds the remaining
Drupal-specific setup needed to turn that environment into a ready-to-use
test site.

The goal is simple: **clone, run one command, and start testing.**

## License

MIT — see [LICENSE](LICENSE).
