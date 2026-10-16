# Couch Committee

![Logo](public/logo_with_name.png)

Couch Committee helps a household (or any small group) agree on what to watch next. Add
movies and show seasons to a shared list, reorder them, and check things off as you watch
them together — no more scrolling every streaming app arguing about it.

## Status

Every phase of [`docs/implementation-plan.md`](docs/implementation-plan.md) is done: groups,
lists, adding titles, drag-to-reorder, recording watches, history, cancelling, rewatching, and
a phone-width polish pass. The plan's "Explicitly deferred" list is what's next. See
[`docs/architecture.md`](docs/architecture.md) / [`docs/data-model.md`](docs/data-model.md) for
the design.

## Tech stack

- Ruby on Rails, with Hotwire (Turbo + Stimulus) and as little custom JavaScript as possible
- Bootstrap for styling
- SQLite everywhere, production included, keeping schema/migrations Postgres-compatible
- Google sign-in via `google_sign_in`; there are no passwords
- Minitest, with Capybara + Cuprite (headless Chromium) for system tests
- Brakeman, bundler-audit, and RuboCop in CI

## Getting started

```bash
bin/setup
```

This installs gems, prepares the database, and starts the dev server (`bin/dev`).

### Google sign-in credentials

Signing in needs a Google OAuth client. Tests don't (they fake Google), so this is only needed
to run the app.

1. In the [Google Cloud console](https://console.cloud.google.com/apis/credentials), configure
   the OAuth consent screen, then create an **OAuth client ID** of type **Web application**.
2. Add `http://localhost:3000/google_sign_in/callback` as an authorized redirect URI (plus the
   equivalent URL for each deployed host).
3. Add the client's ID and secret to the app's credentials with `bin/rails credentials:edit`:

   ```yaml
   google_sign_in:
     client_id: 1234-abcd.apps.googleusercontent.com
     client_secret: your-client-secret
   ```

Anyone with a Google account can sign in; what they can see is limited by group membership.

### TMDB credentials

Titles (movies, shows, seasons, episodes) come from [TMDB](https://www.themoviedb.org/). Running
the app needs a TMDB "API Read Access Token" (free with a TMDB account, under Settings → API).
Tests don't need one: they answer TMDB's requests from recorded responses in
`test/fixtures/files/tmdb/`. Add the token with `bin/rails credentials:edit`:

```yaml
tmdb:
  api_read_access_token: eyJhbGciOi...
```

Production reads it from the same credentials file, so it needs no extra Fly secret.

## Deploying to Fly.io

The app runs on [Fly.io](https://fly.io) as a single machine, with its SQLite database on a
persistent volume. `fly.toml` holds the configuration. These steps are one-time setup.

Don't run `fly launch`: this repo already has a Dockerfile and `fly.toml`, and `fly launch` would
try to regenerate them.

1. Install `flyctl` and sign in:

   ```bash
   brew install flyctl
   fly auth login
   ```

2. Pick an app name (it must be unique across Fly) and a region near you (`fly platform regions`
   lists them). Set `app` and `primary_region` in `fly.toml`, then create the app:

   ```bash
   fly apps create <app-name>
   ```

3. Create the volume for the database, in that same region. The name must match `[[mounts]]` in
   `fly.toml`:

   ```bash
   fly volumes create couch_committee_data --region <region> --size 1
   ```

   Fly warns that a single volume has no redundancy. That's expected with SQLite. Fly snapshots
   volumes daily and keeps the snapshots for 5 days.

4. Give the app the key that decrypts `config/credentials.yml.enc` (which holds the Google client
   ID and secret):

   ```bash
   fly secrets set RAILS_MASTER_KEY="$(cat config/master.key)"
   ```

5. In the [Google Cloud console](https://console.cloud.google.com/apis/credentials), add
   `https://<app-name>.fly.dev/google_sign_in/callback` to the OAuth client's authorized redirect
   URIs. If the OAuth consent screen is still in **Testing**, only the test users listed there can
   sign in. Add your household, or publish the app.

6. Deploy, and open it:

   ```bash
   fly deploy --ha=false
   fly apps open
   ```

   Every boot runs `bin/rails db:prepare` (see `bin/docker-entrypoint`). That creates the database
   on the first deploy and runs any new migrations on later ones.

After that, `fly deploy` ships a new version. Some other useful commands:

```bash
fly logs                                                   # tail the app's logs
fly ssh console --user rails -C "/rails/bin/rails console" # a production console
fly volumes list                                           # the database volume and its ID
```

Run the console as the `rails` user, as above. As root, it could create database files the app
can't write to.

### Backups

To take a copy of the production data offline and restore it into your development database:

1. Take a snapshot on the server and download it. The app runs SQLite in WAL mode, so copying
   `production.sqlite3` directly can miss recent writes or catch it mid-change. SQLite's `.backup`
   makes a consistent copy even while the app is running.

   ```bash
   fly ssh console -C "sqlite3 /rails/storage/production.sqlite3 '.backup /tmp/backup.sqlite3'"
   mkdir -p backups
   fly ssh sftp get /tmp/backup.sqlite3 backups/couch-committee-$(date +%F).sqlite3
   fly ssh console -C "rm /tmp/backup.sqlite3"
   ```

   The machine stops when idle. If `fly ssh` can't connect, open the app (or run
   `fly machine start`) first.

2. Restore it locally, with the development server stopped:

   ```bash
   cp backups/couch-committee-YYYY-MM-DD.sqlite3 storage/development.sqlite3
   bin/rails db:environment:set RAILS_ENV=development   # the copy is marked "production"
   bin/rails db:migrate                                 # in case your branch has newer migrations
   ```

`backups/` is gitignored: the copies contain real names and email addresses, so keep them
somewhere private.

Fly also snapshots the volume daily and keeps snapshots for 5 days (`fly volumes snapshots list
<volume-id>`). Those stay on Fly and restore only as a new volume, so they're for undoing a bad
day on the server, not for offline copies.

## Running tests

```bash
bin/rails test           # unit/integration tests
bin/rails test:system    # system tests (needs Chromium; set BROWSER_PATH if it's not on PATH)
```

## Linting & security scans

```bash
bin/rubocop
bin/brakeman
bin/bundler-audit
bin/importmap audit
```
