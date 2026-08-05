# RSSReader

A UIKit RSS and Atom reader for iOS. Subscribe to feeds, group them into
categories, and read one merged timeline, newest first.

## Requirements

- Xcode 13 or later
- iOS 15.0 or later (simulator or device)

## Running it

The simulator needs no setup: open `RSSReader.xcodeproj`, pick a simulator, run.

For a real device, supply your signing Team ID once:

```sh
cp Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig
```

then set `LOCAL_DEVELOPMENT_TEAM` in that copy. It is gitignored and never
leaves your machine — `project.pbxproj` holds no Team ID at all.

## Using it

- **Today** — the article list for whatever is selected. Pull down to refresh.
- The list button (top left) opens the sidebar: All, a single category, or a
  single feed.
- **+** or the **Library** tab — add, rename, move, and delete feeds and
  categories. Swipe left on a feed to move or delete it.
- **Explore** tab — a built-in directory of feeds to subscribe to in one tap.
- Unread articles carry a blue dot and full-strength text; read ones are dimmed.
  Opening an article marks it read, swiping right on a row toggles it, and
  **Mark all read** in the list header clears the current selection.
- Tapping an article opens it in a Safari view controller.

## Source layout

| File | Responsibility |
| --- | --- |
| `XML.Parser.swift` | Models (`RSSItem`, `FeedSubscription`, `FeedCategory`, `FeedSelection`), the `XMLParser` delegate that reads both RSS and Atom, and publish-date parsing |
| `FeedStore.swift` | All persistence: the library, the article cache, and read state |
| `ViewController.swift` | The Today list, `RssCell`, thumbnail loading, refresh orchestration |
| `SidebarViewController.swift`, `SidebarContainerViewController.swift` | Feed selection panel and its slide-in presentation |
| `SubscriptionManagerViewController.swift` | Library editing |
| `ExploreViewController.swift` | Built-in feed directory |

## Where data lives

| What | Where |
| --- | --- |
| Categories and subscriptions | `UserDefaults`, key `feedCategories` |
| Cached articles, 50 per feed | `Library/Caches/RSSReaderFeedCache.json` |
| Read article identifiers | `Library/Application Support/RSSReaderReadArticles.json` |
| Article thumbnails | `Library/Caches/RSSReaderThumbnails/` |

`DECISIONS.md` explains why storage is split that way. `roadmap.md` lists what
is not built yet.
