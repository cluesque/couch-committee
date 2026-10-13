# Architecture

Builds on `docs/initial-rough-requirements.md` and `docs/data-model.md`. This is the technical
shape of the app — stack choices, structural decisions, and the reasoning behind them. "Clean,
simple architecture, nothing super fancy" is the guiding principle throughout: prefer plain Rails
over extra gems/frameworks wherever plain Rails is enough.

## Stack

- **Rails 8.x**, Propshaft (default asset pipeline), Solid Queue/Solid Cache *not* installed for now
  — no background jobs or app-level caching are needed yet (no email sending, no async work).
- **Hotwire**: Turbo (Drive/Frames/Streams) + Stimulus, `importmap-rails` for JS (no Node/webpack
  toolchain needed).
- **Styling: Bootstrap 5**, compiled via `dartsass-rails` (standalone Sass binary, no Node
  required) on top of Propshaft. Bootstrap's bundled JS (modals, collapses, dropdowns — built on
  Popper) is pinned via importmap from a CDN. It needs a small `turbo:load` / Stimulus adapter so
  components re-initialize correctly across Turbo page visits — a well-known, well-documented
  pattern, not bespoke JS. This gets mobile-first layout and a full set of ready components (cards,
  list-groups, badges, buttons) essentially for free, which maps directly onto this app's UI
  (playlist rows, status badges, forms).
- **Auth**: `google_sign_in` gem (OmniAuth-based Google OAuth). `User` is found-or-created by email
  on successful callback. No password auth at all.
- **Database**: SQLite in development, test, *and* production, via the standard `sqlite3` adapter.
  All migrations use only database-agnostic Rails migration DSL — standard column types
  (`string`, `text`, `integer`, `date`, `datetime`, `boolean`), Rails-native `enum` (integer-backed,
  not a Postgres enum type), no `jsonb`, no Postgres-specific index types. Revisit this constraint
  (and the production SQLite choice) only if a real need for Postgres-specific features shows up.
- **Testing**: Minitest (Rails default) + `factory_bot_rails`. Capybara + a headless browser driver
  for system tests (needed for the drag-reorder and watch-recording flows, which are meaningfully
  JS-dependent).
- **Linting/security**: `rubocop` with the Rails 8 default **omakase** style, `brakeman`.
- **CI**: GitHub Actions — rubocop, brakeman, full test suite (unit/request + system), on every push
  and PR.
- **Authorization**: plain Rails, no Pundit/CanCanCan. The permission model is simple (any Group
  member can do anything within that Group; no roles yet), so a controller concern plus
  `current_user.groups` scoping covers it. Revisit if/when roles are introduced.
- **Deployment target**: not decided yet — out of scope for this plan. The requirements don't
  specify one; flagging it as a follow-up decision (Kamal, Fly, Render, Heroku, etc.) before going
  to production.

## Key structural decisions

### 1. "Current Group" is a URL concept, not session state
A `User` can belong to multiple `Group`s, so routes are nested under the group:
`/groups/:group_id/play_lists`, `/groups/:group_id/play_lists/:id`, etc. A controller concern
(`SetCurrentGroup`) resolves `params[:group_id]` against `current_user.groups`, 404s or redirects
if the user isn't a member, and exposes it as `Current.group`
(`ActiveSupport::CurrentAttributes`). This keeps multi-group use safe across multiple tabs/bookmarks
— no "which group am I in" state hiding in the session.

### 2. Domain logic lives in plain Ruby service objects, not fat models/controllers
The one piece of genuinely non-trivial business logic — recording a watch, which fans out across
every active `ListEntry` for a Title within a Group and transitions `state` — lives in a plain
Ruby class (e.g. `app/services/watch_recorder.rb`), called from a controller action, wrapped in a
transaction. Models stay focused on associations/validations; controllers stay thin. No service
object framework (dry-rb, interactor, etc.) — just a plain class with a `.call`.

### 3. Turbo-first UI
- Turbo Drive for ordinary navigation.
- Turbo Frames for the recommendation detail view and the "Watch" form, so drilling into a
  recommendation or recording a watch doesn't feel like a full page reload on mobile.
- Turbo Streams to update a playlist row in place after a watch is recorded or a reorder happens,
  instead of a full-page refresh.

### 4. Drag-and-drop reorder is the one place with real custom JS
A single Stimulus controller wraps SortableJS (pinned via importmap) and posts the new order to a
`reorder` action on drop. This is the one genuinely custom bit of JS in the app, deliberately kept
to one controller with one responsibility — everything else leans on Turbo + Bootstrap's own JS.

### 5. "Upcoming season" badge is computed, not stored
A season `ListEntry` is visually flagged as "upcoming" when every one of its not-yet-watched
Episodes has `available_on` in the future. This is a presenter/view-layer computation against
today's date — not a stored column — since a stored flag would go stale as dates pass.

### 6. Manual Title/Episode entry (a gap the user stories don't cover)
The user stories describe adding an *existing* Title/season to a playlist, but nothing describes
how a Title and its Episodes get created in the first place — "importing seasons and episodes" is
explicitly future scope, but *manual* entry isn't optional, since without it no Title could ever
exist. MVP needs a minimal manual-entry flow: create a movie (Title + one Episode in one step) or
a series season (Title + a list of Episodes, added via a small repeating nested form). Kept
deliberately plain — no external metadata lookup/autocomplete; that's exactly the "importing"
feature that's out of scope for now.

## Routes/controllers (sketch)

```
SessionsController          # google_sign_in callback, destroy (logout)
GroupsController             # index (my groups), show, new, create
Groups::MembershipsController   # invite/remove users, nested under group
Groups::PlayListsController     # index, show, new, create, edit, update — nested under group
Groups::TitlesController        # manual create of a movie/season (+ nested episodes)
PlayLists::ListEntriesController  # create (add a title), reorder, cancel — nested under playlist
Groups::ViewingsController         # create — the "Watch" form submit, resolves across playlists
```

## Testing strategy

- **Model tests**: validations/associations, and — most importantly — `WatchRecorder` transition
  behavior (movie watch, mid-season watch, last-episode-of-season watch, rewatch, multi-playlist
  fan-out).
- **Request tests**: every controller action, including the Group-membership guard.
- **System tests** (Capybara, headless): login/logout (OAuth stubbed), add a title to a playlist,
  record a watch (movie / mid-season / season-completing episode), drag-reorder, cancel an entry,
  rewatch after completion.
- `factory_bot` factories for every model.

## CI

Single GitHub Actions workflow: Ruby setup with bundler cache → `rubocop` → `brakeman` →
`db:test:prepare` → `rails test` → `rails test:system` (headless Chrome). Fails the build on any
step failing.
