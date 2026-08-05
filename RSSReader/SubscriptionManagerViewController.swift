//
//  SubscriptionManagerViewController.swift
//  RSSReader
//

import UIKit

protocol SubscriptionManagerViewControllerDelegate: AnyObject {
    func subscriptionManager(_ viewController: SubscriptionManagerViewController, didChangeDraft categories: [FeedCategory])
    func subscriptionManager(_ viewController: SubscriptionManagerViewController, didUpdate categories: [FeedCategory])
}

final class SubscriptionManagerViewController: UIViewController {
    weak var delegate: SubscriptionManagerViewControllerDelegate?
    private var categories: [FeedCategory]
    private var hasPendingChanges = false
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    init(categories: [FeedCategory]) {
        self.categories = categories
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Library"
        view.backgroundColor = .systemGroupedBackground
        configureNavigationBar()
        configureTableView()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if hasPendingChanges, isMovingFromParent || isBeingDismissed || navigationController?.isBeingDismissed == true {
            delegate?.subscriptionManager(self, didUpdate: categories)
            hasPendingChanges = false
        }
    }

    private func configureNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "folder.badge.plus"), style: .plain, target: self, action: #selector(addCategoryTapped))
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LibraryCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func doneButtonTapped() {
        if hasPendingChanges {
            delegate?.subscriptionManager(self, didUpdate: categories)
            hasPendingChanges = false
        }
        dismiss(animated: true)
    }

    @objc private func addCategoryTapped() {
        presentCategoryEditor(title: "New Category", categoryIndex: nil)
    }

    private func presentCategoryEditor(title: String, categoryIndex: Int?) {
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "Category name"
            if let categoryIndex = categoryIndex {
                textField.text = self.categories[categoryIndex].title
            }
            textField.clearButtonMode = .whileEditing
        }

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alertController.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alertController] _ in
            guard let self = self, let titleText = alertController?.textFields?.first?.text else { return }
            let normalizedTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedTitle.isEmpty else {
                self.showMessage(title: "Missing Name", message: "Enter a category name.")
                return
            }

            if let categoryIndex = categoryIndex {
                self.categories[categoryIndex].title = normalizedTitle
            } else {
                self.categories.append(FeedCategory(title: normalizedTitle, subscriptions: []))
            }

            self.publishLibraryChanges(reloadData: true)
        })

        present(alertController, animated: true)
    }

    private func presentCategoryActions(categoryIndex: Int) {
        let category = categories[categoryIndex]
        let alertController = UIAlertController(title: category.title, message: nil, preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: "Rename Category", style: .default) { [weak self] _ in
            self?.presentCategoryEditor(title: "Rename Category", categoryIndex: categoryIndex)
        })
        alertController.addAction(UIAlertAction(title: "Delete Category", style: .destructive) { [weak self] _ in
            self?.confirmDeleteCategory(categoryIndex: categoryIndex)
        })
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presentActionSheet(alertController)
    }

    private func confirmDeleteCategory(categoryIndex: Int) {
        let category = categories[categoryIndex]
        let message = category.subscriptions.isEmpty ? nil : "This also removes \(category.subscriptions.count) feeds from the library."
        let alertController = UIAlertController(title: "Delete \(category.title)?", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alertController.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.categories.remove(at: categoryIndex)
            if self.categories.isEmpty {
                self.categories.append(FeedCategory(title: "My Feeds", subscriptions: []))
            }
            self.publishLibraryChanges(reloadData: true)
        })
        present(alertController, animated: true)
    }

    private func presentSubscriptionEditor(title: String, categoryIndex: Int, subscriptionIndex: Int? = nil) {
        let subscription = subscriptionIndex.map { categories[categoryIndex].subscriptions[$0] }
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "Name"
            textField.text = subscription?.title
            textField.clearButtonMode = .whileEditing
        }
        alertController.addTextField { textField in
            textField.placeholder = "https://example.com/feed.xml"
            textField.text = subscription?.url
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.clearButtonMode = .whileEditing
            textField.isEnabled = subscription == nil
        }

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        let saveTitle = subscription == nil ? "Subscribe" : "Save"
        alertController.addAction(UIAlertAction(title: saveTitle, style: .default) { [weak self, weak alertController] _ in
            guard let self = self,
                  let titleText = alertController?.textFields?[0].text,
                  let urlText = alertController?.textFields?[1].text else {
                return
            }

            self.saveSubscription(title: titleText, urlString: urlText, categoryIndex: categoryIndex, subscriptionIndex: subscriptionIndex)
        })

        present(alertController, animated: true)
    }

    private func saveSubscription(title: String, urlString: String, categoryIndex: Int, subscriptionIndex: Int?) {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: normalizedURLString),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            showMessage(title: "Invalid RSS URL", message: "Please enter a full RSS URL beginning with http or https.")
            return
        }

        if let subscriptionIndex = subscriptionIndex {
            categories[categoryIndex].subscriptions[subscriptionIndex].title = normalizedTitle.isEmpty ? categories[categoryIndex].subscriptions[subscriptionIndex].title : normalizedTitle
        } else {
            guard !categories.flatMap({ $0.subscriptions }).contains(where: { $0.url == normalizedURLString }) else {
                showMessage(title: "Already Subscribed", message: "This RSS feed is already in your library.")
                return
            }

            let subscription = FeedSubscription(title: normalizedTitle.isEmpty ? url.host ?? "RSS Feed" : normalizedTitle, url: normalizedURLString)
            categories[categoryIndex].subscriptions.append(subscription)
        }

        publishLibraryChanges(reloadData: true)
    }

    private func presentMoveFeedActions(categoryIndex: Int, subscriptionIndex: Int) {
        guard categories.count > 1 else {
            showMessage(title: "No Other Category", message: "Create another category before moving this feed.")
            return
        }

        let subscription = categories[categoryIndex].subscriptions[subscriptionIndex]
        let alertController = UIAlertController(title: "Move \(subscription.title)", message: nil, preferredStyle: .actionSheet)

        categories.indices.filter { $0 != categoryIndex }.forEach { destinationIndex in
            alertController.addAction(UIAlertAction(title: categories[destinationIndex].title, style: .default) { [weak self] _ in
                self?.moveFeed(fromCategory: categoryIndex, subscriptionIndex: subscriptionIndex, toCategory: destinationIndex)
            })
        }

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presentActionSheet(alertController)
    }

    private func moveFeed(fromCategory sourceIndex: Int, subscriptionIndex: Int, toCategory destinationIndex: Int) {
        guard categories.indices.contains(sourceIndex),
              categories[sourceIndex].subscriptions.indices.contains(subscriptionIndex),
              categories.indices.contains(destinationIndex),
              sourceIndex != destinationIndex else {
            return
        }

        let subscription = categories[sourceIndex].subscriptions.remove(at: subscriptionIndex)
        categories[destinationIndex].subscriptions.append(subscription)
        publishLibraryChanges(reloadData: true)
    }

    private func publishLibraryChanges(reloadData: Bool) {
        hasPendingChanges = true
        delegate?.subscriptionManager(self, didChangeDraft: categories)
        if reloadData {
            tableView.reloadData()
        }
    }

    private func presentActionSheet(_ alertController: UIAlertController) {
        if let popoverPresentationController = alertController.popoverPresentationController {
            popoverPresentationController.sourceView = view
            popoverPresentationController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            popoverPresentationController.permittedArrowDirections = []
        }
        present(alertController, animated: true)
    }

    private func showMessage(title: String, message: String?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }
}

