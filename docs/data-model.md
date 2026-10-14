# Data Model

This supersedes the rough model sketched in `docs/initial-rough-requirements.md`. It resolves the
ambiguities there (how a "season" is represented, how a movie fits the Title/Episode split, how
re-watching and multi-playlist checkoff work) and is the model the implementation plan will build
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
- `has_many :play_lists`

Group membership (who can see/use the Group's PlayLists) is managed at the Group level — there is
no separate per-PlayList membership.

### GroupMembership
- `belongs_to :user`
- `belongs_to :group`

A User is a member of a given Group at most once.

### Title
- `kind` — enum: `movie`, `series`, `book`, `podcast` (not `type`, which Rails reserves for
  single-table inheritance)
- `name`
- `season` — positive integer; required for a series, absent for a movie

A "season" is not a separate model. A season of a series is its own `Title` row (`kind: :series`,
`season` set to that season's number). A movie is a `Title` with exactly one `Episode`.

Titles are a global catalog, not owned by a Group. The intent is to eventually import them from
authoritative sources (IMDb and the like). Manual Title entry (Phase 4) is scaffolding until
then, so hand-entered Titles are visible to every Group in the meantime. Group-specific "bespoke"
Titles may come later as the exception. Because the catalog is shared and will grow, adding a
Title to a PlayList should be a search, not a pick-list of every Title.

### Episode
- `name` — optional
- `number` — positive integer, unique within its Title
- `available_on` — date, optional (unknown until announced)
- `belongs_to :title`

A movie's `Title` has exactly one `Episode`. This keeps `Viewing` and `ListEntry` uniform across
movies and seasons — everything watchable is an `Episode`, everything listable is a `Title`.

### PlayList
- `name`
- `description`
- `belongs_to :group`

### ListEntry
- `belongs_to :playlist`
- `belongs_to :title`
- `sequence` — integer, drag-reorder position within the playlist's default (active) view
- `state` — enum: `not_started`, `in_progress`, `watched`, `cancelled`
- `cancelled_at`
- `cancel_note`

A `ListEntry` represents one occurrence of a Title being listed in a PlayList, and one watch-through
("cycle") of it. It persists indefinitely — it is never deleted — so the historical view can show
watched and cancelled entries alongside active ones. The default (active) view is a filter on
`state IN (not_started, in_progress)`.

`Recommendation` (a planned future model to record who suggested a Title and why) is explicitly out
of scope for now; most of what might have lived there instead lives on `ListEntry`.

### Viewing
- `date`
- `belongs_to :group`
- `belongs_to :episode`
- `belongs_to :list_entry`

A `Viewing` is a single episode-watch event, scoped to the specific `ListEntry` (watch-through) it
advances. The `list_entry` association is what lets a half-finished season and a full rewatch of
that same season coexist without the old cycle's `Viewing`s being mistaken for progress on the new
one.

## Behavior and derivation rules

### Re-watching
A new `ListEntry` may be created for a (playlist, title) pair only if no existing `ListEntry` for
that pair is currently `not_started` or `in_progress`. Re-watching a Title that's already fully
`watched` (or was `cancelled`) in a playlist means adding a fresh `ListEntry` (`state: not_started`),
not mutating the old one. The old entry, with its own `Viewing`s intact, remains visible in the
historical view exactly as it was.

### Recording a watch
Given a (Title, Episode, Group, date) — e.g. from the "Watch" form:
1. Find every currently-active (`not_started` or `in_progress`) `ListEntry` for that Title across
   **all** PlayLists belonging to the Group.
2. For each one, create a `Viewing` (same date/episode/group, `list_entry` set to that entry).
3. For each one, recompute `state`:
   - first `Viewing` recorded against it → `in_progress` (unless step 4 applies)
   - once every `Episode` of the Title has a `Viewing` scoped to that `list_entry` → `watched`

This is what makes "watching a movie/episode checks it off on all playlists for that group" work:
one real watch event is recorded once per active `ListEntry` it applies to. The tradeoff is that a
single watch event can produce multiple `Viewing` rows (one per playlist the Title is concurrently
active in) rather than a single canonical row — accepted for now in exchange for not needing any
shared mutable "resolved by" pointer between entries.

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
