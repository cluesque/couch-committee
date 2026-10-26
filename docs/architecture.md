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
  Popper) is vendored via importmap. Its data-attribute components (collapse, dropdown, modal)
  use event delegation, so they keep working across Turbo page visits without an adapter; only
  tooltips and popovers, which need explicit initialization, would need a small Stimulus
  controller. (The navbar's account menu is a Bootstrap dropdown.) This gets mobile-first layout and a full set of ready components (cards,
  list-groups, badges, buttons) essentially for free, which maps directly onto this app's UI
  (list rows, status badges, forms).
- **Auth**: Basecamp's `google_sign_in` gem (a small Rails engine over the `oauth2` gem, not
  OmniAuth). On a successful callback the `User` is found by Google account ID, else claimed by
  verified email, else created (see `docs/data-model.md`). A sign-in is a `Session` row plus a
  permanent signed cookie, in the shape of Rails 8's authentication generator. No password auth
  at all.
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
- **Authorization**: plain Rails, no Pundit/CanCanCan. The permission model is simple (anyone on
  a List can do anything with it; no roles yet), so finding the List through
  `Current.user.lists` covers it. Revisit if/when roles are introduced.
- **Deployment target**: not decided yet — out of scope for this plan. The requirements don't
  specify one; flagging it as a follow-up decision (Kamal, Fly, Render, Heroku, etc.) before going
  to production.

## Key structural decisions

### 1. The list is in the URL, not session state
A `User` can be on many Lists, so everything about a List is nested under it: `/lists/:id`,
`/lists/:list_id/list_entries/...`, and so on. Each controller finds the List through
`Current.user.lists`, so a List you're not on is a 404, and you can't tell whether it exists. This
keeps several Lists safe across tabs and bookmarks, with no "which list am I on" state hiding in
the session.

Until Phase 17 there was a Group between people and their Lists, and URLs were nested under
`/groups/:group_id`. Those URLs are gone.

### 2. Domain logic lives in plain Ruby service objects, not fat models/controllers
The non-trivial business logic — recording a watch and transitioning the entry's `state`, and
undoing one — lives in plain Ruby classes (`app/services/watch_recorder.rb`, `watch_remover.rb`),
called from a controller action, wrapped in a transaction. Models stay focused on associations/validations; controllers stay thin. No service
object framework (dry-rb, interactor, etc.) — just a plain class with a `.call`.

### 3. Turbo-first UI
- Turbo Drive for ordinary navigation.
- A Turbo Frame for the "Watch" form, which opens in place on an entry's detail page. The detail
  view itself is an ordinary Turbo Drive page: a frame inside the sortable list would fight the
  drag handles, and Drive already avoids a full reload.
- A lazy Turbo Frame for "Where to watch" on title and entry pages. It's fetched live from TMDB
  (and cached for a few hours), so loading it separately keeps a slow TMDB call from holding up
  the page.
- No Turbo Streams so far. Recording a watch redirects back to the list, which re-renders with
  the new state, and a reorder is already reflected in the DOM before it's saved. Streams would earn
  their place only if other members' open pages had to update live.

### 4. Drag-and-drop reorder is the one place with real custom JS
A single Stimulus controller wraps SortableJS (pinned via importmap) and posts the new order to a
`reorder` action on drop. It uses SortableJS's pointer-event mode (`forceFallback`) rather than
native HTML5 drag-and-drop, so desktop and touch share one code path and system tests can drive a
real drag. This is the one genuinely custom bit of JS in the app, deliberately kept
to one controller with one responsibility — everything else leans on Turbo + Bootstrap's own JS.

The only other Stimulus controller, `local-date`, is a few lines: it fills in the "Mark as watched"
form's date with today in the browser's time zone, since the server runs in UTC and that's already
tomorrow on a US evening.

### 5. "Upcoming season" badge is computed, not stored
A season `ListEntry` is visually flagged as "upcoming" when every one of its not-yet-watched
Episodes has `available_on` in the future. The same rule covers a movie with a future release
date. An Episode with no `available_on` counts as available, since the date is optional and
usually skipped for things already out. This is a presenter/view-layer computation against
today's date — not a stored column — since a stored flag would go stale as dates pass.

### 6. Manual Title/Episode entry (a gap the user stories don't cover)
The user stories describe adding an *existing* Title/season to a list, but nothing describes
how a Title and its Episodes get created in the first place — "importing seasons and episodes" is
explicitly future scope, but *manual* entry isn't optional, since without it no Title could ever
exist. MVP needs a minimal manual-entry flow: create a movie (Title + one Episode in one step) or
a series season (Title + a list of Episodes, added via a small repeating nested form). Kept
deliberately plain — no external metadata lookup/autocomplete; that's exactly the "importing"
feature that's out of scope for now.

**Replaced in Phase 13:** titles are now imported from TMDB through the add-a-title search, and
these hand-entry forms are gone. See `docs/title-metadata.md`.

## Routes/controllers (sketch)

```
SessionsController          # google_sign_in callback, destroy (logout)
ListsController             # index (Home: my lists), show, new, create, edit (incl. who's on it), update
Lists::MembershipsController   # add someone by email, remove someone, leave — from the list's edit page
Lists::TagsController          # rename, recolor, delete a tag — in place on the list's edit page
TitlesController                # browse the global catalog — not list-nested, since Titles are global
ViewingsController              # index — "Recently watched" across all my lists, from the account menu
Lists::ListEntriesController  # new (search TMDB), seasons (pick a show's season), create (import
                                # and add a title), reorder — nested under list
Lists::ListEntries::ViewingsController  # new/create — the "Mark as watched" form, from an entry;
                                # destroy — unwatch, from History
```

## Testing strategy

- **Model tests**: validations/associations, and — most importantly — `WatchRecorder` transition
  behavior (movie watch, mid-season watch, last-episode-of-season watch, rewatch, other lists
  untouched).
- **Request tests**: every controller action, including the guard against lists you're not on.
- **System tests** (Capybara, headless): login/logout (OAuth stubbed), add a title to a list,
  record a watch (movie / mid-season / season-completing episode), drag-reorder, cancel an entry,
  rewatch after completion.
- `factory_bot` factories for every model.

## CI

Single GitHub Actions workflow: Ruby setup with bundler cache → `rubocop` → `brakeman` →
`db:test:prepare` → `rails test` → `rails test:system` (headless Chrome). Fails the build on any
step failing.
