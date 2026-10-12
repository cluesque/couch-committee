# Introduction

These are some _very_ broad thoughts about how the "Couch Committee" application should work. We expect to expand these into more proper requirements and then implement.

# Application Requirements:

- Modern Rails with hotwire, as little custom javascript as possible
- Optimized for mobile, reasonable on desktop
- Styling: (bootstrap? discuss current best practice)
- minitest test suite with factory_bot
- CI with GitHub Actions, rubocop, brakeman
- Google oauth using google_sign_in
- database: remain agnostic - start configured with sqlite for development, test, production, use only constructs and migration syntax that will work on either sqlite or postgres. Keep an eye on if this is hurting us and we get to a point where postgres features makes sense.
- clean, simple architecture - nothing super fancy

# Models

User - email, display_name
Group - has_many users, has_many lists
Title - type: [movie series book podcast], name: text, season_number: int
Episode - name, number, available_on date - belongs_to :title
Viewing - date, group, (episode | title), belongs_to :list_entry
Recommendation - belongs_to title, notes:text [belongs_to :group?]
PlayList - name: text, description: text, has_many :titles, belongs_to :group
ListEntry - belongs_to list, sequence: int

# User stories

- a User authenticates with google oauth
- a logged in User can log out
- Watching a movie checks it off on all playlists for that group
- Viewing a playlist shows title, next episode (if any), last viewing (if any)
- The default view of a playlist shows not-yet-viewed recommendations in a view order
- each row in the playlist has the title and a drag handle for reordering
- A PlayList entry for a Season where all of the not-yet-watched episodes have an available_on in the future is visually different from Seasons with available unwatched episodes
- The historical version of a playlist shows what was viewed and when (order by view date)
- Watching an episode updates playlist "next episode", if it's the last episode removes the season from the default playlist view
- Watching the last episode of a season removes the season from the (unviewed) playlist
- Watching a movie removes it from the playlist
- PlayList member can add a movie to a playlist
- PlayList member can add a season of a show to a playlist
- PlayList member can reorder recommendations in a playlist
- PlayList member can see many PlayLists, drill down to view a PlayList
- PlayList member can drill down into a PlayList to show description, users
- PlayList member can invite (or remove) other Users to PlayList
- PlayList member can "Cancel" a Recommendation, leaving an optional note about why, can be viewed in the historical view of a playlist
- A PlayList has a Season, but a Group Watches an Episode
- Tap a Recommendation in a PlayList to see detail
  - a "Watch" button in the detail allows marking as watched
- The Watch button in a Recommendation opens a form for recording a watch, defaults to the next unwatched Episode and a watch date of today, with options to change either

# Future ideas currently out of scope:

- Mechanism for importing seasons and episodes
- Understanding of streaming services and awareness of availability
- Avatars for users
