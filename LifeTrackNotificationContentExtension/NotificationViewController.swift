//
//  NotificationViewController.swift
//  LifeTrackNotificationContentExtension
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI
import UIKit
import UserNotifications
import UserNotificationsUI

final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private var hostingController: UIHostingController<LifeTrackReminderNotificationView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let hostingController = UIHostingController(
            rootView: LifeTrackReminderNotificationView(
                model: LifeTrackReminderNotificationModel.placeholder
            )
        )
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingController)
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)

        self.hostingController = hostingController
    }

    func didReceive(_ notification: UNNotification) {
        let model = LifeTrackReminderNotificationModel(content: notification.request.content)
        hostingController?.rootView = LifeTrackReminderNotificationView(model: model)
        preferredContentSize = CGSize(width: view.bounds.width, height: 270)
    }
}

