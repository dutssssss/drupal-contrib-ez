# Reference

## Get just the scripts

If you don't want the whole repo, just the scripts work fine, dropped
anywhere you want your contrib workspace to live:

```
curl -O https://raw.githubusercontent.com/rodzy03/ddev-contrib-ez/main/setup_contrib
curl -O https://raw.githubusercontent.com/rodzy03/ddev-contrib-ez/main/dispose_contrib
chmod +x setup_contrib dispose_contrib
```

You lose the `overrides/` folder this way, see
[`overrides/README.md`](../overrides/README.md).

## setup_contrib flags

```
setup_contrib --mn=<name> [--cv=<constraint>] [options]

  e.g.: setup_contrib --mn=contrib_module_name --cv=^11.2
        setup_contrib --mn=contrib_module_name --cv=^11.2 --as=https://github.com/<username>/ddev-drupal-contrib/tarball/GH-XX
        setup_contrib --mn=contrib_module_name --cv=^11.2 --si
        setup_contrib --mn=contrib_module_name --si
        setup_contrib --mn=contrib_module_name --cv=^11.2 --pn=contrib_module_name-scratch --dir=~/sites/projects/contribs
```

| Flag                | Required | Description                                                                                                                              |
|---------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------|
| `--mn=<name>`       | Yes      | Module name, the Drupal contrib module machine name.                                                                                      |
| `--cv=<constraint>` | No       | Core version, a Drupal core version constraint, e.g. `^11.2`. Required the first time you set up a module. On a rerun, it's read back from the existing `.ddev/.env.web`, so it can be left out. |
| `--as=<source>`     | No       | Addon source, passed to `ddev add-on get`. Defaults to `ddev/ddev-drupal-contrib`. Pass a tarball URL to try an unmerged branch or PR instead. |
| `--si`              | No       | Skip install, skips `drush site:install` and `drush pm:enable`. Use this if you're rerunning against a project that already has a site, since `site:install` would otherwise wipe its database. |
| `--pn=<name>`       | No       | Project name, the DDEV project name. Defaults to whatever `ddev config` derives from the module directory name. DDEV's project registry is global, not per-directory, so set this if you're checking out the same module more than once and the default name would collide with an existing project. |
| `--dir=<path>`      | No       | Directory to clone/look for the module in, instead of the directory `setup_contrib` is sitting in. Must already exist. Supports a leading `~`. Only affects where the module's code and DDEV project live, `overrides/` is always read from next to `setup_contrib` itself, see [`overrides/README.md`](../overrides/README.md). |
| `--profile=<name>`  | No       | Install profile passed to `drush site:install`. Defaults to `standard`. Recipe-based setups, e.g. Drupal CMS site templates, often expect `minimal` instead. |

Rerunning `setup_contrib --mn=<name> --si` against a project that already
exists (no `--cv` needed) is also how you pick up a new entry added to
`overrides/<name>/other-modules.txt`: every line in that file gets required
again on each run, so adding a package and rerunning is enough, nothing
needs deleting or resetting first.

That rerun is faster than the first run, too. Once a project already has
the `ddev-drupal-contrib` add-on installed, the drupal.org composer
repository configured, and its composer plugins approved, `setup_contrib`
skips redoing those (`--as` forces a refetch of the add-on if you need one).
`ddev poser` and the `other-modules.txt` pass still run every time, so new
dependencies get installed and enabled on a rerun.

Packages under the `drupal/` vendor namespace also get `drush pm:enable`'d
automatically, using the part after `drupal/` as the module machine name
(`drupal/ai_provider_openai:^1.0` → `ai_provider_openai`). This is a guess,
not a guarantee: some packages contain more than one module, or none at all.
If a guess doesn't match a real module, that one enable is skipped with a
warning rather than failing the whole run, and you can enable the right
module yourself. Packages outside the `drupal/` namespace are never treated
as enable candidates.

