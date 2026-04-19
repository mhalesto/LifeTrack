//
//  NotificationViewController.swift
//  LifeTrackNotificationContentExtension
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import UIKit
import UserNotifications
import UserNotificationsUI

final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .red
    }

    func didReceive(_ notification: UNNotification) {}
}