extension SubscriptionManagerViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return categories.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories[section].subscriptions.count + 2
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return categories[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LibraryCell", for: indexPath)
        var content = cell.defaultContentConfiguration()

        if indexPath.row == 0 {
            content.image = UIImage(systemName: "folder")
            content.text = "Category Settings"
            content.secondaryText = nil
            cell.accessoryType = .disclosureIndicator
        } else if indexPath.row == categories[indexPath.section].subscriptions.count + 1 {
            content.image = UIImage(systemName: "plus.circle")
            content.text = "Add feed"
            content.secondaryText = nil
            content.textProperties.color = UIColor(red: 0.15, green: 0.68, blue: 0.33, alpha: 1)
            cell.accessoryType = .none
        } else {
            let subscription = categories[indexPath.section].subscriptions[indexPath.row - 1]
            content.image = UIImage(systemName: "rss")
            content.text = subscription.title
            content.secondaryText = subscription.url
            content.secondaryTextProperties.color = .secondaryLabel
            cell.accessoryType = .disclosureIndicator
        }

        cell.contentConfiguration = content
        return cell
    }
}

extension SubscriptionManagerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.row == 0 {
            presentCategoryActions(categoryIndex: indexPath.section)
        } else if indexPath.row == categories[indexPath.section].subscriptions.count + 1 {
            presentSubscriptionEditor(title: "Add RSS Feed", categoryIndex: indexPath.section)
        } else {
            presentSubscriptionEditor(title: "Edit Feed", categoryIndex: indexPath.section, subscriptionIndex: indexPath.row - 1)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row > 0, indexPath.row < categories[indexPath.section].subscriptions.count + 1 else {
            return nil
        }

        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            guard let self = self else { return }
            self.categories[indexPath.section].subscriptions.remove(at: indexPath.row - 1)
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
            self.publishLibraryChanges(reloadData: false)
            completion(true)
        }

        let moveAction = UIContextualAction(style: .normal, title: "Move") { [weak self] _, _, completion in
            self?.presentMoveFeedActions(categoryIndex: indexPath.section, subscriptionIndex: indexPath.row - 1)
            completion(true)
        }
        moveAction.backgroundColor = UIColor(red: 0.15, green: 0.68, blue: 0.33, alpha: 1)

        return UISwipeActionsConfiguration(actions: [deleteAction, moveAction])
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "Use Category Settings for the folder. Swipe left on a feed to move or delete it."
    }
}
