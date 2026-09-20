# overrides/

Drop your own per-module stuff here. It's gitignored, so it's yours only,
nothing you'd commit or push.

One folder per module, named after the module directory:

```
overrides/
  my_module/
    other-modules.txt     # extra composer packages, picked up automatically
    recipes.txt           # recipe packages, composer-required and applied with `drush recipe`
    web-build/            # extra .ddev/web-build/ files, copied in before ddev start
```

No flag needed, the script checks for `overrides/<module>/other-modules.txt`,
`overrides/<module>/recipes.txt`, and `overrides/<module>/web-build/` on its
own:

```
setup_contrib --mn=my_module --cv=^11.2
```

This `overrides/` folder, next to `setup_contrib` itself, is always where
it looks, regardless of `--dir`. Point `--dir` at a workspace anywhere else
on disk and your overrides still apply, they don't need to be copied into
that workspace too.

`other-modules.txt` is a plain list, one composer package per line, blank
lines and `#` comments ignored:

```
drupal/some_dependency
drupal/another_dependency:^2.0
```

`recipes.txt` is the same plain-list format, but for recipe packages, e.g.
Drupal CMS site templates:

```
drupal/byte
```

Each package is composer-required the same way as `other-modules.txt`, but
applied with `drush recipe ../recipes/<name>` instead of `pm:enable`, since
recipes aren't modules, see [`docs/reference.md`](../docs/reference.md) for
details. Recipes are meant to be reapplied safely, so this also runs on a
`--si` rerun.

`web-build/` is a folder, not a file: whatever is in it gets copied into
the project's `.ddev/web-build/` before `ddev start`, so DDEV's own web
image build picks it up, a `pre.Dockerfile`, a CA cert to trust, that kind
of thing.

See [`docs/advanced-example.md`](../docs/advanced-example.md) for both of
these worked through with real cases (`ai`'s provider packages, and a
`pre.Dockerfile` that trusts a proxy's CA cert), and
[`docs/reference.md`](../docs/reference.md)'s `setup_contrib` flags section
for what happens to each `other-modules.txt` package (auto-enabled or not)
and why `--cv` isn't needed on a rerun.

This file is the only thing under `overrides/` that's actually tracked.
