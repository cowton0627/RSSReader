# Roadmap

Known gaps and intended work, as of 2026-08-05. Not a commitment, just what is
already understood to be missing so it does not have to be rediscovered.

## Next

- **Unread-only filter.** Read state exists but cannot be filtered on. The
  natural follow-up to it, and cheap now that `FeedStore` owns the state.
- **Real tabs for Library and Explore.** Both tab items currently present a
  modal sheet and then snap the selection back to Today. They should be actual
  tabs, which probably means a `UITabBarController` instead of the hand-placed
  `UITabBar` in `ViewController`.

## Later

- **Per-feed error reporting.** A single feed that fails to load is silent
  today; the alert only appears when nothing at all could be loaded. Failed
  feeds should be visible, ideally per row in the sidebar.
- **Background refresh.** Feeds are only fetched on launch, on selection
  change, and on pull-to-refresh.
- **Search** across cached articles.
- **Saved or starred articles**, which would need durable storage alongside read
  state rather than in the purgeable cache.
- **Offline reading.** Article bodies are not stored, only summaries; opening a
  story always goes to the network.

## Housekeeping

- **`MyTableView` is inert.** It overrides `intrinsicContentSize` to make the
  table self-sizing, but the storyboard pins the table on all four edges, so its
  size comes entirely from constraints and the override is never consulted.
  Either it goes, or the layout that needed it comes back.
- **The storyboard prototype cell is dead.** `Main.storyboard` carries an
  `RssCell` prototype with `titleLabel` / `dateLabel` / `desLabel` outlets, but
  `configureTableView()` calls `register(RssCell.self, forCellReuseIdentifier:)`,
  which replaces the prototype. Cells are built by `setupView()` and those three
  outlets are always nil. Delete both the prototype's labels and the outlets.
- `RssCell` and the library screens each define the same accent colours inline
  (green `0.15, 0.68, 0.33` and blue `0.10, 0.47, 0.75`). They should be one
  named colour set in the asset catalog.
- `ViewController.swift` is still the largest file at ~650 lines, holding both
  `RssCell` and the list controller. `RssCell` could move to its own file.
- Before making the repo public, confirm nothing personal is tracked:
  `git grep` for Team IDs, and check that `Config/Signing.local.xcconfig` is
  still ignored.
