import SwiftUI

// Global state object to handle loading and navigation states across the app
class AppState: ObservableObject {
    @Published var isNavigating: Bool = false
    @Published var isLoading: Bool = false
    
    // Convenience property to check if any loading state is active
    var isShowingLoadingView: Bool {
        return isNavigating || isLoading
    }
    
    // Function to start navigation loading state
    func startNavigating() {
        isNavigating = true
    }
    
    // Function to stop navigation loading state
    func stopNavigating() {
        isNavigating = false
    }
    
    // Function to start data loading state
    func startLoading() {
        isLoading = true
    }
    
    // Function to stop data loading state
    func stopLoading() {
        isLoading = false
    }
    
    func resetAllLoadingStates() {
        isNavigating = false
        isLoading = false
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
                    appState.stopLoading()
                }
            }
        }
    }
}
