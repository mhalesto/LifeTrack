//
//  LifeTrackControlWidgetBundle.swift
//  LifeTrackControlWidget
//

import WidgetKit
import SwiftUI

@main
struct LifeTrackControlWidgetBundle: WidgetBundle {
    var body: some Widget {
        LifeTrackControlWidget()
        MoneyWidget()
        LifeTrackControlWidgetControl()
        NewBlankTaskControl()
        TodaysFocusControl()
        QuickCompleteControl()
        LifeTrackControlWidgetLiveActivity()
    }
}
