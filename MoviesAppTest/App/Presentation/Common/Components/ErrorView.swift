import SwiftUI

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(message)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier(AccessibilityID.Common.errorView)
            Button(String(localized: "common.retry", comment: "Retry button"), action: onRetry)
                .accessibilityIdentifier(AccessibilityID.Common.retryButton)
        }
        .padding()
    }
}
