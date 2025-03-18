import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            // Full screen white background
            Color.white.ignoresSafeArea()
            
            VStack {
                // Your loading GIF
                GIFView(gifName: "loading")
                    .frame(width: 300, height: 360)
            }
        }
    }
}
