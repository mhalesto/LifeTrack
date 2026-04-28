//
//  NewTaskCardViews.swift
//  LifeTrack
//
//  Section-card views extracted from NewTaskView. Each one is driven by the
//  shared NewTaskFormState model plus a small amount of view-local state
//  threaded in via bindings.
//

import SwiftUI

// MARK: - Status

struct TaskStatusCard: View {
    @Bindable var form: NewTaskFormState

    var body: some View {
        SectionCardView {
            Toggle(isOn: $form.isCompleted) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Completed")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text("Completed tasks will not schedule reminders.")
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
            .tint(LifeTrackTheme.ColorPalette.success)
        }
    }
}

// MARK: - Notes

struct TaskNotesCard: View {
    @Bindable var form: NewTaskFormState

    var body: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Notes",
                infoMessage: "Add context, links, or draft text."
            )

            ZStack(alignment: .topLeading) {
                TextEditor(text: $form.notes)
                    .font(.body)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .frame(minHeight: 126)
                    .scrollContentBackground(.hidden)
                    .padding(9)

                if form.notes.isEmpty {
                    Text("Write the details that will make this task easier later...")
                        .font(.body)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.placeholderText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .background(LifeTrackTheme.ColorPalette.backgroundTop, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.9), lineWidth: 0.8)
            }
        }
    }
}

// MARK: - Location

struct TaskLocationCard: View {
    @Bindable var form: NewTaskFormState
    @Binding var isShowingLocationPicker: Bool

    var body: some View {
        SectionCardView {
            SectionHeaderView(title: "Location Reminder", subtitle: "Trigger when you arrive or leave a place.")

            if let config = form.locationConfig {
                HStack(spacing: 12) {
                    Image(systemName: config.onArrival ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(config.name.isEmpty ? "Selected Place" : config.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            .lineLimit(1)
                        Text("\(config.onArrival ? "On arrival" : "On departure") · \(Int(config.radius))m radius")
                            .font(.caption)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    }

                    Spacer()

                    Button {
                        form.locationConfig = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    }
                }

                Button {
                    isShowingLocationPicker = true
                } label: {
                    Text("Change Location")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                }
            } else {
                Button {
                    isShowingLocationPicker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                        Text("Add Location Trigger")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Date

struct TaskDateCard: View {
    @Bindable var form: NewTaskFormState
    @Binding var activeDueDatePicker: DueDatePickerMode?

    private static let durationOptions = [15, 30, 45, 60, 90, 120]

    var body: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Due Date",
                infoMessage: "LifeTrack will schedule a reminder."
            )

            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
                HStack(spacing: LifeTrackTheme.Spacing.medium) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                        .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
                        .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(form.dueDate.weekdayDateString)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text(form.dueDate.timeString)
                            .font(.footnote)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                VStack(spacing: 0) {
                    DateSelectionRow(
                        title: "Date",
                        value: form.dueDate.formatted(Date.FormatStyle().month(.abbreviated).day().year()),
                        symbolName: "calendar",
                        action: { activeDueDatePicker = .date }
                    )

                    Divider()
                        .padding(.leading, 54)

                    DateSelectionRow(
                        title: "Time",
                        value: form.dueDate.timeString,
                        symbolName: "clock",
                        action: { activeDueDatePicker = .time }
                    )
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.75), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))

                durationSelector
            }
            .padding(11)
            .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.85), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.85), lineWidth: 0.8)
            }
        }
    }

    private var durationSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: LifeTrackTheme.Spacing.small) {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)

                Text("Duration")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Spacer(minLength: 0)

                Text(Self.durationTitle(for: form.durationMinutes))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 70), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(Self.durationOptions, id: \.self) { option in
                    Button {
                        form.durationMinutes = option
                    } label: {
                        Text(Self.durationTitle(for: option))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(form.durationMinutes == option ? .white : LifeTrackTheme.ColorPalette.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Self.durationChipBackground(isSelected: form.durationMinutes == option), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(form.durationMinutes == option ? Color.white.opacity(0.22) : LifeTrackTheme.ColorPalette.hairline.opacity(0.82), lineWidth: 0.8)
                            }
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.95, pressedOpacity: 0.92))
                }
            }
        }
        .padding(11)
        .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.66), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
    }

    static func durationTitle(for minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainingMinutes)m"
    }

    static func durationChipBackground(isSelected: Bool) -> some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(LifeTrackTheme.ColorPalette.accentGradient)
        }

        return AnyShapeStyle(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.86))
    }
}
