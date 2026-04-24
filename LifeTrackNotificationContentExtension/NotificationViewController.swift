//
//  NotificationViewController.swift
//  LifeTrackNotificationContentExtension
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import OSLog
import UIKit
import UserNotifications
import UserNotificationsUI

final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private let logger = Logger(
        subsystem: "com.currenttech.LifeTrack.NotificationContentExtension",
        category: "NotificationUI"
    )

    private let iconContainerView = UIView()
    private let iconImageView = UIImageView()
    private let contentStackView = UIStackView()
    private let headerStackView = UIStackView()
    private let textStackView = UIStackView()
    private let statusLabel = InsetLabel()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let footerLabel = UILabel()
    private let metaLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 24
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        setupLayout()
        apply(model: .placeholder)

        logger.debug("viewDidLoad")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        logger.debug("viewDidAppear size=\(self.view.bounds.debugDescription, privacy: .public)")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let targetWidth = max(view.bounds.width, 1)
        let fittingSize = CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height)
        let resolvedSize = view.systemLayoutSizeFitting(
            fittingSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        preferredContentSize = CGSize(width: 0, height: max(186, resolvedSize.height))
    }

    func didReceive(_ notification: UNNotification) {
        logger.debug(
            "didReceive category=\(notification.request.content.categoryIdentifier, privacy: .public) title=\(notification.request.content.title, privacy: .public)"
        )
        apply(model: LifeTrackReminderNotificationModel(content: notification.request.content))
    }

    private func setupLayout() {
        view.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)

        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.spacing = 12
        contentStackView.alignment = .fill

        headerStackView.axis = .horizontal
        headerStackView.spacing = 14
        headerStackView.alignment = .center

        textStackView.axis = .vertical
        textStackView.spacing = 8
        textStackView.alignment = .fill

        iconContainerView.translatesAutoresizingMaskIntoConstraints = false
        iconContainerView.layer.cornerRadius = 18
        iconContainerView.layer.cornerCurve = .continuous

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconContainerView.addSubview(iconImageView)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        statusLabel.insets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        statusLabel.layer.cornerRadius = 12
        statusLabel.layer.cornerCurve = .continuous
        statusLabel.clipsToBounds = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .systemFont(ofSize: 16, weight: .medium)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 3

        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        footerLabel.textColor = .label
        footerLabel.numberOfLines = 2

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = .systemFont(ofSize: 14, weight: .medium)
        metaLabel.textColor = .tertiaryLabel
        metaLabel.numberOfLines = 2

        view.addSubview(contentStackView)
        contentStackView.addArrangedSubview(headerStackView)
        contentStackView.addArrangedSubview(detailLabel)
        contentStackView.addArrangedSubview(footerLabel)
        contentStackView.addArrangedSubview(metaLabel)

        headerStackView.addArrangedSubview(iconContainerView)
        headerStackView.addArrangedSubview(textStackView)

        textStackView.addArrangedSubview(statusLabel)
        textStackView.addArrangedSubview(titleLabel)

        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            contentStackView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),

            iconContainerView.widthAnchor.constraint(equalToConstant: 40),
            iconContainerView.heightAnchor.constraint(equalToConstant: 40),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    private func apply(model: LifeTrackReminderNotificationModel) {
        iconImageView.image = UIImage(systemName: model.symbolName)
        iconContainerView.backgroundColor = model.categoryTint.withAlphaComponent(0.94)

        statusLabel.text = model.statusText
        statusLabel.textColor = model.statusTint
        statusLabel.backgroundColor = model.statusTint.withAlphaComponent(0.12)

        titleLabel.text = model.taskTitle
        detailLabel.text = model.detailText
        footerLabel.text = model.footerText
        metaLabel.text = "\(model.categoryTitle) • \(model.dueDateText) • \(model.dueTimeText)"
    }
}

private final class InsetLabel: UILabel {
    var insets: UIEdgeInsets = .zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}
