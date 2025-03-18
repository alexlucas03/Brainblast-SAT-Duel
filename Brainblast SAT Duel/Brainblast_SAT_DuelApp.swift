import SwiftUI

@main
struct BrainblastSATDuelApp: App {
    // Create shared PostgresDBManager instance
    @StateObject private var dbManager = PostgresDBManager()
    @State private var isAppReady = false
    
    var body: some Scene {
        WindowGroup {
            if isAppReady {
                // Show ContentView if user is logged in, otherwise show LoginView
                if dbManager.isLoggedIn {
                    ContentView()
                        .environmentObject(dbManager)
                } else {
                    LoginView()
                        .environmentObject(dbManager)
                }
            } else {
                LoadingView()
                    .onAppear {
                        prepareApp()
                    }
            }
        }
    }
    
    private func prepareApp() {
        // Simulate initial app setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dbManager.checkInitialLoginStatus { success in
                DispatchQueue.main.async {
                    isAppReady = true
                }
            }
        }
    }
}
