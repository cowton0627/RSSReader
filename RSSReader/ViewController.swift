//
//  ViewController.swift
//  RSSReader
//
//  Created by Chun-Li Cheng on 2021/12/20.
//

import UIKit
import SafariServices
import CryptoKit
import ImageIO

class RssCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var desLabel: UILabel!

    private static let imageCache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 200
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()
    private static let thumbnailCacheDirectory: URL? = {
        guard let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directory = cacheDirectory.appendingPathComponent("RSSReaderThumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()
    private static let thumbnailPixelSize: CGFloat = 320
    private var representedImageURL: URL?

    private let headlineLabel = UILabel()
    private let summaryLabel = UILabel()
    private let metadataLabel = UILabel()
    private let thumbnailView = UIImageView()
    private let placeholderView = UIView()
    private let placeholderIcon = UIImageView(image: UIImage(systemName: "newspaper"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        representedImageURL = nil
        thumbnailView.image = nil
        placeholderView.isHidden = false
    }

    var item: RSSItem? {
        didSet {
            guard let item = item else { return }
            headlineLabel.text = item.title
            summaryLabel.text = item.description.isEmpty ? "Open the story for the full article" : "↗ " + item.description
            metadataLabel.text = "•  \(item.sourceTitle) / \(item.relativePublishTime)"
            loadImage(from: item.imageURL)
        }
    }

    private func setupView() {
        selectionStyle = .none
        backgroundColor = .systemBackground
        contentView.backgroundColor = .systemBackground
        contentView.layoutMargins = UIEdgeInsets(top: 22, left: 18, bottom: 22, right: 18)

        headlineLabel.font = .systemFont(ofSize: 20, weight: .bold)
        headlineLabel.textColor = .label
        headlineLabel.numberOfLines = 3
        headlineLabel.lineBreakMode = .byTruncatingTail
        headlineLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        summaryLabel.font = .systemFont(ofSize: 17, weight: .regular)
        summaryLabel.textColor = UIColor(red: 0.15, green: 0.68, blue: 0.33, alpha: 1)
        summaryLabel.numberOfLines = 2
        summaryLabel.lineBreakMode = .byTruncatingTail

        metadataLabel.font = .systemFont(ofSize: 16, weight: .regular)
        metadataLabel.textColor = .secondaryLabel
        metadataLabel.numberOfLines = 1

        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.clipsToBounds = true
        thumbnailView.layer.cornerRadius = 6
        thumbnailView.backgroundColor = .secondarySystemBackground

        placeholderView.backgroundColor = UIColor(red: 0.94, green: 0.96, blue: 0.95, alpha: 1)
        placeholderView.layer.cornerRadius = 6
        placeholderView.clipsToBounds = true
        placeholderIcon.tintColor = UIColor(red: 0.15, green: 0.68, blue: 0.33, alpha: 1)
        placeholderIcon.contentMode = .scaleAspectFit

        let textStack = UIStackView(arrangedSubviews: [headlineLabel, summaryLabel, metadataLabel])
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.alignment = .fill

        [textStack, thumbnailView, placeholderView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        placeholderIcon.translatesAutoresizingMaskIntoConstraints = false
        placeholderView.addSubview(placeholderIcon)

        NSLayoutConstraint.activate([
            thumbnailView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 4),
            thumbnailView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            thumbnailView.widthAnchor.constraint(equalToConstant: 126),
            thumbnailView.heightAnchor.constraint(equalToConstant: 88),

            placeholderView.topAnchor.constraint(equalTo: thumbnailView.topAnchor),
            placeholderView.leadingAnchor.constraint(equalTo: thumbnailView.leadingAnchor),
            placeholderView.trailingAnchor.constraint(equalTo: thumbnailView.trailingAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: thumbnailView.bottomAnchor),

            placeholderIcon.centerXAnchor.constraint(equalTo: placeholderView.centerXAnchor),
            placeholderIcon.centerYAnchor.constraint(equalTo: placeholderView.centerYAnchor),
            placeholderIcon.widthAnchor.constraint(equalToConstant: 28),
            placeholderIcon.heightAnchor.constraint(equalToConstant: 28),

            textStack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            textStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            textStack.trailingAnchor.constraint(equalTo: thumbnailView.leadingAnchor, constant: -18),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.bottomAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 144)
        ])
    }

    private func loadImage(from imageURL: String?) {
        guard let imageURL = imageURL, let url = URL(string: imageURL) else {
            thumbnailView.image = nil
            placeholderView.isHidden = false
            return
        }

        representedImageURL = url
        if let cachedImage = Self.imageCache.object(forKey: url as NSURL) {
            thumbnailView.image = cachedImage
            placeholderView.isHidden = true
            return
        }

        if let diskURL = Self.cachedThumbnailURL(for: url), FileManager.default.fileExists(atPath: diskURL.path) {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let data = try? Data(contentsOf: diskURL),
                      let image = Self.downsampledImage(from: data) else {
                    return
                }

                Self.imageCache.setObject(image, forKey: url as NSURL, cost: image.cacheCost)
                DispatchQueue.main.async {
                    guard self?.representedImageURL == url else { return }
                    self?.thumbnailView.image = image
                    self?.placeholderView.isHidden = true
                }
            }
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
            guard let self = self,
                  self.representedImageURL == url,
                  let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode,
                  let data = data,
                  data.count > 128,
                  Self.responseLooksLikeImage(httpResponse, url: url),
                  let image = Self.downsampledImage(from: data) else {
                return
            }

            Self.imageCache.setObject(image, forKey: url as NSURL, cost: image.cacheCost)
            Self.persist(image, for: url)
            DispatchQueue.main.async {
                guard self.representedImageURL == url else { return }
                self.thumbnailView.image = image
                self.placeholderView.isHidden = true
            }
        }.resume()
    }

    private static func responseLooksLikeImage(_ response: HTTPURLResponse, url: URL) -> Bool {
        if let mimeType = response.mimeType?.lowercased(), mimeType.hasPrefix("image/") {
            return true
        }

        return ["jpg", "jpeg", "png", "webp", "gif", "heic"].contains(url.pathExtension.lowercased())
    }

    private static func downsampledImage(from data: Data) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
            return nil
        }

        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailPixelSize
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private static func persist(_ image: UIImage, for url: URL) {
        guard let diskURL = cachedThumbnailURL(for: url),
              let data = image.jpegData(compressionQuality: 0.82) else {
            return
        }

        try? data.write(to: diskURL, options: .atomic)
    }

    private static func cachedThumbnailURL(for url: URL) -> URL? {
        guard let thumbnailCacheDirectory else { return nil }
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let filename = digest.map { String(format: "%02x", $0) }.joined() + ".jpg"
        return thumbnailCacheDirectory.appendingPathComponent(filename)
    }
}

