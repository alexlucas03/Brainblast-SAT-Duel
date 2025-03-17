import SwiftUI

struct LoginView: View {
    @State private var username: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var isLoggingIn: Bool = false
    
    @EnvironmentObject private var dbManager: PostgresDBManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Brainblast SAT Duel")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 30)
                
                Image(systemName: "brain.head.profile")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                    .padding(.bottom, 20)
                
                TextField("Enter Your Name", text: $username)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button(action: loginUser) {
                    if isLoggingIn {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(isLoggingIn || username.isEmpty)
                
                Spacer()
                
                // Database connection indicator
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                    Text("Connected to Neon PostgreSQL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom)
            }
            .padding()
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Message"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private func loginUser() {
        guard !username.isEmpty else {
            alertMessage = "Please enter your name."
            showAlert = true
            return
        }
        
        isLoggingIn = true
        
        dbManager.loginOrCreateUser(username: username) { success in
            DispatchQueue.main.async {
                isLoggingIn = false
                
                if !success {
                    alertMessage = "Connection error. Please try again."
                    showAlert = true
                }
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
