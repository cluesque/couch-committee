# Implementation Plan

Phased build order, each phase producing something runnable/testable before moving on. Later
phases depend on earlier ones; within a phase, tasks are roughly sequential. See
`docs/architecture.md` for the stack/structural decisions and `docs/data-model.md` for the schema
and behavior rules this implements.

## Phase 0 — Project scaffolding
- `rails new` (Rails 8, SQLite, Propshaft, importmap, no Node).
- Add gems: `google_sign_in`, `bootstrap`, `dartsass-rails`; test group: `factory_bot_rails`,
  `capybara`, a headless driver.
- Rubocop (omakase defaults) + Brakeman configured; GitHub Actions workflow running both plus
  `rails test` (initially empty) on push/PR.
- Base layout with Bootstrap wired in (navbar, container, flash messages), mobile-first viewport
  meta tag.
- **Done when**: CI is green on an empty app with the layout rendering.

## Phase 1 — Auth
- `User` model/migration (`email`, `display_name`).
- `google_sign_in` integration: callback creates-or-finds `User` by email, sets session.
- `SessionsController` (create via OAuth callback, destroy for logout); `Current.user`.
- Login page (signed-out layout) and logout control (signed-in layout).
- Request/system tests for login, logout, and an unauthenticated redirect.
- **Done when**: a real user can sign in with Google, see a signed-in shell, and sign out.

## Phase 2 — Core domain models
- Migrations + models for `Group`, `GroupMembership`, `Title`, `Episode`, `List`, `ListEntry`,
  `Viewing`, per `docs/data-model.md` (associations, enums, validations).
