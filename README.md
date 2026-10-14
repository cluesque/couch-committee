# Couch Committee

![Logo](public/logo_with_name.png)

Couch Committee helps a household (or any small group) agree on what to watch next. Add
movies and show seasons to a shared playlist, reorder them, and check things off as you watch
them together — no more scrolling every streaming app arguing about it.

## Status

Early days — scaffolding (Phase 0) and Google sign-in (Phase 1) are done; groups and playlists
come next. See
[`docs/implementation-plan.md`](docs/implementation-plan.md) for the roadmap, and
[`docs/architecture.md`](docs/architecture.md) / [`docs/data-model.md`](docs/data-model.md) for
the design.

## Tech stack

- Ruby on Rails, with Hotwire (Turbo + Stimulus) and as little custom JavaScript as possible
- Bootstrap for styling
- SQLite in development and test, keeping schema/migrations Postgres-compatible
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
