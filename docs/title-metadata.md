# Title metadata: where to get it

Research notes, 2026-10-15. **Decision: use TMDB (The Movie Database).** The catalog is meant to
be imported from an authoritative source, with hand entry as scaffolding until then (see "Title"
in `docs/data-model.md`). This doc picks that source and sketches how it fits the app. It's the
"automated import" item in the implementation plan's "Explicitly deferred" list.

> These notes were written from knowledge as of early 2026, without live access to the providers'
> sites. Re-check terms, pricing, and rate limits before building on them.

## How media players do it

Plex, Jellyfin, Emby, Kodi, and Infuse all work the same way. They identify each file from its
name and folder, e.g. `The Bear/Season 03/The Bear - S03E02.mkv`. Then they look it up in
community-run online databases, which return show and episode names, air dates, plot summaries,
and artwork (posters, episode stills, logos), all keyed by stable IDs that the player caches.
Plex runs its own metadata service in front of the same sources.

Big-platform guides (the Apple TV app, Google TV, cable and smart-TV guides) license commercial
data from Gracenote (Nielsen) or TiVo instead. That's priced for companies, not households.

## Sources compared

| Source | Coverage | Access and terms | Verdict |
|---|---|---|---|
| **TMDB** (themoviedb.org) | Movies and TV: shows, seasons, episodes (names, numbers, air dates, overviews), posters and stills, cross-reference IDs (IMDb, TVDB), and per-country "where to stream" data sourced from JustWatch | Free API key for non-commercial use. Requires an on-screen credit and TMDB logo. Generous rate limits. Commercial use needs a license. | **Chosen** |
| **TVmaze** | TV only: shows, seasons, episodes with names and air dates, networks, images, schedules | No key. Data is CC BY-SA (credit required). About 20 requests per 10 seconds. Very simple JSON API. | Fallback if TMDB's terms ever become a problem, though movies would stay hand-entered |
| **TheTVDB** | TV, with very complete episode ordering | Current API (v4) needs a paid subscription or license | Not worth paying for, given TMDB |
| **IMDb** | The most complete data | No free API. Free bulk TSV downloads (non-commercial) have no images and only years, not air dates. Commercial feed via AWS Data Exchange is expensive. | No |
| **OMDb** | Unofficial IMDb-style lookups | Small paid tier; thin on episode data | No |
| **Trakt** | Built on TMDB IDs, plus users' watch histories and lists | Free API | Not a catalog source, but worth knowing about: it's "what have I watched" for individuals, so a possible future import of people's history |
| **Fanart.tv** | Artwork only (logos, clear art, backgrounds) | Free personal API key | Only if TMDB's images aren't enough |
| **Wikidata** | Cross-reference IDs between all of the above | Open (CC0); episode coverage patchy | No |

## Why TMDB

- **Both movies and TV**, in one free API. TVmaze covers TV only.
- **Fits the data model.** A movie maps to a TMDB movie. A season (this app's series `Title`) maps
  to a TMDB TV show plus a season number. An episode's air date fills `Episode#available_on`, and
  those dates drive the "Coming …" badges.
- **Images**, i.e. the posters and episode stills seen in media players.
- **Streaming availability** comes along for free, via its watch-provider data. That answers the
  deferred "streaming-service availability awareness" item too.
- **The terms fit.** A household app is non-commercial. The cost is a credit line, the TMDB logo
  (on an About page or footer), and an API key in credentials.

## TMDB in brief

- **Auth:** an API key, or the "API Read Access Token" sent as a bearer token. Both come from a
  free TMDB account's settings.
- **Endpoints this app would use:**
  - `GET /3/search/movie?query=…` and `GET /3/search/tv?query=…` (or `/3/search/multi`)
  - `GET /3/movie/{id}`: title, release date, poster
  - `GET /3/tv/{id}`: show name, poster, and a list of seasons (number, name, episode count, air date)
  - `GET /3/tv/{id}/season/{season_number}`: that season's episodes (`episode_number`, `name`,
    `air_date`, `overview`, `still_path`)
  - `GET /3/movie/{id}/watch/providers`, `GET /3/tv/{id}/watch/providers`: streaming, rent, and
    buy options per country, credited to JustWatch
  - `GET /3/configuration`: the image base URL and sizes
- **Images** are paths like `/abc123.jpg`, served from `https://image.tmdb.org/t/p/{size}{path}`
  (e.g. `w185`). Linking to them directly is the normal way to use them.
- **Attribution** means showing the TMDB logo and "This product uses the TMDB API but is not
  endorsed or certified by TMDB." Watch-provider data must also credit JustWatch.

## How it would fit the app

### Schema

- `titles.tmdb_id` (integer, nullable). It holds a movie's TMDB movie ID, or a season's TMDB *show*
  ID. A partial unique index on `(kind, tmdb_id, season)` where `tmdb_id` is present stops the
  same movie or season from being imported twice. That also fixes the duplicate-titles gap
  hand entry has.
- `titles.poster_path` (string, nullable): the TMDB image path.
- Optionally `episodes.tmdb_id`, if refreshes should match episodes by ID rather than by number.

Hand-entered titles keep `tmdb_id` empty, so nothing about the existing catalog has to change.
They could be linked to TMDB later.

### Adding a title to a list

The current "Add to <list>" search already searches the local catalog. It would also search TMDB
and show matches not yet in the catalog:

- **A movie:** picking it imports the Title plus its one Episode (`available_on` from
  `release_date`) and adds it to the list.
- **A series:** picking it shows the show's seasons. Picking a season imports that season as a
  Title (`season` set), with its Episodes, and adds it to the list.
- **Already imported:** a match that's already in the catalog (same `tmdb_id`) is just added, not
  imported again.

The hand-entry movie and season forms stay as the fallback for anything TMDB doesn't have.

### Keeping upcoming seasons current

Air dates and episode lists for upcoming seasons change after import. Options, simplest first:

1. **A "Refresh from TMDB" button** on a title. Manual, but no new infrastructure.
2. **Refresh when viewed:** when a season with future episodes is shown and its data is more than
   a few days old, re-fetch it. This works inline at first, but blocks the page on a slow request.
3. **A scheduled job** that re-fetches every title with future-dated episodes, say nightly. This
   needs a job runner, and none is installed (the architecture doc deliberately left out Solid
   Queue). It would be the first reason to add one.

Recommendation: start with 1, and move to 3 if keeping dates fresh turns out to matter.

### Practicalities

- **Credentials:** a `tmdb.api_read_access_token` entry in `config/credentials.yml.enc`.
- **HTTP client:** Faraday is already in the bundle (through `oauth2`). A small `Tmdb::Client`
  wrapping the endpoints above would keep the rest of the app unaware of TMDB's response shapes.
- **Tests:** stub TMDB the way `test/support/fake_google.rb` stubs Google, with Faraday's test
  adapter and canned JSON responses. No network calls in tests.
- **Network:** this dev sandbox's firewall would need `api.themoviedb.org` (and `image.tmdb.org`
  for images) approved. Fly.io has open egress.
- **Rate limits:** TMDB's limits are far above what a household app will ever send. Caching the
  imported data in our own tables means pages never call TMDB at all.

## Open questions

- Which country to use for streaming availability. Presumably US to start; it could become a
  per-group or per-user setting.
- Whether to show posters in lists (more visual, but heavier on a phone) or only on a title's page.
- Books and podcasts aren't covered by TMDB. Open Library and Podcast Index are the equivalent
  sources if those kinds ever get entry forms.
