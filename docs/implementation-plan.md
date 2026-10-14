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
- Migrations + models for `Group`, `GroupMembership`, `Title`, `Episode`, `PlayList`, `ListEntry`,
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

## Phase 5 — PlayLists and the default (active) view
- `Groups::PlayListsController` (show, new/create, edit/update). The group's own page lists its
  playlists, so there's no separate playlist index.
- `Groups::PlayLists::ListEntriesController#create` — add an existing Title to a playlist as a new
  `ListEntry` (`state: not_started`, `sequence` appended at the end); enforce the "no second active
  entry for the same (playlist, title)" rule. Titles are a shared, growing catalog (data model
  doc), so choosing one should be a search by name rather than a pick-list of every Title.
- Default playlist view: active entries (`not_started`/`in_progress`) ordered by `sequence`,
  showing title, next episode (derived — see data model), last viewing (derived), and the
  "upcoming season" badge (architecture doc §5).
- System tests: add a movie and a season to a playlist, see them in the default view with correct
  derived fields.
- **Done when**: a playlist's default view matches the user stories for display and ordering.

## Phase 6 — Drag-and-drop reorder
- Stimulus controller wrapping SortableJS (imported via importmap); drag handle per row.
- `Groups::PlayLists::ListEntriesController#reorder` — accepts the new ordering, updates `sequence` in a
  transaction.
- System test exercising an actual drag (or a direct POST test plus a lighter JS smoke test,
  depending on how reliable drag simulation proves in CI).
- **Done when**: reordering persists and survives a reload.

## Phase 7 — Recommendation detail + Watch flow
- Tap-through detail view for a `ListEntry` (Turbo Frame) showing description/title info and a
  "Watch" button.
- Watch form: defaults to the next unwatched Episode and today's date, both editable.
- `WatchRecorder` service (architecture doc §2): given (Title, Episode, Group, date) —
  1. finds every active `ListEntry` for that Title across the Group's PlayLists,
  2. creates a `Viewing` per entry (data model §"Recording a watch"),
  3. recomputes each entry's `state` (`not_started` → `in_progress` → `watched`).
- `Groups::ViewingsController#create` calls `WatchRecorder`, redirects/Turbo-Streams the updated
  row(s) in every affected playlist.
- This is the highest-value area for test coverage — unit-test `WatchRecorder` directly across:
  movie watch, mid-season episode, season-completing episode, and the multi-playlist fan-out.
- **Done when**: all of the watch-related user stories (checks off across playlists, advances next
  episode, removes a completed season/movie from the default view) pass.

## Phase 8 — Historical view & cancel
- Historical playlist view: `watched`/`cancelled` entries, ordered by viewing date (for watched) /
  `cancelled_at` (for cancelled), each showing its note if cancelled.
- Cancel action on an active `ListEntry` (sets `cancelled_at`/`cancel_note`).
- System tests covering cancel-with-note and its appearance in the historical view.
- **Done when**: the historical view story and the cancel-with-note story both pass.

## Phase 9 — Rewatch
- Allow creating a new `ListEntry` for a (playlist, title) pair once the existing one is
  `watched`/`cancelled` — reuses the Phase 5 creation path, since the guard is already "no active
  entry exists."
- System test: watch a movie to completion, re-add it, confirm the old entry's history is
  untouched and the new one starts `not_started`.
- **Done when**: rewatch works and old history is preserved exactly as designed in the data model
  doc.

## Phase 10 — Polish pass
- Mobile responsive pass on every view built so far (this was supposed to be considered
  throughout, but do a dedicated pass once everything exists).
- Empty states (no groups yet, empty playlist, etc.), flash messages, consistent error handling for
  the membership/ownership guards.
- Full Rubocop/Brakeman clean pass; fill any system-test gaps found during the polish pass.
- **Done when**: CI is green end-to-end and the app is usable top-to-bottom on a phone-width
  viewport.

## Explicitly deferred (per requirements doc + this conversation)
- Automated import of seasons/episodes from an external source.
- Streaming-service availability awareness.
- User avatars.
- The `Recommendation` model (suggester + reason) — `ListEntry` covers its MVP duties for now.
- Deployment target selection.
