# ddev-contrib-ez

A script that sets up a local DDEV site for a Drupal contrib module. It's a
wrapper around the
[`ddev-drupal-contrib`](https://github.com/ddev/ddev-drupal-contrib) add-on.

This is for throwaway environments, not production sites. If you just want
to poke at a contrib module, try out a feature, or reproduce an issue before
filing it, this gets you a running site fast without setting any of it up by
hand. You don't need to know Drupal internals, DDEV, or shell scripting to
use it, just follow the steps below.

## Requirements

- [DDEV](https://ddev.com), which needs Docker. DDEV's own install guide
  covers installing Docker too if you don't have it.
- `git`, usually already on your machine. Check with `git --version` in a
  terminal.

## Step by step

This walks through getting a working site for the `webform` module from a
blank machine.

1. Install [DDEV](https://ddev.com/get-started/) (link above). DDEV runs a
   local Drupal site inside Docker containers, so you don't have to install
   PHP, a database, or anything else by hand.

2. Get this repo:

   ```
   git clone https://github.com/rodzy03/ddev-contrib-ez.git
   cd ddev-contrib-ez
   ```

3. Run the setup script, telling it which module you want and which
   version of Drupal core to build the site on:

   ```
   ./setup_contrib --mn=webform --cv=^11.2
   ```

   `--mn` is the module's machine name, the short lowercase name in its
   drupal.org project URL (`drupal.org/project/webform` → `webform`).
   `--cv` is a Drupal core version constraint, `^11.2` means "11.2 or any
   later 11.x release."

   The script downloads the `webform` module, builds a Drupal site around
   it, and installs the site. The first run takes a few minutes, Docker
   images and composer dependencies have to download.

4. When it finishes, open the site in your browser:

   ```
   ddev launch
   ```

   Log in with username `admin`, password `admin`. The `webform` module is
   already enabled and ready to try.

5. When you're done and want the disk space and containers back, remove
   everything the script created:

   ```
   ./dispose_contrib --m=webform
   ```

   It asks you to type `webform` again to confirm, then deletes the DDEV
   project and the module's files. This can't be undone.

That's the whole workflow: `setup_contrib` to spin a module up,
`dispose_contrib` to tear it back down. See [Documentation](#documentation)
below for more specific cases, a different module, extra dependencies, an
unmerged add-on branch, and how it all works under the hood.

## Documentation

- [How it works](docs/how-it-works.md), what the add-on sets up versus what
  `setup_contrib` layers on top, and how the workspace is laid out.
- [Reference](docs/reference.md), full `setup_contrib`/`dispose_contrib`
  flags, getting just the scripts without cloning the repo, and running the
  tests.
- [Advanced examples: overrides/](docs/advanced-example.md), extra composer
  packages for a module, and custom `.ddev/web-build/` files like a
  `pre.Dockerfile` or a CA cert.
- [overrides/README.md](overrides/README.md), how the local, gitignored
  `overrides/` folder is laid out.

## License

MIT, see [LICENSE](LICENSE)
