import SwiftUI

struct LoadingView: View {
    // Array of available GIF names
    private let gifOptions = ["loading", "loading2", "loading3", "loading4"]
    
    // State to store the currently selected GIF
    @State private var selectedGif: String
    
    // State to control the animation
    @State private var animationStarted = false
    
    // Initialize with a random GIF
    init() {
        _selectedGif = State(initialValue: LoadingView.getRandomGif(from: ["loading", "loading2", "loading3", "loading4"]))
    }
    
    var body: some View {
        ZStack {
            // Full screen white background
            Color.white.ignoresSafeArea()
            
            VStack {
                // Your randomly selected loading GIF with ease-in animation
                GIFView(gifName: selectedGif)
                    .frame(width: 300, height: 360)
                    .opacity(animationStarted ? 1 : 0)
                    .animation(.easeIn(duration: 0.5), value: animationStarted)
                    .onAppear {
                        // Start with opacity 0
                        animationStarted = false
                        
                        // Select a random GIF
                        selectedGif = Self.getRandomGif(from: gifOptions)
                        
                        // Start animation after a tiny delay to ensure proper rendering
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                animationStarted = true
                            }
                        }
                    }
                
                // Loading text
                Text("Loading...")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
                    .opacity(animationStarted ? 1 : 0)
                    .animation(.easeIn(duration: 0.5).delay(0.2), value: animationStarted)
            }
        }
    }
    
    // Static method to get a random GIF from the array
    private static func getRandomGif(from options: [String]) -> String {
        guard !options.isEmpty else { return "loading" } // Default fallback
        return options.randomElement() ?? "loading"
    }
}
