import SwiftUI
import OneSignalFramework

struct LoginView: View {
    @State private var username: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var isGIFLoaded: Bool = false

    @EnvironmentObject private var dbManager: PostgresDBManager
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()

                // Since we're using global loading state, we don't need a local LoadingView
                VStack(spacing: 20) {
                    GIFView(gifName: "wave")
                        .frame(width: 300, height: 360)
                        .padding(.bottom, 20)
                        .onAppear {
                            // Show loading while GIF is loading
                            appState.startLoading()
                            
                            // Simulate GIF loading time
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isGIFLoaded = true
                                appState.stopLoading()
                            }
                        }

                    if isGIFLoaded {
                        Text("Hello!")
                            .font(.title2)
                            .fontWeight(.medium)
                            .padding(.bottom, 0)

                        Text("What's your name?")
                            .font(.title2)
                            .fontWeight(.medium)
                            .padding(.bottom, 10)

                        TextField("Enter Your Name", text: $username)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .disabled(appState.isShowingLoadingView)

                        Button(action: loginUser) {
                            Text("Get Started")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                        }
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.98, green: 0.7, blue: 0.6),
                                            Color(red: 0.95, green: 0.95, blue: 0.6),
                                            Color(red: 0.7, green: 0.98, blue: 0.7),
                                            Color(red: 0.6, green: 0.8, blue: 0.98)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .opacity((username.isEmpty || appState.isShowingLoadingView) ? 0.6 : 1.0)
                        .padding(.horizontal)
                        .disabled(username.isEmpty || appState.isShowingLoadingView)
                    }
                }
                .padding()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Message"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            setupNotificationListeners()
        }
    }

    private func loginUser() {
        guard !username.isEmpty else {
            alertMessage = "Please enter your name."
            showAlert = true
            return
        }

        // Use global loading state for network operation
        appState.startLoading()

        dbManager.loginOrCreateUser(username: username) { success in
            DispatchQueue.main.async {
                if success {
                    // When login is successful, save the OneSignal player ID to the database
                    if let userId = self.dbManager.currentUserId {
                        if let playerId = OneSignalManager.shared.playerId {
                            // Save OneSignal ID to database
                            self.dbManager.saveOneSignalPlayerId(userId: userId, playerId: playerId) { success, error in
                                if success {
                                    print("Successfully saved OneSignal player ID: \(playerId)")
                                } else {
                                    print("Error saving OneSignal player ID: \(error?.localizedDescription ?? "Unknown error")")
                                }
                            }
                            
                            // Also set external user ID in OneSignal
                            OneSignalManager.shared.setExternalUserId(userId: userId)
                        } else {
                            print("OneSignal player ID not available yet")
                        }
                    }
                    
                    // Switch from loading to navigating
                    appState.stopLoading()
                    appState.startNavigating()
                } else {
                    // Stop loading and show error
                    appState.stopLoading()
                    alertMessage = "Connection error. Please try again."
                    showAlert = true
                }
            }
        }
    }
    
    private func setupNotificationListeners() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OneSignalPlayerIDUpdated"),
            object: nil,
            queue: .main
        ) { notification in
            if let playerId = notification.userInfo?["playerId"] as? String,
               let userId = self.dbManager.currentUserId {
                // Update the OneSignal ID in the database
                self.dbManager.saveOneSignalPlayerId(userId: userId, playerId: playerId) { success, error in
                    if success {
                        print("Updated OneSignal player ID in database after delayed update: \(playerId)")
                    } else {
                        print("Error updating OneSignal player ID: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
        }
    }
}
