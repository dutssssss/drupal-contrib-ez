# Advanced examples: overrides/

Both examples below use `overrides/`, a local, gitignored folder for
per-module stuff that doesn't belong in this repo. See
[`overrides/README.md`](../overrides/README.md) for the full layout.

## Extra composer dependencies

Setting up the `ai` module with the OpenAI provider pulled in automatically:

```
mkdir -p overrides/ai
```

`overrides/ai/other-modules.txt`:

```
drupal/ai_provider_openai
drupal/ai_provider_anthropic:^1.0
```

```
./setup_contrib --mn=ai --cv=^11.2
```

What that does:

1. `ai` doesn't exist yet in the workspace, so it's cloned from
   `https://git.drupalcode.org/project/ai.git`.
2. `overrides/ai/other-modules.txt` exists, so both packages listed in it
   get required alongside `ai` itself.
3. DDEV starts, Drush is installed at the version that matches core `^11.2`,
   the site gets installed, and `ai`, `ai_provider_openai`, and
   `ai_provider_anthropic` all get enabled.

Then open the site:

```
ddev launch
```

### Adding or updating a dependency later

Say you set up `ai` a while ago and now want to add a third provider,
without touching Drupal core version or redoing the install.

1. Open `overrides/ai/other-modules.txt` (create it if it doesn't exist
   yet) and add the package on its own line:

   ```
   drupal/ai_provider_openai
   drupal/ai_provider_anthropic:^1.0
   drupal/ai_provider_groq
   ```

2. Rerun the same way you always do, just without `--cv`:

   ```
   ./setup_contrib --mn=ai --si
   ```

   `ai_provider_groq` is the only thing that actually changes here, the
   other two lines are already required and get skipped as no-ops.

3. Confirm it's enabled:

   ```
   ddev drush pm:list --status=enabled | grep ai_provider_groq
   ```

Removing a line from the file and rerunning does not uninstall or disable
the module, it only stops requiring it on future runs. Disable and remove
it yourself first if you want it gone:

```
ddev drush pm:uninstall ai_provider_groq -y
ddev composer remove drupal/ai_provider_groq
```

## Custom web-build files: trusting a proxy's CA cert

Some networks (a corporate proxy, a Cloudflare Zero Trust gateway) do TLS
inspection, so composer and npm inside the DDEV container need to trust
that proxy's CA cert or their requests fail. DDEV supports a
`.ddev/web-build/pre.Dockerfile` for exactly this, it runs before DDEV's
own web image layer. `overrides/<module>/web-build/` is where you put the
files for that, and `setup_contrib` copies them into `.ddev/web-build/`
before `ddev start`.

```
mkdir -p overrides/ai_context/web-build
cp cloudflare-ca.crt overrides/ai_context/web-build/
```

`overrides/ai_context/web-build/pre.Dockerfile`:

```
COPY cloudflare-ca.crt /usr/local/share/ca-certificates/cloudflare-ca.crt
RUN update-ca-certificates
```

```
./setup_contrib --mn=ai_context --cv=^11.2
```

Both files land in `ai_context/.ddev/web-build/` before DDEV builds the web
image, so the cert is trusted from the first `ddev start` on. See
[DDEV's image customization docs](https://docs.ddev.com/en/stable/users/extend/customizing-images/)
for the full `pre.Dockerfile`/`Dockerfile`/`post.Dockerfile` build order.

Changed a file in `overrides/<module>/web-build/`? Rerun the same command,
`setup_contrib` compares each file's contents against what's already in
`.ddev/web-build/` and only copies the ones that actually differ, so DDEV
only rebuilds the image when something genuinely changed, not on every
rerun. Removing a file from the overrides folder doesn't remove it from the
project's `.ddev/web-build/`, delete it there yourself if you want it gone.
