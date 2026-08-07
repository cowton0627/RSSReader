# Decisions

Why the code looks the way it does. Newest first.

This file starts on 2026-08-05. Choices made before that — the custom sidebar
container instead of `UISplitViewController`, the `RssCell` layout — left no
record of their reasoning, and no reasoning is invented for them here.

## 2026-08-07 — The app icon is drawn by a script

`Tools/make_app_icon.py` draws the icon with Pillow and writes it straight into
the asset catalog. Nothing about it is hand-painted, so the geometry, the
gradient, and the stroke weight stay adjustable without a design tool and
without anyone having to find the original file.

The mark is the standard RSS broadcast symbol in white, on the same blue the
list header and the unread dot already use, so the icon and the app read as one
thing rather than two palettes. Two alternates were drawn and rejected: a
white-background version, which disappears against pale wallpapers, and an
abstraction of the article list, whose read rows vanished at 60px.

The catalog holds one 1024×1024 entry and lets Xcode derive the rest, which is
the Xcode 14+ single-size format. The PNG is written as RGB rather than RGBA
because App Store submission rejects an icon with an alpha channel.

## 2026-08-05 — Read state lives outside the caches directory

Read state is stored in `Library/Application Support/RSSReaderReadArticles.json`,
not next to the article cache in `Library/Caches/`.

iOS may purge the caches directory under storage pressure. Losing cached
articles costs a re-download; losing reading history cannot be recovered at all.
The two have different value, so they are stored in different places.

Articles are identified by their link, falling back to
`sourceTitle|title|pubDate` for the feeds that omit one. Identifiers whose
articles have aged out of the 50-per-feed cache window are dropped on each
refresh, so the set cannot grow without bound — skipped when the cache is empty,
because that means a failed refresh rather than an empty library.

## 2026-08-05 — Articles moved from UserDefaults to a JSON file

`UserDefaults` is read in full at launch. Categories are a short list of names
and URLs and stay there, but articles carry full summaries for every feed and
had become the bulk of the data — several MB of plist parsed synchronously
before the first frame. They now live in `Library/Caches/RSSReaderFeedCache.json`,
written on a utility queue.

`FeedStore` migrates an existing `feedItemCache` key to the file on first launch
and then clears the key, including when the blob fails to decode, so bad data is
not carried forever.

## 2026-08-05 — Publish dates are parsed by trying a list of formats

RSS publishes RFC 822 timestamps, Atom publishes ISO 8601, and feeds in the wild
drift from both (named zones, missing zones, fractional seconds, date-only).
A single `DateFormatter` silently returned nil for every Atom feed, which sent
those articles to the bottom of the list and showed raw strings as their times.

`ArticleDateParser` tries `ISO8601DateFormatter` first, then a fixed list of
`DateFormatter` patterns. Formatters are built once and held statically — they
are expensive to create, and sorting used to build one per comparison.

Sorting decorates each item with its parsed date once rather than parsing inside
the comparator. Undated articles sort to the bottom instead of an arbitrary
position.

## 2026-08-05 — Signing settings come from a local xcconfig

`project.pbxproj` is tracked, so a Team ID committed there is published to
anyone who reads the repo. Both build configurations now use
`Config/Signing.xcconfig`, which optionally includes the gitignored
`Config/Signing.local.xcconfig`:

```
#include? "Signing.local.xcconfig"
DEVELOPMENT_TEAM = $(LOCAL_DEVELOPMENT_TEAM)
```

Without the local file the setting is simply empty, and simulator builds — which
need no signing — still work. Verified by building with the file moved aside.

Debug and Release had also drifted apart: two different Team IDs and two
different bundle identifiers. Both now resolve to one Team ID from the local
file and one bundle identifier, `com.example.RSSReader`.

Note that `com.example.*` is a reserved placeholder domain. It is fine for
local development but would have to change before any App Store submission.

## 2026-08-05 — Thumbnails are cached in three layers

`NSCache` in memory, then JPEG files under `Library/Caches/RSSReaderThumbnails/`
keyed by a SHA-256 of the image URL, then the network. Downloads are downsampled
through `CGImageSourceCreateThumbnailAtIndex` to 320px before being kept, since
feed images are often far larger than the 126×88 slot they are drawn into.

Cells check `representedImageURL` before applying a loaded image, so a recycled
cell cannot show the previous row's picture.