Packages listed in `overrides/<module>/recipes.txt` are composer-required
the same way, but aren't modules, so they're never `pm:enable`'d. Instead,
each one is applied with `drush recipe ../recipes/<name>` (again using the
part after `drupal/` as `<name>`), right after `site:install` and *before*
the main module and `other-modules.txt`'s modules get `pm:enable`'d. A
recipe can enable modules itself as part of its own dependency graph and
establish their config canonically; enabling those modules separately
first and applying the recipe afterward risks the reverse, a module's own
default config conflicting with the recipe's import. Recipes are designed
to be applied idempotently, so this step also runs on a `--si` rerun, the
same "add a line, rerun" workflow described above for `other-modules.txt`.

## setup_cms flags

```
setup_cms --mn=<name> [options]

  e.g.: setup_cms --mn=canvas
        setup_cms --mn=canvas --template=starter --si
```

| Flag                | Required | Description                                                                                                                              |
|---------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------|
| `--mn=<name>`       | Yes      | Name for this environment: the DDEV project/directory name, and the key for `overrides/<name>/`.                                          |
| `--template=<name>` | No       | Site template recipe to install from, e.g. `byte`, `starter`, `haven`. Defaults to `byte`.                                                 |
| `--cv=<constraint>` | No       | Version constraint for `drupal/cms` itself, e.g. `^2.1`. Only used the first time; on a rerun the project already exists.                 |
| `--si`              | No       | Skip `site:install`, for rerunning against a project that already has a site (avoids wiping the DB).                                      |
| `--pn=<name>`       | No       | DDEV project name. Defaults to whatever `ddev config` derives from the directory name.                                                     |
| `--dir=<path>`      | No       | Directory to create/look for the project in, instead of next to this script. Must already exist.                                          |

Unlike `setup_contrib`, this doesn't clone a single module's git checkout
ahead of time — it builds a whole Drupal CMS project from composer packages,
which is what a site template recipe actually needs (see `--help` output for
why). Composer's `preferred-install` is forced to `source`, so every package
it installs — e.g. `web/modules/contrib/canvas` — is still a real git
checkout with upstream history, not a dist zip, just installed as part of
the whole-project build rather than cloned up front. This is slower and uses
more disk than a plain dist install.

`overrides/<name>/other-modules.txt`, `recipes.txt`, and `web-build/` are
picked up the same way as `setup_contrib`; `recipes.txt` here layers *extra*
recipes on top of the site template, it isn't the template itself (that's
`--template`).

Tear down with `dispose_contrib --mn=<name>` (same `--dir` if used) — it
only cares about the DDEV project and directory, not how they were built.

## dispose_contrib flags

`dispose_contrib` tears down what `setup_contrib` created: the DDEV project
(containers, database, DDEV config) and the module directory itself. It asks
for confirmation before deleting anything, so it needs an interactive
terminal.

It only ever acts on the DDEV project defined inside that module's own
directory, never a project name lookup. An unrelated DDEV project elsewhere
on your machine that happens to share the same name is untouched, even if
it's currently running.

```
dispose_contrib --mn=<name> [options]

  e.g.: dispose_contrib --mn=contrib_module_name
        dispose_contrib --mn=contrib_module_name --dir=~/sites/projects/contribs
```

| Flag           | Required | Description                                            |
|----------------|----------|-------------------------------------------------------|
| `--mn=<name>`   | Yes      | Module name, the same one passed to `setup_contrib`'s `--mn`. |
| `--dir=<path>` | No       | Directory the module is in, if you ran `setup_contrib` with `--dir`. Defaults to the directory this script is sitting in. Must already exist. Supports a leading `~`. |

This is permanent. There's no `--yes` to skip the prompt.

## Testing

```
bats tests/
```

Covers argument parsing and validation for both scripts, the flags, the
required checks, the module-name format. It doesn't cover the actual `ddev`
provisioning or deletion steps, those need real Docker to run and aren't
practical to test this way.

Needs [bats-core](https://github.com/bats-core/bats-core), only for running
the tests.