private extension UIImage {
    var cacheCost: Int {
        guard let cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

class ViewController: UIViewController {
    @IBOutlet weak var myTableView: MyTableView!
    private let categoriesKey = "feedCategories"
    private let feedItemCacheKey = "feedItemCache"
    private let legacySubscriptionsKey = "feedSubscriptions"
    private var rssItems: [RSSItem] = []
    private var categories: [FeedCategory] = []
    private var selectedSelection: FeedSelection = .all
    private var feedItemCache: [String: [RSSItem]] = [:]
    private var activeRefreshID = UUID()
    private var isApplyingAnimatedUpdate = false
    private var collectionLabel = UILabel()
    private let bottomTabBar = UITabBar()

    override func viewDidLoad() {
        super.viewDidLoad()
        categories = loadCategories()
        feedItemCache = loadFeedItemCache()
        configureNavigationBar()
        configureTableView()
        configureBottomTabBar()
        applyCachedItems(for: subscriptions(for: selectedSelection))
        fetchData()
    }

//https://developer.apple.com/news/rss/news.rss
//https://www.apple.com/newsroom/rss-feed.rss
//https://news.ltn.com.tw/rss/business.xml
//https://www.ptt.cc/atom/movie.xml

    private func fetchData() {
        activeRefreshID = UUID()
        let refreshID = activeRefreshID
        let selectedSubscriptions = subscriptions(for: selectedSelection)

        applyCachedItems(for: selectedSubscriptions)

        guard !selectedSubscriptions.isEmpty else {
            myTableView.refreshControl?.endRefreshing()
            return
        }

        let dispatchGroup = DispatchGroup()
        var loadedItemsByURL: [String: [RSSItem]] = [:]
        var failedFeeds: [FeedSubscription] = []
        let updateQueue = DispatchQueue(label: "RSSReader.feedUpdates")

        selectedSubscriptions.forEach { subscription in
            dispatchGroup.enter()
            let feedParser = FeedParser()
            feedParser.parseFeed(url: subscription.url, sourceTitle: subscription.title) { result in
                updateQueue.async {
                    switch result {
                    case .success(let items):
                        loadedItemsByURL[subscription.url] = items
                    case .failure:
                        failedFeeds.append(subscription)
                    }
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            // A stale round leaves the spinner alone — the active refresh will stop it.
            guard let self = self, self.activeRefreshID == refreshID else { return }
            self.myTableView.refreshControl?.endRefreshing()

            loadedItemsByURL.forEach { url, items in
                self.feedItemCache[url] = Array(items.prefix(50))
            }

            self.saveFeedItemCache()
            self.applyCachedItems(for: selectedSubscriptions)

            if self.rssItems.isEmpty, !failedFeeds.isEmpty {
                self.showMessage(title: "Unable to Load Feeds", message: "Check the RSS URL and try again.")
            }
        }
    }

    private func applyCachedItems(for subscriptions: [FeedSubscription]) {
        rssItems = subscriptions
            .flatMap { feedItemCache[$0.url] ?? [] }
            .sortedByPublishDate

        let updates = {
            self.updateHeaderTitle()
            self.myTableView.reloadData()
        }

        if isApplyingAnimatedUpdate {
            UIView.transition(
                with: myTableView,
                duration: 0.20,
                options: [.transitionCrossDissolve, .allowUserInteraction],
                animations: updates
            )
        } else {
            updates()
        }
    }

    private func loadCategories() -> [FeedCategory] {
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let categories = try? JSONDecoder().decode([FeedCategory].self, from: data),
           !categories.isEmpty {
            return categories
        }

        if let data = UserDefaults.standard.data(forKey: legacySubscriptionsKey),
           let subscriptions = try? JSONDecoder().decode([FeedSubscription].self, from: data),
           !subscriptions.isEmpty {
            let migratedCategories = [FeedCategory(title: "My Feeds", subscriptions: subscriptions)]
            saveCategories(migratedCategories)
            return migratedCategories
        }

        let defaultCategories = [FeedCategory(title: "My Feeds", subscriptions: [])]
        saveCategories(defaultCategories)
        return defaultCategories
    }

    private func saveCategories() {
        saveCategories(categories)
    }

    private func saveCategories(_ categories: [FeedCategory]) {
        guard let data = try? JSONEncoder().encode(categories) else {
            return
        }

        UserDefaults.standard.set(data, forKey: categoriesKey)
        UserDefaults.standard.synchronize()
    }

    private func loadFeedItemCache() -> [String: [RSSItem]] {
        guard let data = UserDefaults.standard.data(forKey: feedItemCacheKey),
              let cache = try? JSONDecoder().decode([String: [RSSItem]].self, from: data) else {
            return [:]
        }

        return cache
    }

    private func saveFeedItemCache() {
        let activeURLs = Set(categories.flatMap { $0.subscriptions.map { $0.url } })
        let cacheToPersist = feedItemCache.reduce(into: [String: [RSSItem]]()) { partialResult, entry in
            guard activeURLs.contains(entry.key) else { return }
            partialResult[entry.key] = Array(entry.value.prefix(50))
        }

        guard let data = try? JSONEncoder().encode(cacheToPersist) else {
            return
        }

        UserDefaults.standard.set(data, forKey: feedItemCacheKey)
        UserDefaults.standard.synchronize()
    }

    private func subscriptions(for selection: FeedSelection) -> [FeedSubscription] {
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

    private func updateHeaderTitle() {
        switch selectedSelection {
        case .all:
            collectionLabel.text = "All Feeds"
        case .category(let categoryIndex):
            collectionLabel.text = categories.indices.contains(categoryIndex) ? categories[categoryIndex].title : "Category"
        case .subscription(let categoryIndex, let subscriptionIndex):
            if categories.indices.contains(categoryIndex), categories[categoryIndex].subscriptions.indices.contains(subscriptionIndex) {
                collectionLabel.text = categories[categoryIndex].subscriptions[subscriptionIndex].title
            } else {
                collectionLabel.text = "Feed"
            }
        }
    }

    private func showMessage(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }

    private func configureNavigationBar() {
        title = "Today"
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.tintColor = .secondaryLabel

        let manageButton = UIButton(type: .system)
        manageButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        manageButton.layer.cornerRadius = 15
        manageButton.layer.borderWidth = 1
        manageButton.layer.borderColor = UIColor.separator.cgColor
        manageButton.setImage(UIImage(systemName: "list.bullet"), for: .normal)
        manageButton.tintColor = .secondaryLabel
        manageButton.addTarget(self, action: #selector(manageSubscriptionsTapped), for: .touchUpInside)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: manageButton)

        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "plus"), style: .plain, target: self, action: #selector(addButtonTapped))
    }

    private func configureTableView() {
        myTableView.register(RssCell.self, forCellReuseIdentifier: "RssCell")
        myTableView.separatorStyle = .none
        myTableView.backgroundColor = .systemBackground
        myTableView.rowHeight = UITableView.automaticDimension
        myTableView.estimatedRowHeight = 164
        myTableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 90, right: 0)
        myTableView.scrollIndicatorInsets = myTableView.contentInset
        myTableView.tableHeaderView = makeHeaderView()

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshControlPulled), for: .valueChanged)
        myTableView.refreshControl = refreshControl
    }

    @objc private func refreshControlPulled() {
        fetchData()
    }

    private func configureBottomTabBar() {
        bottomTabBar.translatesAutoresizingMaskIntoConstraints = false
        bottomTabBar.delegate = self
        bottomTabBar.backgroundColor = .systemBackground

        let todayItem = UITabBarItem(title: "Today", image: UIImage(systemName: "newspaper"), tag: 0)
        let libraryItem = UITabBarItem(title: "Library", image: UIImage(systemName: "books.vertical"), tag: 1)
        let exploreItem = UITabBarItem(title: "Explore", image: UIImage(systemName: "magnifyingglass"), tag: 2)
        bottomTabBar.items = [todayItem, libraryItem, exploreItem]
        bottomTabBar.selectedItem = todayItem

        view.addSubview(bottomTabBar)
        NSLayoutConstraint.activate([
            bottomTabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomTabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomTabBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    @objc private func addButtonTapped() {
        presentLibraryManager()
    }

    @objc private func manageSubscriptionsTapped() {
        presentSidebar()
    }

    private func presentSidebar() {
        let sidebarViewController = SidebarViewController(categories: categories, selectedSelection: selectedSelection)
        sidebarViewController.delegate = self
        let navigationController = UINavigationController(rootViewController: sidebarViewController)
        let containerViewController = SidebarContainerViewController(contentViewController: navigationController)
        present(containerViewController, animated: false)
    }

    private func makeHeaderView() -> UIView {
        let headerWidth = max(view.bounds.width, UIScreen.main.bounds.width)
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: headerWidth, height: 68))
        headerView.backgroundColor = .systemBackground

        collectionLabel = UILabel(frame: CGRect(x: 18, y: 0, width: max(headerWidth - 36, 0), height: 67.5))
        updateHeaderTitle()
        collectionLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionLabel.font = .systemFont(ofSize: 18, weight: .bold)
        collectionLabel.textColor = UIColor(red: 0.10, green: 0.47, blue: 0.75, alpha: 1)

        let separator = UIView(frame: CGRect(x: 0, y: 67.5, width: headerWidth, height: 0.5))
        separator.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        separator.backgroundColor = .separator

        headerView.addSubview(collectionLabel)
        headerView.addSubview(separator)
        return headerView
    }
}




extension ViewController: UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        switch item.tag {
        case 0:
            myTableView.setContentOffset(CGPoint(x: 0, y: -myTableView.adjustedContentInset.top), animated: true)
        case 1:
            presentLibraryManager()
            tabBar.selectedItem = tabBar.items?.first
        case 2:
            presentExplore()
            tabBar.selectedItem = tabBar.items?.first
        default:
            break
        }
    }

    private func presentExplore() {
        let exploreViewController = ExploreViewController()
        exploreViewController.delegate = self
        let navigationController = UINavigationController(rootViewController: exploreViewController)
        navigationController.modalPresentationStyle = .pageSheet
        if let sheetPresentationController = navigationController.sheetPresentationController {
            sheetPresentationController.detents = [.large()]
            sheetPresentationController.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
    }
}

extension ViewController: ExploreViewControllerDelegate {
    func exploreViewController(_ viewController: ExploreViewController, didChoose subscription: FeedSubscription) {
        guard !categories.flatMap({ $0.subscriptions }).contains(where: { $0.url == subscription.url }) else {
            showMessage(title: "Already Subscribed", message: "This RSS feed is already in your library.")
            return
        }

        if categories.isEmpty {
            categories.append(FeedCategory(title: "My Feeds", subscriptions: []))
        }

        categories[0].subscriptions.append(subscription)
        saveCategories()
        selectedSelection = .subscription(categoryIndex: 0, subscriptionIndex: categories[0].subscriptions.count - 1)
        applyCachedItems(for: subscriptions(for: selectedSelection))
        fetchData()
        viewController.dismiss(animated: true)
    }
}

extension ViewController: SidebarViewControllerDelegate {
    func sidebar(_ viewController: SidebarViewController, didSelect selection: FeedSelection) {
        selectedSelection = selection
        isApplyingAnimatedUpdate = true
        fetchData()
        isApplyingAnimatedUpdate = false
    }

    func sidebarDidRequestManage(_ viewController: SidebarViewController, in navigationController: UINavigationController?) {
        let managerViewController = makeLibraryManager()
        navigationController?.pushViewController(managerViewController, animated: true)
    }
}

extension ViewController: SubscriptionManagerViewControllerDelegate {
    func subscriptionManager(_ viewController: SubscriptionManagerViewController, didChangeDraft categories: [FeedCategory]) {
        self.categories = categories
        saveCategories()
    }

    func subscriptionManager(_ viewController: SubscriptionManagerViewController, didUpdate categories: [FeedCategory]) {
        self.categories = categories
        saveCategories()
        selectedSelection = normalizedSelection(selectedSelection)
        pruneFeedCache()
        applyCachedItems(for: subscriptions(for: selectedSelection))
        fetchData()
    }

    private func presentLibraryManager() {
        let navigationController = UINavigationController(rootViewController: makeLibraryManager())
        navigationController.modalPresentationStyle = .pageSheet
        if let sheetPresentationController = navigationController.sheetPresentationController {
            sheetPresentationController.detents = [.large()]
            sheetPresentationController.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
    }

    private func makeLibraryManager() -> SubscriptionManagerViewController {
        let managerViewController = SubscriptionManagerViewController(categories: categories)
        managerViewController.delegate = self
        return managerViewController
    }


    private func pruneFeedCache() {
        let activeURLs = Set(categories.flatMap { $0.subscriptions.map { $0.url } })
        feedItemCache = feedItemCache.filter { activeURLs.contains($0.key) }
        saveFeedItemCache()
    }

    private func normalizedSelection(_ selection: FeedSelection) -> FeedSelection {
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
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rssItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "RssCell", for: indexPath) as? RssCell else {
            return UITableViewCell()
        }

        cell.item = rssItems[indexPath.row]
        return cell
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let url = URL(string: rssItems[indexPath.row].link) else {
            return
        }

        let articleViewController = SFSafariViewController(url: url)
        present(articleViewController, animated: true)
    }
}

private extension RSSItem {
    var relativePublishTime: String {
        guard let date = pubDate.rssDate else {
            return pubDate
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private enum ArticleDateParser {
    // Atom feeds publish ISO 8601 dates, RSS feeds publish RFC 822 ones,
    // and plenty of feeds drift from both. Try the strict parsers first.
    private static let iso8601Formatters: [ISO8601DateFormatter] = {
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]

        let fractionalSeconds = ISO8601DateFormatter()
        fractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return [standard, fractionalSeconds]
    }()

    private static let fallbackFormatters: [DateFormatter] = [
        "E, d MMM yyyy HH:mm:ss Z",
        "E, d MMM yyyy HH:mm:ss zzz",
        "E, d MMM yyyy HH:mm Z",
        "yyyy-MM-dd'T'HH:mm:ssXXXXX",
        "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss Z",
        "yyyy-MM-dd"
    ].map { dateFormat in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = dateFormat
        return formatter
    }

    static func date(from string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        for formatter in iso8601Formatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        for formatter in fallbackFormatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }
}

private extension String {
    var rssDate: Date? {
        ArticleDateParser.date(from: self)
    }
}


private extension Array where Element == RSSItem {
    var sortedByPublishDate: [RSSItem] {
        // Parse once per item instead of once per comparison; undated items sink to the bottom.
        map { ($0, $0.pubDate.rssDate) }
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
