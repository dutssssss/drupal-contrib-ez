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
