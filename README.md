# Couch Committee

![Logo](public/logo_with_name.png)

Couch Committee helps a household (or any small group) agree on what to watch next. Add
movies and show seasons to a shared playlist, reorder them, and check things off as you watch
them together — no more scrolling every streaming app arguing about it.

## Status

Early days — Phase 0 (project scaffolding) is done. Phase 1 (Google sign-in) is next. See
[`docs/implementation-plan.md`](docs/implementation-plan.md) for the roadmap, and
[`docs/architecture.md`](docs/architecture.md) / [`docs/data-model.md`](docs/data-model.md) for
the design.

## Tech stack

- Ruby on Rails, with Hotwire (Turbo + Stimulus) and as little custom JavaScript as possible
- Bootstrap for styling
- SQLite in development and test, keeping schema/migrations Postgres-compatible
- Google OAuth via `google_sign_in` (coming in Phase 1)
- Minitest, with Capybara + Cuprite (headless Chromium) for system tests
- Brakeman, bundler-audit, and RuboCop in CI

## Getting started

```bash
bin/setup
```

This installs gems, prepares the database, and starts the dev server (`bin/dev`).

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