- Factories for all of the above.
- Model tests for associations/validations (behavior/state-machine logic comes in Phase 7, once
  there's UI driving it — no behavior to test yet besides shape).
- **Done when**: schema matches the data model doc, factories build valid objects, `rails test`
  green.

## Phase 3 — Groups & membership
- `SetCurrentGroup` controller concern (resolves `params[:group_id]` against
  `current_user.groups`, 404/redirect otherwise); `Current.group`.
- `GroupsController` (index of my groups, new/create a group — creator becomes first member).
- `Groups::MembershipsController` (invite a user by email — creates the `User` if they don't exist
  yet, since there's no separate invite/pending state — and remove a member).
- Request/system tests covering the membership guard (a non-member can't load another group's
  pages) and invite/remove.
- **Done when**: a user can create a Group, invite another user by email, and both see it in their
  group list; a non-member is blocked.

## Phase 4 — Manual Title/Episode entry
- `TitlesController#new/create` for a **movie** (Title + its one Episode, one form). Top-level
  rather than group-nested, since Titles are a global catalog; `index`/`show` give it a minimal
  browsable home until Phase 5's search.
- Separate flow (or a type toggle on the same form) for a **series season** (Title with `season`
  set + a repeating nested-episode form — small Stimulus "add another episode" controller).
- Validation: a movie's Title always ends up with exactly one Episode.
- Request/system tests for both creation paths.
- **Done when**: a member can manually create a movie or a season with its episodes. (No metadata
  lookup/autocomplete — explicitly out of scope, see architecture doc §6.)

## Phase 5 — Lists and the default (active) view
- `Groups::ListsController` (show, new/create, edit/update). The group's own page lists its
  lists, so there's no separate list index.
- `Groups::Lists::ListEntriesController#create` — add an existing Title to a list as a new
  `ListEntry` (`state: not_started`, `sequence` appended at the end); enforce the "no second active
  entry for the same (list, title)" rule. Titles are a shared, growing catalog (data model
  doc), so choosing one should be a search by name rather than a pick-list of every Title.
- Default list view: active entries (`not_started`/`in_progress`) ordered by `sequence`,
  showing title, next episode (derived — see data model), last viewing (derived), and the
  "upcoming season" badge (architecture doc §5).
- System tests: add a movie and a season to a list, see them in the default view with correct
  derived fields.
- **Done when**: a list's default view matches the user stories for display and ordering.

## Phase 6 — Drag-and-drop reorder
- Stimulus controller wrapping SortableJS (imported via importmap); drag handle per row.
- `Groups::Lists::ListEntriesController#reorder` — accepts the new ordering, updates `sequence` in a
  transaction.
- System test exercising an actual drag (or a direct POST test plus a lighter JS smoke test,
  depending on how reliable drag simulation proves in CI).
- **Done when**: reordering persists and survives a reload.

## Phase 7 — Recommendation detail + Watch flow
- Tap-through detail view for a `ListEntry` (Turbo Frame) showing description/title info and a
  "Watch" button.
- Watch form: defaults to the next unwatched Episode and today's date, both editable.
- `WatchRecorder` service (architecture doc §2): given (Title, Episode, Group, date) —
  1. finds every active `ListEntry` for that Title across the Group's Lists,
  2. creates a `Viewing` per entry (data model §"Recording a watch"),
  3. recomputes each entry's `state` (`not_started` → `in_progress` → `watched`).
- `Groups::Lists::ListEntries::ViewingsController#create` calls `WatchRecorder` and redirects
  back to the list, which re-renders with every affected entry's new state.
- This is the highest-value area for test coverage — unit-test `WatchRecorder` directly across:
  movie watch, mid-season episode, season-completing episode, and the multi-list fan-out.
- **Done when**: all of the watch-related user stories (checks off across lists, advances next
  episode, removes a completed season/movie from the default view) pass.

## Phase 8 — Historical view & cancel
- Historical list view: a flat log, newest first, with one row per `Viewing` (each episode of a
  series, including seasons still in progress) and one per cancelled entry with its note.
- Cancel action on an active `ListEntry` (sets `cancelled_at`/`cancel_note`).
- System tests covering cancel-with-note and its appearance in the historical view.
- **Done when**: the historical view story and the cancel-with-note story both pass.

## Phase 9 — Rewatch
- Allow creating a new `ListEntry` for a (list, title) pair once the existing one is
  `watched`/`cancelled` — reuses the Phase 5 creation path, since the guard is already "no active
  entry exists." A finished entry's page (reached from History) has a "Watch again" button for
  this; re-adding through search works too.
- System test: watch a movie to completion, re-add it, confirm the old entry's history is
  untouched and the new one starts `not_started`.
- **Done when**: rewatch works and old history is preserved exactly as designed in the data model
  doc.

## Phase 10 — Polish pass
- Mobile responsive pass on every view built so far (this was supposed to be considered
  throughout, but do a dedicated pass once everything exists).
- Empty states (no groups yet, empty list, etc.), flash messages, consistent error handling for
  the membership/ownership guards.
- Full Rubocop/Brakeman clean pass; fill any system-test gaps found during the polish pass.
- **Done when**: CI is green end-to-end and the app is usable top-to-bottom on a phone-width
  viewport.

## Phase 11 — TMDB client and credit
Titles come from TMDB from here on. The research, the fields kept, and the decisions behind these
phases are in `docs/title-metadata.md`.
- Get a TMDB account and its "API Read Access Token", and store it as `tmdb.api_read_access_token`
  in credentials. The dev sandbox needs `api.themoviedb.org` and `image.tmdb.org` approved.
- `Tmdb::Client` on Faraday (already in the bundle), with the bearer token, JSON parsing, short
  timeouts, and a `Tmdb::Error` for failures. Methods: `search` (movies and TV, without people),
  `movie`, `tv`, `season`, `watch_providers`.
- `Tmdb.image_url(path, size)`, with a configurable base URL.
- `FakeTmdb` test support: Faraday's test adapter serving canned JSON from
  `test/fixtures/files/tmdb/`. Record real responses once the host is approved, trimmed to what's
  used. Point image URLs at a local placeholder in tests so browsers don't hit the network.
- TMDB's required credit: its logo and "This product uses the TMDB API but is not endorsed or
  certified by TMDB" in a small footer.
- **Done when**: the client is tested end to end against `FakeTmdb`, and the credit shows on every
  page.

## Phase 12 — Metadata columns and the importer
- Migration: `titles` gains `tmdb_id`, `imdb_id`, `overview`, `poster_path`, `backdrop_path`,
  `genres`, `runtime_minutes`, `rating`, `network`, `tmdb_synced_at`, plus a partial unique index on
  `(kind, tmdb_id, season)` where `tmdb_id` is present. `episodes` gains `overview`, `still_path`,
  `runtime_minutes`.
- `Tmdb::Importer` service: `import_movie(tmdb_id)` and `import_season(tmdb_show_id, season_number)`.
  Each finds or creates the Title by `(kind, tmdb_id, season)`, fills in its fields (a season falls
  back to the show's overview and poster), and updates its Episodes by number, all in one
  transaction. Importing again refreshes; it never deletes an episode that has viewings.
- `Title#imdb_url` and `#tmdb_url`.
- **Done when**: importer tests over the fixtures cover a movie, a season, the season-to-show
  fallbacks, and a re-import that updates rather than duplicates.

## Phase 13 — "Add a title" searches TMDB
- The add-to-list search queries TMDB. Each result shows a small poster, name, year, and kind
  icon. Results already active on the list say "On this list".
- **A movie:** "Add" imports it (or reuses it, if it's in the catalog) and adds it to the list.
- **A TV show:** opens a season picker (poster, season name, year, episode count; no season 0).
  Picking a season imports it and adds it to the list.
- Titles entered by hand earlier still show up in results when their names match, until they're
  linked to TMDB (Phase 15).
- If TMDB can't be reached, the search says so and offers to try again.
- Remove hand entry: `TitlesController#new`/`create`, the movie, season, and episode-row form
  partials, `episode_fields_controller.js`, and their tests. `/titles` keeps its browse pages.
- **Done when**: a system test adds a movie and a season to a list through TMDB search (against
  `FakeTmdb`), and nothing asks for a title's name anymore except the search box.

## Phase 14 — Show the metadata
- An entry's page and a title's page get a header: poster, name, a facts line (year · runtime ·
  rating · genres · network), the overview, and links to IMDb and TMDB.
- A season's episode list shows each episode's still and overview, kept compact on a phone, with
  the "Next" badge and watched ticks as today.
- Small poster thumbnails in list rows, search results, and history (see `docs/title-metadata.md`,
  "Open questions"). The kind icon stays for titles without a poster.
- Hand-entered titles without metadata still render cleanly.
- **Done when**: phone-width screenshots of every changed page look right, with and without
  metadata, and request tests cover both.

## Phase 15 — Refresh, and link older titles
- "Refresh from TMDB" on a linked title's page re-imports it, picking up new air dates and
  episodes.
- "Find on TMDB" on a hand-entered title's page: a search prefilled with its name. Picking the
  match links it (sets `tmdb_id`) and fills in its metadata, keeping existing episodes and
  viewings by matching episode numbers.
- **Done when**: a refresh updates a season's air dates, and linking a hand-entered title keeps its
  watch history intact.

## Phase 16 — Where to watch
- A title's page shows where to stream, rent, or buy it in one country (US to start), using
  TMDB's watch providers. Fetched live and cached for a few hours in `Rails.cache`, with
  JustWatch's required credit.
- **Done when**: providers show for a fixture title, and a title with none (or a TMDB outage)
  shows a quiet "not available to stream" instead of an error.

## Explicitly deferred (per requirements doc + this conversation)
- User avatars.
- The `Recommendation` model (suggester + reason) — `ListEntry` covers its MVP duties for now.
- Deployment target selection.
