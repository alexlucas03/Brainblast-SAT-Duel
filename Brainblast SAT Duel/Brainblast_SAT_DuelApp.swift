import SwiftUI

@main
struct BrainblastSATDuelApp: App {
    // Create shared PostgresDBManager instance
    @StateObject private var dbManager = PostgresDBManager()
    
    var body: some Scene {
        WindowGroup {
            // Show ContentView if user is logged in, otherwise show LoginView
            if dbManager.isLoggedIn {
                ContentView()
                    .environmentObject(dbManager)
            } else {
                LoginView()
                    .environmentObject(dbManager)
            }
        }
    }
}
