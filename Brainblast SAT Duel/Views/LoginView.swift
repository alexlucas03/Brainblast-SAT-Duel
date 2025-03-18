import SwiftUI

struct LoginView: View {
    @State private var username: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var isViewLoaded: Bool = false
    @State private var isGIFLoaded: Bool = false

    @EnvironmentObject private var dbManager: PostgresDBManager

    var body: some View {
        Group {
            if !isViewLoaded {
                LoadingView()
                    .onAppear {
                        loadInitialData()
                    }
            } else {
                NavigationView {
                    ZStack {
                        Color.white.ignoresSafeArea()

                        if isLoading {
                            LoadingView()
                        } else {
                            VStack(spacing: 20) {
                                GIFView(gifName: "wave")
                                    .frame(width: 300, height: 360)
                                    .padding(.bottom, 20)
                                    .onAppear {
                                        // Simulate GIF loading time
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            isGIFLoaded = true
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
                                    .opacity(username.isEmpty ? 0.6 : 1.0)
                                    .padding(.horizontal)
                                    .disabled(username.isEmpty)
                                } else {
                                    LoadingView()
                                }
                            }
                            .padding()
                        }
                    }
                    .alert(isPresented: $showAlert) {
                        Alert(title: Text("Message"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                    }
                }
                .preferredColorScheme(.light)
            }
        }
    }

    private func loadInitialData() {
        // Simulate initial setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isViewLoaded = true
        }
    }

    private func loginUser() {
        guard !username.isEmpty else {
            alertMessage = "Please enter your name."
            showAlert = true
            return
        }

        isLoading = true // Start loading

        dbManager.loginOrCreateUser(username: username) { success in
            DispatchQueue.main.async {
                isLoading = false // Stop loading
                if !success {
                    alertMessage = "Connection error. Please try again."
                    showAlert = true
                }
                //If successful, the next view will load, and the loading screen will disappear.
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(PostgresDBManager())
    }
}
