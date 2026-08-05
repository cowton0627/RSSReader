//
//  SidebarViewController.swift
//  RSSReader
//

import UIKit

protocol SidebarViewControllerDelegate: AnyObject {
    func sidebar(_ viewController: SidebarViewController, didSelect selection: FeedSelection)
    func sidebarDidRequestManage(_ viewController: SidebarViewController, in navigationController: UINavigationController?)
}

final class SidebarViewController: UIViewController {
    weak var delegate: SidebarViewControllerDelegate?
    private let categories: [FeedCategory]
    private let selectedSelection: FeedSelection
    private var expandedCategoryIndexes = Set<Int>()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    init(categories: [FeedCategory], selectedSelection: FeedSelection) {
        self.categories = categories
        self.selectedSelection = selectedSelection
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Feeds"
        view.backgroundColor = .systemGroupedBackground
        configureNavigationBar()
        configureTableView()
    }

    private func configureNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Manage", style: .plain, target: self, action: #selector(manageButtonTapped))
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SidebarCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func doneButtonTapped() {
        sidebarContainer?.dismissSidebar()
    }

    @objc private func manageButtonTapped() {
        delegate?.sidebarDidRequestManage(self, in: navigationController)
    }
}

extension SidebarViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return categories.count + 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return 1 }

        let categoryIndex = section - 1
        guard expandedCategoryIndexes.contains(categoryIndex) else {
            return 1
        }

        return categories[categoryIndex].subscriptions.count + 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SidebarCell", for: indexPath)
        var content = cell.defaultContentConfiguration()

        if indexPath.section == 0 {
            content.image = UIImage(systemName: "tray.full")
            content.text = "All"
            cell.accessoryType = selectedSelection == .all ? .checkmark : .none
        } else if indexPath.row == 0 {
            let categoryIndex = indexPath.section - 1
            let isExpanded = expandedCategoryIndexes.contains(categoryIndex)
            content.image = UIImage(systemName: isExpanded ? "folder.fill" : "folder")
            content.text = categories[categoryIndex].title
            content.secondaryText = "\(categories[categoryIndex].subscriptions.count) feeds"
            content.textProperties.font = .systemFont(ofSize: 17, weight: .semibold)
            cell.accessoryType = .none
            cell.accessoryView = UIImageView(image: UIImage(systemName: isExpanded ? "chevron.down" : "chevron.right"))
            cell.accessoryView?.tintColor = .tertiaryLabel
        } else {
            let categoryIndex = indexPath.section - 1
            let subscriptionIndex = indexPath.row - 1
            let subscription = categories[categoryIndex].subscriptions[subscriptionIndex]
            content.image = UIImage(systemName: "rss")
            content.text = subscription.title
            content.secondaryText = nil
            cell.accessoryView = nil
            cell.accessoryType = selectedSelection == .subscription(categoryIndex: categoryIndex, subscriptionIndex: subscriptionIndex) ? .checkmark : .none
        }

        if indexPath.section == 0 {
            cell.accessoryView = nil
        }
        cell.contentConfiguration = content
        return cell
    }
}

extension SidebarViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 {
            sidebarContainer?.dismissSidebar { [weak self] in
                guard let self = self else { return }
                self.delegate?.sidebar(self, didSelect: .all)
            }
            return
        }

        let categoryIndex = indexPath.section - 1
        if indexPath.row == 0 {
            toggleCategory(at: categoryIndex)
            return
        }

        let selection = FeedSelection.subscription(categoryIndex: categoryIndex, subscriptionIndex: indexPath.row - 1)
        sidebarContainer?.dismissSidebar { [weak self] in
            guard let self = self else { return }
            self.delegate?.sidebar(self, didSelect: selection)
        }
    }
    private func toggleCategory(at categoryIndex: Int) {
        if expandedCategoryIndexes.contains(categoryIndex) {
            expandedCategoryIndexes.remove(categoryIndex)
        } else {
            expandedCategoryIndexes.insert(categoryIndex)
        }

        tableView.reloadSections(IndexSet(integer: categoryIndex + 1), with: .automatic)
    }

}


private extension UIViewController {
    var sidebarContainer: SidebarContainerViewController? {
        var currentParent = parent
        while let parent = currentParent {
            if let sidebarContainer = parent as? SidebarContainerViewController {
                return sidebarContainer
            }
            currentParent = parent.parent
        }
        return nil
    }
}
