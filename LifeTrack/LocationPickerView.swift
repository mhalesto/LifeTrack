//
//  LocationPickerView.swift
//  LifeTrack
//

import CoreLocation
import MapKit
import SwiftUI

struct LocationReminderConfig: Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    var radius: Double = 150
    var onArrival: Bool = true
}

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (LocationReminderConfig) -> Void

    @State private var searchText = ""
    @State private var results: [MKMapItem] = []
    @State private var selectedItem: MKMapItem?
    @State private var onArrival = true
    @State private var radius: Double = 150
    @State private var isSearching = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar

                    if let selected = selectedItem {
                        selectedPreview(item: selected)
                    } else {
                        resultsList
                    }
                }
            }
            .navigationTitle("Location Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
                if selectedItem != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") { confirmSelection() }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .onAppear {
            LocationReminderManager.shared.requestPermissionIfNeeded()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            TextField("Search for a place...", text: $searchText)
                .submitLabel(.search)
                .onSubmit { performSearch() }
                .onChange(of: searchText) { _, _ in
                    if searchText.isEmpty { results = [] }
                }
        }
        .padding(LifeTrackTheme.Spacing.medium)
        .background(LifeTrackTheme.ColorPalette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(LifeTrackTheme.Spacing.xLarge)
    }

    // MARK: - Results

    private var resultsList: some View {
        ScrollView {
            VStack(spacing: LifeTrackTheme.Spacing.small) {
                ForEach(results, id: \.self) { item in
                    Button {
                        selectItem(item)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? "Unknown place")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                                if let address = item.placemark.title {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .padding(LifeTrackTheme.Spacing.medium)
                        .background(LifeTrackTheme.ColorPalette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
        }
    }

    // MARK: - Selected Preview

    private func selectedPreview(item: MKMapItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                SectionCardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? "Selected Place")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                                if let address = item.placemark.title {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            Button {
                                selectedItem = nil
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            }
                        }
                    }
                }

                SectionCardView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
                        SectionHeaderView(title: "Trigger", subtitle: "When to remind you.")

                        HStack(spacing: 10) {
                            triggerButton(label: "On Arrival", icon: "arrow.down.circle.fill", selected: onArrival) {
                                onArrival = true
                            }
                            triggerButton(label: "On Departure", icon: "arrow.up.circle.fill", selected: !onArrival) {
                                onArrival = false
                            }
                        }
                    }
                }

                SectionCardView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
                        SectionHeaderView(title: "Radius", subtitle: "\(Int(radius)) meters")
                        Slider(value: $radius, in: 50...500, step: 25)
                            .tint(LifeTrackTheme.ColorPalette.accent)
                    }
                }
            }
            .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
            .padding(.top, LifeTrackTheme.Spacing.medium)
        }
    }

    private func triggerButton(label: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(selected ? .white : LifeTrackTheme.ColorPalette.primaryText)
            .background(selected
                        ? AnyShapeStyle(LifeTrackTheme.ColorPalette.accentGradient)
                        : AnyShapeStyle(LifeTrackTheme.ColorPalette.card),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: selected)
    }

    // MARK: - Actions

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        MKLocalSearch(request: request).start { response, _ in
            isSearching = false
            results = response?.mapItems ?? []
        }
    }

    private func selectItem(_ item: MKMapItem) {
        selectedItem = item
        if let coord = item.placemark.location?.coordinate {
            region.center = coord
        }
    }

    private func confirmSelection() {
        guard
            let item = selectedItem,
            let coord = item.placemark.location?.coordinate
        else { return }

        let config = LocationReminderConfig(
            name: item.name ?? searchText,
            latitude: coord.latitude,
            longitude: coord.longitude,
            radius: radius,
            onArrival: onArrival
        )
        onSelect(config)
        dismiss()
    }
}
