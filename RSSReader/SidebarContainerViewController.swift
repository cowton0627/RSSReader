//
//  SidebarContainerViewController.swift
//  RSSReader
//

import UIKit

final class SidebarContainerViewController: UIViewController {
    private let contentViewController: UIViewController
    private let dimmingView = UIView()
    private let panelView = UIView()
    private var panelLeadingConstraint: NSLayoutConstraint?

    init(contentViewController: UIViewController) {
        self.contentViewController = contentViewController
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureDimmingView()
        configurePanel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.layoutIfNeeded()
        animatePanel(isPresented: true)
    }

    private func configureDimmingView() {
        view.backgroundColor = .clear
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.22)
        dimmingView.alpha = 0
        view.addSubview(dimmingView)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dimmingViewTapped))
        dimmingView.addGestureRecognizer(tapGesture)

        NSLayoutConstraint.activate([
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configurePanel() {
        panelView.translatesAutoresizingMaskIntoConstraints = false
        panelView.backgroundColor = .systemBackground
        panelView.layer.shadowColor = UIColor.black.cgColor
        panelView.layer.shadowOpacity = 0.16
        panelView.layer.shadowRadius = 18
        panelView.layer.shadowOffset = CGSize(width: 4, height: 0)
        view.addSubview(panelView)

        addChild(contentViewController)
        contentViewController.view.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(contentViewController.view)
        contentViewController.didMove(toParent: self)

        let panelWidth = min(UIScreen.main.bounds.width * 0.86, 340)
        panelLeadingConstraint = panelView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -panelWidth)

        NSLayoutConstraint.activate([
            panelLeadingConstraint!,
            panelView.topAnchor.constraint(equalTo: view.topAnchor),
            panelView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            panelView.widthAnchor.constraint(equalToConstant: panelWidth),

            contentViewController.view.topAnchor.constraint(equalTo: panelView.topAnchor),
            contentViewController.view.leadingAnchor.constraint(equalTo: panelView.leadingAnchor),
            contentViewController.view.trailingAnchor.constraint(equalTo: panelView.trailingAnchor),
            contentViewController.view.bottomAnchor.constraint(equalTo: panelView.bottomAnchor)
        ])
    }

    @objc private func dimmingViewTapped() {
        dismissSidebar()
    }

    func dismissSidebar(completion: (() -> Void)? = nil) {
        animatePanel(isPresented: false) { [weak self] in
            self?.dismiss(animated: false) {
                completion?()
            }
        }
    }

    private func animatePanel(isPresented: Bool, completion: (() -> Void)? = nil) {
        panelLeadingConstraint?.constant = isPresented ? 0 : -panelView.bounds.width

        UIView.animate(
            withDuration: 0.34,
            delay: 0,
            usingSpringWithDamping: 0.88,
            initialSpringVelocity: 0.25,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            self.dimmingView.alpha = isPresented ? 1 : 0
            self.view.layoutIfNeeded()
        } completion: { _ in
            completion?()
        }
    }
}
