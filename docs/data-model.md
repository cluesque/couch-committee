# Data Model

This supersedes the rough model sketched in `docs/initial-rough-requirements.md`. It resolves the
ambiguities there (how a "season" is represented, how a movie fits the Title/Episode split, how
re-watching and multi-list checkoff work) and is the model the implementation plan will build
from.

## Models

### User
- `email` — unique, normalized to lowercase
- `display_name` — optional; filled from the Google profile on first sign-in
- `google_id` — optional, unique; Google's stable account ID (the ID token's `sub`)

A User can exist before they've ever signed in (Phase 3 invites create one by email), so
`google_id` and `display_name` are blank until first sign-in. Sign-in matches on `google_id`
first, since a Google account's email can change. Failing that, it claims an existing User with
the same (verified) email and no `google_id` yet; failing that, it creates a new User.

### Group
- `name`
- `has_many :users`, through `GroupMembership`
- `has_many :lists`

Group membership (who can see/use the Group's Lists) is managed at the Group level — there is
no separate per-List membership.

### GroupMembership
- `belongs_to :user`
- `belongs_to :group`

A User is a member of a given Group at most once.

### Title
- `kind` — enum: `movie`, `series`, `book`, `podcast` (not `type`, which Rails reserves for
  single-table inheritance)
- `name`
- `season` — positive integer; required for a series, absent for a movie
- `tmdb_id` — optional; a movie's TMDB movie ID, or a season's TMDB *show* ID
- `imdb_id`, `overview`, `poster_path`, `backdrop_path`, `genres` (comma-separated names),
  `runtime_minutes` (movies), `rating` (US certification or TV rating), `network` (series),
  `tmdb_synced_at` — all optional, filled in by importing from TMDB (`Tmdb::Importer`)

A TMDB movie is in the catalog at most once, and so is each season of a TMDB show. Two partial
unique indexes enforce this: one on `tmdb_id` for movies, and one on `(tmdb_id, season)` for
series. A single index on `(kind, tmdb_id, season)` wouldn't do, because a movie's `season` is
NULL and unique indexes treat NULLs as distinct. Hand-entered Titles have no `tmdb_id`.

A "season" is not a separate model. A season of a series is its own `Title` row (`kind: :series`,
`season` set to that season's number). A movie is a `Title` with exactly one `Episode`.

Titles are a global catalog, not owned by a Group. They're imported from TMDB when someone adds
one to a List (see `docs/title-metadata.md`). Titles entered by hand before that (Phase 4's
forms, since removed) remain, with no `tmdb_id`, until someone links one to TMDB from its page
("Find on TMDB"). Linking keeps its Episodes, matched by number, so its Viewings stay intact. Group-specific "bespoke" Titles may come later
as the exception. Because the catalog is shared and will grow, adding a
Title to a List should be a search, not a pick-list of every Title.

### Episode
- `name` — optional
- `number` — positive integer, unique within its Title
- `available_on` — date, optional (unknown until announced)
- `overview`, `still_path` (an episode image), `runtime_minutes` — optional, from TMDB
- `belongs_to :title`

Re-importing a season from TMDB removes episodes TMDB no longer lists, unless they have Viewings.

A movie's `Title` has exactly one `Episode`. This keeps `Viewing` and `ListEntry` uniform across
movies and seasons — everything watchable is an `Episode`, everything listable is a `Title`.

### List
- `name`
- `description`
- `belongs_to :group`

Called `PlayList` until 2026-10-15. Users found "play list" awkward, so the model, table, routes,
and UI all became "list".

### ListEntry
- `belongs_to :list`
- `belongs_to :title`
- `sequence` — integer, drag-reorder position within the list's default (active) view
- `state` — enum: `not_started` (default), `in_progress`, `watched`, `cancelled`
- `cancelled_at`
- `cancel_note`
- `recommendation` — optional string (up to 500 characters): why it's on the list, entered when
  adding the title or later

A `ListEntry` represents one occurrence of a Title being listed in a List, and one watch-through
("cycle") of it. It persists indefinitely — it is never deleted — so the historical view can show
watched and cancelled entries alongside active ones. The default (active) view is a filter on
`state IN (not_started, in_progress)`.

A recommendation is just the `recommendation` string on `ListEntry` (the reason). Recording *who*
suggested a Title, which a separate `Recommendation` model was once planned for, is still out of
scope.

### Viewing
- `date`
- `belongs_to :group`
- `belongs_to :episode`
- `belongs_to :list_entry`

A `Viewing` is a single episode-watch event, scoped to the specific `ListEntry` (watch-through) it
advances. Its `episode` must belong to the entry's Title, and its `group` must own the entry's
List. The `list_entry` association is what lets a half-finished season and a full rewatch of
that same season coexist without the old cycle's `Viewing`s being mistaken for progress on the new
one.

## Behavior and derivation rules

### Re-watching
A new `ListEntry` may be created for a (list, title) pair only if no existing `ListEntry` for
that pair is currently `not_started` or `in_progress`. This is enforced by a model validation and
by a partial unique index (supported by both SQLite and Postgres). Re-watching a Title that's already fully
`watched` (or was `cancelled`) in a list means adding a fresh `ListEntry` (`state: not_started`),
not mutating the old one. The old entry, with its own `Viewing`s intact, remains visible in the
historical view exactly as it was.

### Recording a watch
Given a (Title, Episode, Group, date) — e.g. from the "Watch" form:
1. Find every currently-active (`not_started` or `in_progress`) `ListEntry` for that Title across
   **all** Lists belonging to the Group.
2. For each one, create a `Viewing` (same date/episode/group, `list_entry` set to that entry).
3. For each one, recompute `state`:
   - first `Viewing` recorded against it → `in_progress` (unless step 4 applies)
   - once every `Episode` of the Title has a `Viewing` scoped to that `list_entry` → `watched`

This is what makes "watching a movie/episode checks it off on all lists for that group" work:
one real watch event is recorded once per active `ListEntry` it applies to. The tradeoff is that a
single watch event can produce multiple `Viewing` rows (one per list the Title is concurrently
active in) rather than a single canonical row — accepted for now in exchange for not needing any
shared mutable "resolved by" pointer between entries.

### Unwatching
A recorded watch can be undone from a List's history (`WatchRemover`). Since recording put a
`Viewing` on every active entry for the Title across the Group's Lists, unwatching deletes all of
them: every `Viewing` in the Group for that same Episode and date. No record of the undo is kept.
Each affected entry then takes the state its remaining viewings call for (`not_started`,
`in_progress`, or `watched`), so a finished season or movie can return to the active list. A
`cancelled` entry stays cancelled. If a finished entry would reopen while a rewatch of the same
Title is already active on its List, the unwatch is refused, since a List can't hold two active
entries for one Title.

### "Next episode" / season progress
For a season `ListEntry`, the next episode to watch is the lowest-numbered `Episode` of that Title
with no `Viewing` scoped to that specific `list_entry`. Because `Viewing`s are scoped per
`ListEntry` rather than globally per (group, episode), this is accurate even when the same season
has been watched before (a prior, now-`watched` `ListEntry`) and is being watched again.

### Movies
A movie's Title has exactly one `Episode`, so the first `Viewing` recorded against a movie's
`ListEntry` is always also the last — it goes straight from `not_started` to `watched`.

### Cancelling
A member can cancel an active `ListEntry`, setting `cancelled_at` and an optional `cancel_note`.
This is distinct from `watched` — cancelling means "we decided not to watch this," not "this was
resolved by being watched elsewhere." Cancelled entries remain visible, with their note, in the
historical view.
