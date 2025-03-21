import SwiftUI

// Global state object to handle loading and navigation states across the app
class AppState: ObservableObject {
    @Published var isNavigating: Bool = false
    @Published var isLoading: Bool = false
    @Published var isAnimationCompleting: Bool = false
    var dbManager: PostgresDBManager?
    
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
    
    func setupOneSignalObserver() {
        // Add observer for when the OneSignal Player ID is updated
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OneSignalPlayerIDUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let dbManager = self.dbManager,  // Properly unwrap the optional dbManager
                  let userId = dbManager.currentUserId,  // Now use the unwrapped dbManager
                  let playerId = notification.userInfo?["playerId"] as? String else {
                return
            }
            
            print("Received OneSignal player ID update: \(playerId)")
            
            // Save the OneSignal player ID to the database
            dbManager.saveOneSignalPlayerId(userId: userId, playerId: playerId) { success, error in
                if success {
                    print("Successfully saved OneSignal player ID to database")
                } else {
                    print("Failed to save OneSignal player ID: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
            
            // Also set up the external user ID in OneSignal
            OneSignalManager.shared.setExternalUserId(userId: userId)
        }
    }
}

@main
struct BrainblastSATDuelApp: App {
    // Create shared PostgresDBManager instance
    @StateObject private var dbManager = PostgresDBManager()
    @StateObject private var appState = AppState()
    @State private var isAppReady = false
    
    init() {
        // Initialize OneSignal
        OneSignalManager.shared.initialize()
    }
    
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
