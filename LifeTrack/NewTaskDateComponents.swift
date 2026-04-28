//
//  NewTaskDateComponents.swift
//  LifeTrack
//
//  Date-picker UI extracted from NewTaskView. Each type is self-contained
//  and takes its inputs as parameters or bindings.
//

import SwiftUI

enum DueDatePickerMode: String, Identifiable {
    case date
    case time

    var id: String { rawValue }

    var title: String {
        switch self {
        case .date: "Choose Date"
        case .time: "Choose Time"
        }
    }

    var subtitle: String {
        switch self {
        case .date: "Pick a reminder day."
        case .time: "Set the task time."
        }
    }

    var symbolName: String {
        switch self {
        case .date: "calendar"
        case .time: "clock"
        }
    }

    var presentationDetent: PresentationDetent {
        switch self {
        case .date: .height(590)
        case .time: .height(450)
        }
    }
}

struct DateSelectionRow: View {
    let title: String
    let value: String
    let symbolName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .frame(width: 32, height: 32)
                    .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Spacer(minLength: LifeTrackTheme.Spacing.medium)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(LifeTrackTheme.ColorPalette.accentSoft.opacity(0.72), in: Capsule())

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
            }
            .frame(minHeight: 50)
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.985, pressedOpacity: 0.94))
    }
}

struct DueDatePickerSheet: View {
    let mode: DueDatePickerMode
    @Binding var dueDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                sheetHeader

                if mode == .date {
                    themedDatePicker
                } else {
                    themedTimePicker
                }
            }
            .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
            .padding(.top, LifeTrackTheme.Spacing.medium)
            .padding(.bottom, LifeTrackTheme.Spacing.xLarge)
        }
    }

    private var sheetHeader: some View {
        HStack(alignment: .center, spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: mode.symbolName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                .frame(width: 44, height: 44)
                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(mode.title)
                    .font(.lifeTrack(.title3, weight: .bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(1)

                Text(mode.subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: LifeTrackTheme.Spacing.small)

            Button("Done") {
                dismiss()
            }
            .font(.callout.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(LifeTrackTheme.ColorPalette.accentGradient, in: Capsule())
            .shadow(color: LifeTrackTheme.ColorPalette.accent.opacity(0.18), radius: 10, x: 0, y: 6)
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96, pressedOpacity: 0.94))
        }
    }

    private var themedDatePicker: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            HStack {
                Text(dueDate.weekdayDateString)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Spacer(minLength: LifeTrackTheme.Spacing.medium)

                Text(dueDate.formatted(Date.FormatStyle().year()))
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(LifeTrackTheme.ColorPalette.accentSoft, in: Capsule())
            }

            DatePicker("", selection: $dueDate, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.graphical)
                .tint(LifeTrackTheme.ColorPalette.accent)
                .padding(10)
                .environment(\.colorScheme, .light)
                .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                        .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.82), lineWidth: 0.8)
                }
                .shadow(color: LifeTrackTheme.ColorPalette.shadow.opacity(0.08), radius: 14, x: 0, y: 8)

            HStack(spacing: 8) {
                DateShortcutChip(title: "Today", isSelected: isSelectedDate(offset: 0)) {
                    setDate(offset: 0)
                }
                DateShortcutChip(title: "Tomorrow", isSelected: isSelectedDate(offset: 1)) {
                    setDate(offset: 1)
                }
                DateShortcutChip(title: "Next Week", isSelected: isSelectedDate(offset: 7)) {
                    setDate(offset: 7)
                }
            }
        }
        .lifeTrackCard(padding: LifeTrackTheme.Spacing.medium, backgroundColor: LifeTrackTheme.ColorPalette.card)
    }

    private var themedTimePicker: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Reminder time")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text("Due at \(dueDate.timeString)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }

                Spacer(minLength: LifeTrackTheme.Spacing.medium)

                Text(dueDate.timeString)
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(LifeTrackTheme.ColorPalette.accentSoft, in: Capsule())
            }

            DatePicker("", selection: $dueDate, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.wheel)
                .tint(LifeTrackTheme.ColorPalette.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 170)
                .clipped()
                .environment(\.colorScheme, .light)
                .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                        .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.82), lineWidth: 0.8)
                }
                .shadow(color: LifeTrackTheme.ColorPalette.shadow.opacity(0.08), radius: 14, x: 0, y: 8)

            HStack(spacing: 8) {
                DateShortcutChip(title: "09:00", isSelected: isSelectedTime(hour: 9, minute: 0)) {
                    setTime(hour: 9, minute: 0)
                }
                DateShortcutChip(title: "14:00", isSelected: isSelectedTime(hour: 14, minute: 0)) {
                    setTime(hour: 14, minute: 0)
                }
                DateShortcutChip(title: "18:00", isSelected: isSelectedTime(hour: 18, minute: 0)) {
                    setTime(hour: 18, minute: 0)
                }
            }
        }
        .lifeTrackCard(padding: LifeTrackTheme.Spacing.medium, backgroundColor: LifeTrackTheme.ColorPalette.card)
    }

    private func setDate(offset: Int) {
        let calendar = Calendar.current
        guard let targetDay = calendar.date(byAdding: .day, value: offset, to: Date()) else {
            return
        }

        let time = calendar.dateComponents([.hour, .minute, .second], from: dueDate)
        dueDate = calendar.date(
            bySettingHour: time.hour ?? 9,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: targetDay
        ) ?? dueDate
    }

    private func setTime(hour: Int, minute: Int) {
        dueDate = Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: dueDate
        ) ?? dueDate
    }

    private func isSelectedDate(offset: Int) -> Bool {
        guard let targetDay = Calendar.current.date(byAdding: .day, value: offset, to: Date()) else {
            return false
        }

        return Calendar.current.isDate(dueDate, inSameDayAs: targetDay)
    }

    private func isSelectedTime(hour: Int, minute: Int) -> Bool {
        let components = Calendar.current.dateComponents([.hour, .minute], from: dueDate)
        return components.hour == hour && components.minute == minute
    }
}

private struct DateShortcutChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? .white : LifeTrackTheme.ColorPalette.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    isSelected ? AnyShapeStyle(LifeTrackTheme.ColorPalette.accentGradient) : AnyShapeStyle(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.84)),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(isSelected ? Color.white.opacity(0.22) : LifeTrackTheme.ColorPalette.hairline.opacity(0.82), lineWidth: 0.8)
                }
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96, pressedOpacity: 0.92))
    }
}
