import SwiftUI

public struct ChatGPTBrandLogoView: View {
    public init() {}

    public var body: some View {
        Image("ChatGPTMark")
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .accessibilityHidden(true)
    }
}
