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
  - `GET /3/movie/{id}?append_to_response=release_dates`: title, overview, release date, runtime,
    genres, poster and backdrop, `imdb_id`, and US certification
  - `GET /3/tv/{id}?append_to_response=external_ids,content_ratings`: show name, overview,
    genres, networks, poster and backdrop, IMDb ID, US TV rating, and a list of seasons (number,
    name, episode count, air date, poster)
  - `GET /3/tv/{id}/season/{season_number}`: that season's episodes (`episode_number`, `name`,
    `air_date`, `overview`, `still_path`, `runtime`)
  - `GET /3/movie/{id}/watch/providers`, `GET /3/tv/{id}/watch/providers`: streaming, rent, and
    buy options per country, credited to JustWatch
  - `GET /3/configuration`: the image base URL and sizes
- **Images** are paths like `/abc123.jpg`, served from `https://image.tmdb.org/t/p/{size}{path}`
  (e.g. `w185`). Linking to them directly is the normal way to use them.
- **Attribution** means showing the TMDB logo and "This product uses the TMDB API but is not
  endorsed or certified by TMDB." Watch-provider data must also credit JustWatch.

## What we'll keep

Everything below comes from the movie, TV show, and season endpoints, plus `append_to_response`
to fold extra data into the same request. Imported data is stored in our own tables, so showing a
page never calls TMDB. The one exception is where-to-watch, which changes too often to store.

**On Title**

| Field | Movie | Season of a series |
|---|---|---|
| `tmdb_id` | TMDB movie ID | TMDB *show* ID (the season number is `season`) |
| `imdb_id` | movie's `imdb_id` | show's IMDb ID (`external_ids`); IMDb links seasons through the show |
| `overview` | movie overview | season overview, falling back to the show's when it's blank |
| `poster_path` | movie poster | season poster, falling back to the show's |
| `backdrop_path` | movie backdrop | show backdrop |
| `genres` | genre names, comma-separated | show's genre names |
| `runtime_minutes` | movie runtime | (blank; episodes carry their own) |
| `rating` | US certification (`release_dates`) | US TV rating (`content_ratings`) |
| `network` | (blank) | the show's first network |
| `cast_names` | first four billed (`credits`), comma-separated | that season's own first four (season `credits`) |
| `tmdb_synced_at` | when it was last imported or refreshed | same |

**On Episode** (beyond today's `name`, `number`, `available_on`): `overview`, `still_path` (an
episode screenshot), `runtime_minutes`. A movie's single Episode takes the movie's release date as
`available_on`.

**Derived, not stored**: links to `https://www.imdb.com/title/{imdb_id}/` and to the title's TMDB
page (`/movie/{id}`, or `/tv/{id}/season/{n}`).

**Fetched live, cached for a few hours**: where to watch (streaming, rent, or buy, for one
country), credited to JustWatch.

**Not kept for now**: the rest of the cast, crew, trailers, vote averages, taglines. The TMDB link covers
them for anyone curious.

Everything stays in plain string, text, and integer columns (no JSON columns), in keeping with the
database-agnostic rule in `docs/architecture.md`.

## Decisions

- **No more typing titles.** "Add a title" searches TMDB, and picking a result imports it. The
  hand-entry movie and season forms are removed. Titles entered by hand before this keep working,
  and each can be linked to its TMDB match later.
- **One Title per season**, as in the data model today. Picking a TV show leads to a choice of its
  seasons. TMDB's "Season 0" (specials) is left out for now.
- **Imports are idempotent.** A Title is identified by `(kind, tmdb_id, season)`, so importing
  again refreshes the existing Title instead of duplicating it. The database enforces this with
  two partial unique indexes (movies on `tmdb_id`, seasons on `(tmdb_id, season)`). A single
  three-column index would let a movie in twice, since unique indexes treat its NULL `season` as
  distinct.
  A refresh never deletes an episode that has viewings.
- **Keeping upcoming seasons current** starts with a "Refresh from TMDB" button. A scheduled job
  would need a job runner, and none is installed yet; it's worth adding only if stale air dates
  turn out to matter.
- **A small Faraday client of our own** (`Tmdb::Client`), not a gem. Every TMDB gem on rubygems.org
  is stale or brand new, and the app needs only about six endpoints. Tests stub it with Faraday's
  test adapter and canned JSON, as `test/support/fake_google.rb` does for Google.
- **Images link straight to `image.tmdb.org`.** The base URL is configurable, so tests can point it
  somewhere that doesn't need the network.

The build order is in `docs/implementation-plan.md` (Phases 11–16).

## Settled with the user (2026-10-16)

- **Posters:** small thumbnails in list rows and search results; full size only on a title's page.
- **Streaming country:** US to start. It could become a per-user setting later.
- **Specials:** TMDB's "Season 0" is left out for now.

## Open questions

- Books and podcasts aren't covered by TMDB. Open Library and Podcast Index are the equivalent
  sources if those kinds ever get entry forms.
