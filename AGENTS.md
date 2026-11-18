# AGENTS.md

Couch Committee is a small Rails app that helps a household agree on what to watch next. People
share lists of movies and show seasons, reorder them, and record what they watch. Start with
`README.md` for setup and deployment. The design lives in `docs/`:

- `docs/architecture.md`: stack choices and key structural decisions, with the reasoning
- `docs/data-model.md`: every model, its columns, and its behavior rules (states, rewatching,
  sign-in matching)
- `docs/implementation-plan.md`: the phased build history and the "Explicitly deferred" list
- `docs/title-metadata.md`: why TMDB, and how importing from it works

Read the relevant doc before changing behavior, and update it in the same change when behavior or
structure changes. The docs describe the app as it is now, not as it once was.

## Guiding principle

"Clean, simple architecture, nothing super fancy." Use plain Rails wherever it is enough. Don't
add gems, frameworks, or JavaScript unless they're clearly needed, and say why when you do.

## Stack

- Ruby (see `.ruby-version`) and Rails 8.1, with Propshaft and importmap. There's no Node toolchain.
- Hotwire: Turbo Drive and Frames, plus Stimulus. There are no Turbo Streams yet.
- Bootstrap 5, compiled by `dartsass-rails` from `app/assets/stylesheets/application.scss`.
- SQLite in every environment, production included.
- Google sign-in through Basecamp's `google_sign_in`. There are no passwords.
- TMDB for title metadata (`app/services/tmdb/`).
- Minitest with `factory_bot_rails`, and Capybara with Cuprite (headless Chromium) for system tests.
- Deployed to Fly.io as a single machine (`fly.toml`, `Dockerfile`).

## Commands

```bash
bin/setup                  # install gems, prepare the DB, start bin/dev (--skip-server to not start it)
bin/dev                    # Rails server on :3000 plus the Sass watcher (Procfile.dev)
bin/rails test             # unit, model, service, controller, integration tests
bin/rails test test/models/list_entry_test.rb:42   # a single file or test
bin/rails test:system      # system tests; needs Chromium (set BROWSER_PATH if it's not on PATH)
bin/rubocop                # style (rubocop-rails-omakase); bin/rubocop -a to autocorrect
bin/brakeman --no-pager    # security static analysis
bin/bundler-audit          # gem vulnerabilities
bin/importmap audit        # JS dependency vulnerabilities
bin/ci                     # everything above, plus the seeds check, as defined in config/ci.rb
```

Before calling a change done, run `bin/rubocop`, `bin/rails test`, and `bin/rails test:system`
(or `bin/ci`). GitHub Actions runs the same checks on every push and PR.

Running the app needs Google OAuth and TMDB credentials in `config/credentials.yml.enc` (see
README). The tests need neither, and never touch the network.

## Code layout and conventions

- **Everything about a list is nested under it in the URL** (`/lists/:list_id/...`). There's no
  "current list" in the session. Every list-scoped controller finds the list through
  `Current.user.lists.find(...)`, so a list you're not on is a 404. Keep that guard in any new
  list-scoped action, and add a request test for it.
- **Authorization is plain Rails**: anyone on a list can do anything with it. There's no
  Pundit/CanCanCan and there are no roles.
- **Controllers are small and RESTful.** Sub-actions are their own nested resource controllers
  (`Lists::ListEntries::CancellationsController`, `Titles::RefreshesController`) rather than
  custom actions. See `config/routes.rb`.
- **Domain logic goes in plain service objects** in `app/services/`, each a class with `.call`,
  wrapped in a transaction where needed (`WatchRecorder`, `WatchRemover`). There's no service
  framework. Models keep to associations, validations, scopes, and small query helpers.
- **Derived state is computed, not stored**, when a stored value would go stale. For example, the
  "upcoming" badge depends on today's date.
- **Auth**: `Authentication` concern (Rails 8 generator shape). `Current.session` and
  `Current.user` are available everywhere. Use `allow_unauthenticated_access` to opt out.
- **Redirect-back links** go through the `ReturnTo` concern (`return_to_path`), which only accepts
  in-app paths.
- **JavaScript is kept to a minimum.** There are only two real Stimulus controllers: `sortable`
  (SortableJS drag-reorder, using `forceFallback` so touch and system tests share one path) and
  `local-date`. Use Turbo and Bootstrap's data-attribute components before writing JS. JS
  dependencies are pinned in `config/importmap.rb`.
- **UI is mobile-first.** Phones are the main target, and system tests run at a 390×844 viewport.
- **Ruby style** is rubocop-rails-omakase: double quotes, spaces inside array brackets
  (`[ a, b ]`), and methods under `private` indented one extra level.
- **Comments** explain *why*, in plain prose. Services, concerns, migrations, and
  less obvious controllers open with a one or two sentence summary of what they're for.

## Database and migrations

- `db/schema.rb` is **gitignored**. The migrations are the source of truth and must run cleanly
  from an empty database (CI runs `db:migrate`). Don't edit or delete old migrations. Add a new
  one.
- Keep migrations database-agnostic so a later move to Postgres stays easy. Use the standard
  column types and integer-backed Rails `enum`s. Avoid `jsonb`, Postgres enums, and
  adapter-specific index types. Partial unique indexes are already used, and they work on both
  databases.
- A data migration must not depend on app model classes that may change later. Define minimal
  model classes inside the migration, or use SQL.
- CI runs `RAILS_ENV=test bin/rails db:seed:replant`, so `db/seeds.rb` must stay idempotent and
  runnable.

## Testing

- Every model, service, and controller action has tests. Controller/request tests cover the
  not-on-this-list guard. Behavior that depends on JS (drag-reorder, in-place frames, the watch
  form) gets a system test in `test/system/`.
- Build records with the factories in `test/factories/`. There are no YAML
  fixtures for models.
- **Google is faked** by `test/support/fake_google.rb`. Request tests sign in through
  `SignInHelper`. System tests use `sign_in_as(user)` / `sign_in_with_google(...)` from
  `ApplicationSystemTestCase`.
- **TMDB is faked** by `test/support/fake_tmdb.rb`, which answers from recorded, trimmed JSON in
  `test/fixtures/files/tmdb/`. The file is named after the request path, e.g.
  `movie-329865.json`, `tv-136315-season-1.json`, `search-the-bear.json`. To cover a new TMDB
  response, add a trimmed fixture with that name. Set `FakeTmdb.unreachable = true` to simulate
  an outage.
- Tests run in parallel, so don't rely on global state that leaks between tests. Reset anything
  you change in `teardown`.
- Failed system tests save screenshots to `tmp/screenshots/`.

## Writing style (docs, UI copy, commit messages)

Use short, plain sentences in a friendly voice. Name things the way users see them ("Mark as
watched", "Just Me", "Recently watched"). Commit messages get a short imperative subject line and
a body that explains the user-visible change in prose.

## Things to avoid

- Don't commit secrets, `config/master.key`, or anything in `backups/` (real user data).
- Don't run `fly launch`, which would overwrite the existing `Dockerfile` and `fly.toml`.
- Don't add Node, webpack, or a JS bundler.
- Don't reintroduce "groups". Lists and their members replaced them in Phase 17.
