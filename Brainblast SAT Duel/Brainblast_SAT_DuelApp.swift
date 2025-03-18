import SwiftUI

// Global state object to handle loading and navigation states across the app
class AppState: ObservableObject {
    @Published var isNavigating: Bool = false
    @Published var isLoading: Bool = false
    @Published var isAnimationCompleting: Bool = false
    
    // Animation duration estimate (adjust based on your GIF length)
    private let animationDuration: TimeInterval = 1.5 // Estimate in seconds
    
    // Convenience property to check if any loading state is active
    var isShowingLoadingView: Bool {
        return isNavigating || isLoading || isAnimationCompleting
    }
    
    // Function to start navigation loading state
    func startNavigating() {
        isNavigating = true
    }
    
    // Function to stop navigation loading state with animation completion
    func stopNavigating() {
        // Set animation completion flag
        isAnimationCompleting = true
        
        // Allow animation to complete before removing loading view
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            self.isNavigating = false
            self.isAnimationCompleting = false
        }
    }
    
    // Function to start data loading state
    func startLoading() {
        isLoading = true
    }
    
    // Function to stop data loading state with animation completion
    func stopLoading() {
        // Set animation completion flag
        isAnimationCompleting = true
        
        // Allow animation to complete before removing loading view
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            self.isLoading = false
            self.isAnimationCompleting = false
        }
    }
    
    func resetAllLoadingStates() {
        // Allow any current animation to complete
        isAnimationCompleting = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            self.isNavigating = false
            self.isLoading = false
            self.isAnimationCompleting = false
        }
    }
}

@main
struct BrainblastSATDuelApp: App {
    // Create shared PostgresDBManager instance
    @StateObject private var dbManager = PostgresDBManager()
    @StateObject private var appState = AppState()
    @State private var isAppReady = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isAppReady {
                    // Show ContentView if user is logged in, otherwise show LoginView
                    if dbManager.isLoggedIn {
                        ContentView()
                            .environmentObject(dbManager)
                            .environmentObject(appState)
                    } else {
                        LoginView()
                            .environmentObject(dbManager)
                            .environmentObject(appState)
                    }
                }
                
                // Show LoadingView when app is initializing or when any loading state is active
                if !isAppReady || appState.isShowingLoadingView {
                    LoadingView()
                        .transition(.opacity)
                        .animation(.easeInOut, value: !isAppReady || appState.isShowingLoadingView)
                }
            }
            .onAppear {
                prepareApp()
            }
        }
    }
    
    private func prepareApp() {
        // Set initial loading state
        appState.startLoading()
        
        // Simulate initial app setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dbManager.checkInitialLoginStatus { success in
                DispatchQueue.main.async {
                    isAppReady = true
                    appState.stopLoading() // Will now wait for animation to complete
                }
            }
        }
    }
}
