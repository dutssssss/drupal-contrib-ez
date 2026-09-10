# How it works

The add-on sets up the DDEV environment itself: the docker containers, and
DDEV commands like `ddev poser` (installs composer dependencies) and
`ddev symlink-project` (links the module into the site's codebase). It
doesn't know anything about Drupal versions or your specific module.

After the add-on is installed, there are still several manual steps before
you have a working site:

1. Work out which Drush version matches your Drupal core version.
2. Add the `packages.drupal.org` composer repository.
3. Approve the composer plugins Drupal projects commonly need.
4. Set `DRUPAL_CORE` in `.ddev/.env.web`.
5. Run `drush site:install` and `drush pm:enable` for your module.

`setup_contrib` runs through those steps in order, so you don't have to do
them by hand each time you set up a new module.

The site install itself is Drupal's standard install profile, the same one
`drush site:install` defaults to on a fresh site: no custom profile, no
recipes, just the usual out-of-the-box content types, views, and blocks.

`setup_contrib` and `dispose_contrib` treat the folder they're sitting in as
your contrib workspace. Every module ends up next to them:

```
ddev-contrib-ez/
  setup_contrib
  dispose_contrib
  webform/
  other_contrib_module/
```

If a module isn't there yet, `setup_contrib` clones it from drupal.org for
you. Already have it checked out, say a fork or a patched local copy, just
put it there yourself first and the script leaves it alone. Same if the
module isn't on drupal.org at all, a sandbox or a private module: clone it
in yourself and the script picks it up from there.
