import SwiftUI

struct ErrorBannerView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(Typography.body)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(radius: 8)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}
