import SwiftUI

struct MoneyCurrencySetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCurrencyCode: String
    let onLock: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose Money Currency")
                            .font(.lifeTrackHeadline)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        Text("This currency will be used across entries, task financial details, bills, forecasts, and reports.")
                            .font(.subheadline)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    SectionCardView {
                        HStack(spacing: LifeTrackTheme.Spacing.medium) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                                .frame(width: 44, height: 44)
                                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Global currency")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                                Text("Pick carefully. It locks after setup so reports stay consistent.")
                                    .font(.caption)
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: LifeTrackTheme.Spacing.small)
                            MoneyCurrencyPicker(currencyCode: $selectedCurrencyCode)
                        }
                    }

                    Button {
                        selectedCurrencyCode = MoneyCurrency.normalized(selectedCurrencyCode)
                        onLock()
                        dismiss()
                        LifeTrackHaptics.lightImpact()
                    } label: {
                        Label("Use \(MoneyCurrency.normalized(selectedCurrencyCode))", systemImage: "checkmark.circle.fill")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LifeTrackTheme.ColorPalette.accentGradient, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                .padding(.top, LifeTrackTheme.Spacing.xLarge)
                .padding(.bottom, LifeTrackTheme.Spacing.xLarge)
            }
        }
        .tint(LifeTrackTheme.ColorPalette.accent)
    }
}


