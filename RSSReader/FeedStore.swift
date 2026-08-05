//
//  FeedStore.swift
//  RSSReader
//

import Foundation

/// Owns everything the reader persists: the subscription library, and the most
/// recent articles fetched for each feed.
///
/// Categories stay in UserDefaults — a short list of names and URLs. Articles do
/// not: they carry full summaries for every feed, and UserDefaults is read in its
/// entirety at launch, so they go to a JSON file in the caches directory instead.
final class FeedStore {
    private enum Key {
        static let categories = "feedCategories"
        static let legacySubscriptions = "feedSubscriptions"
        static let legacyItemCache = "feedItemCache"
    }

    private static let maximumItemsPerFeed = 50
    private static let defaultCategoryTitle = "My Feeds"

    private let defaults: UserDefaults
    private let itemCacheURL: URL?
    private let persistenceQueue = DispatchQueue(label: "RSSReader.FeedStore.persistence", qos: .utility)

    private(set) var categories: [FeedCategory]
    private var itemsByFeedURL: [String: [RSSItem]]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.itemCacheURL = Self.makeItemCacheURL()
        self.categories = []
        self.itemsByFeedURL = [:]

        self.categories = loadCategories()
        self.itemsByFeedURL = loadItems()
    }

    // MARK: - Library

    func replaceCategories(_ categories: [FeedCategory]) {
        self.categories = categories
        saveCategories()
    }

    func subscriptions(for selection: FeedSelection) -> [FeedSubscription] {
        switch selection {
        case .all:
            return categories.flatMap { $0.subscriptions }
        case .category(let categoryIndex):
            guard categories.indices.contains(categoryIndex) else { return [] }
            return categories[categoryIndex].subscriptions
        case .subscription(let categoryIndex, let subscriptionIndex):
            guard categories.indices.contains(categoryIndex),
                  categories[categoryIndex].subscriptions.indices.contains(subscriptionIndex) else {
                return []
            }

            return [categories[categoryIndex].subscriptions[subscriptionIndex]]
        }
    }

    /// Falls back to `.all` once a selection points at a category or feed that is gone.
    func normalized(_ selection: FeedSelection) -> FeedSelection {
        switch selection {
        case .all:
            return .all
        case .category(let categoryIndex):
            return categories.indices.contains(categoryIndex) ? selection : .all
        case .subscription(let categoryIndex, let subscriptionIndex):
            guard categories.indices.contains(categoryIndex),
                  categories[categoryIndex].subscriptions.indices.contains(subscriptionIndex) else {
                return .all
            }

            return selection
        }
    }

    func title(for selection: FeedSelection) -> String? {
        switch selection {
        case .all:
            return nil
        case .category(let categoryIndex):
            guard categories.indices.contains(categoryIndex) else { return nil }
            return categories[categoryIndex].title
        case .subscription(let categoryIndex, let subscriptionIndex):
            guard categories.indices.contains(categoryIndex),
                  categories[categoryIndex].subscriptions.indices.contains(subscriptionIndex) else {
                return nil
            }

            return categories[categoryIndex].subscriptions[subscriptionIndex].title
        }
    }

    private func loadCategories() -> [FeedCategory] {
        if let data = defaults.data(forKey: Key.categories),
           let categories = try? JSONDecoder().decode([FeedCategory].self, from: data),
           !categories.isEmpty {
            return categories
        }

        // Older builds stored a flat subscription list; fold it into one category.
        if let data = defaults.data(forKey: Key.legacySubscriptions),
           let subscriptions = try? JSONDecoder().decode([FeedSubscription].self, from: data),
           !subscriptions.isEmpty {
            let migratedCategories = [FeedCategory(title: Self.defaultCategoryTitle, subscriptions: subscriptions)]
            save(migratedCategories)
            return migratedCategories
        }

        let defaultCategories = [FeedCategory(title: Self.defaultCategoryTitle, subscriptions: [])]
        save(defaultCategories)
        return defaultCategories
    }

    private func saveCategories() {
        save(categories)
    }

    private func save(_ categories: [FeedCategory]) {
        guard let data = try? JSONEncoder().encode(categories) else { return }
        defaults.set(data, forKey: Key.categories)
    }

    // MARK: - Articles

    /// Merges the cached articles for `subscriptions`, newest first.
    func items(for subscriptions: [FeedSubscription]) -> [RSSItem] {
        subscriptions
            .flatMap { itemsByFeedURL[$0.url] ?? [] }
            .sortedByPublishDate
    }

    func setItems(_ items: [RSSItem], for feedURL: String) {
        itemsByFeedURL[feedURL] = Array(items.prefix(Self.maximumItemsPerFeed))
    }

    /// Drops articles from feeds that are no longer subscribed, then writes the
    /// cache to disk off the main thread.
    func persistItems() {
        let subscribedURLs = Set(categories.flatMap { $0.subscriptions.map { $0.url } })
        itemsByFeedURL = itemsByFeedURL.filter { subscribedURLs.contains($0.key) }

        guard let itemCacheURL, let data = try? JSONEncoder().encode(itemsByFeedURL) else { return }

        persistenceQueue.async {
            try? data.write(to: itemCacheURL, options: .atomic)
        }
    }

    private func loadItems() -> [String: [RSSItem]] {
        if let itemCacheURL,
           let data = try? Data(contentsOf: itemCacheURL),
           let items = try? JSONDecoder().decode([String: [RSSItem]].self, from: data) {
            return items
        }

        // Older builds kept articles in UserDefaults; move them to disk once and
        // clear the key either way, so a corrupt blob is not carried forever.
        let legacyData = defaults.data(forKey: Key.legacyItemCache)
        defaults.removeObject(forKey: Key.legacyItemCache)

        guard let legacyData,
              let legacyItems = try? JSONDecoder().decode([String: [RSSItem]].self, from: legacyData) else {
            return [:]
        }

        if let itemCacheURL {
            try? legacyData.write(to: itemCacheURL, options: .atomic)
        }

        return legacyItems
    }

    private static func makeItemCacheURL() -> URL? {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        return cachesDirectory.appendingPathComponent("RSSReaderFeedCache.json")
    }
}

private extension Array where Element == RSSItem {
    var sortedByPublishDate: [RSSItem] {
        // Parse once per item instead of once per comparison; undated items sink to the bottom.
        map { ($0, $0.publishDate) }
            .sorted { firstItem, secondItem in
                switch (firstItem.1, secondItem.1) {
                case let (firstDate?, secondDate?):
                    return firstDate > secondDate
                case (_?, nil):
                    return true
                default:
                    return false
                }
            }
            .map { $0.0 }
    }
}
