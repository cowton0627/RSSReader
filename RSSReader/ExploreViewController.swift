//
//  ExploreViewController.swift
//  RSSReader
//

import UIKit

protocol ExploreViewControllerDelegate: AnyObject {
    func exploreViewController(_ viewController: ExploreViewController, didChoose subscription: FeedSubscription)
}

final class ExploreViewController: UIViewController {
    weak var delegate: ExploreViewControllerDelegate?
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let sections: [(title: String, feeds: [FeedSubscription])] = [
        (
            title: "Public & Global News",
            feeds: [
                FeedSubscription(title: "BBC News", url: "https://feeds.bbci.co.uk/news/rss.xml"),
                FeedSubscription(title: "BBC World", url: "https://feeds.bbci.co.uk/news/world/rss.xml"),
                FeedSubscription(title: "PBS NewsHour", url: "https://www.pbs.org/newshour/feeds/rss/headlines"),
                FeedSubscription(title: "The Guardian World", url: "https://www.theguardian.com/world/rss"),
                FeedSubscription(title: "Le Monde English", url: "https://www.lemonde.fr/en/rss/une.xml")
            ]
        ),
        (
            title: "Business & Technology",
            feeds: [
                FeedSubscription(title: "BBC Technology", url: "https://feeds.bbci.co.uk/news/technology/rss.xml"),
                FeedSubscription(title: "BBC Business", url: "https://feeds.bbci.co.uk/news/business/rss.xml"),
                FeedSubscription(title: "The Guardian Technology", url: "https://www.theguardian.com/technology/rss"),
                FeedSubscription(title: "Apple Newsroom", url: "https://www.apple.com/newsroom/rss-feed.rss"),
                FeedSubscription(title: "Apple Developer News", url: "https://developer.apple.com/news/rss/news.rss")
            ]
        ),
        (
            title: "Education & Research",
            feeds: [
                FeedSubscription(title: "MIT Latest News", url: "https://news.mit.edu/rss/feed"),
                FeedSubscription(title: "MIT Education", url: "https://news.mit.edu/rss/topic/education"),
                FeedSubscription(title: "Harvard Gazette", url: "https://news.harvard.edu/gazette/feed"),
                FeedSubscription(title: "Harvard Science & Technology", url: "https://news.harvard.edu/gazette/section/science-technology/feed/"),
                FeedSubscription(title: "Cornell Artificial Intelligence", url: "https://news.cornell.edu/taxonomy/term/24043/feed"),
                FeedSubscription(title: "Cornell Continuing Education", url: "https://news.cornell.edu/taxonomy/term/34/feed")
            ]
        ),
        (
            title: "Science & Culture",
            feeds: [
                FeedSubscription(title: "NASA Recently Published", url: "https://www.nasa.gov/feed/"),
                FeedSubscription(title: "NASA Technology", url: "https://www.nasa.gov/technology/feed/"),
                FeedSubscription(title: "Smithsonian Latest", url: "https://www.smithsonianmag.com/rss/latest_articles/"),
                FeedSubscription(title: "Smithsonian Science", url: "https://www.smithsonianmag.com/rss/science-nature/")
            ]
        ),
        (
            title: "Taiwan & Communities",
            feeds: [
                FeedSubscription(title: "自由時報財經", url: "https://news.ltn.com.tw/rss/business.xml"),
                FeedSubscription(title: "PTT Movie", url: "https://www.ptt.cc/atom/movie.xml")
            ]
        )
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Explore"
        view.backgroundColor = .systemGroupedBackground
        configureNavigationBar()
        configureTableView()
    }

    private func configureNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ExploreCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func doneButtonTapped() {
        dismiss(animated: true)
    }

    private func subscription(at indexPath: IndexPath) -> FeedSubscription {
        return sections[indexPath.section].feeds[indexPath.row]
    }
}

extension ExploreViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].feeds.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExploreCell", for: indexPath)
        let feed = subscription(at: indexPath)
        var content = cell.defaultContentConfiguration()
        content.image = UIImage(systemName: "rss")
        content.text = feed.title
        content.secondaryText = URL(string: feed.url)?.host
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        cell.accessoryType = .none
        return cell
    }
}

extension ExploreViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let subscription = subscription(at: indexPath)
        let alertController = UIAlertController(title: "Subscribe to \(subscription.title)?", message: subscription.url, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alertController.addAction(UIAlertAction(title: "Subscribe", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.exploreViewController(self, didChoose: subscription)
        })
        present(alertController, animated: true)
    }
}
