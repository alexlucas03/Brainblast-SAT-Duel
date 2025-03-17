import SwiftUI

struct DuelDetailView: View {
    @EnvironmentObject private var dbManager: PostgresDBManager
    let duel: Duel
    
    @State private var participants: [User] = []
    @State private var isLoading: Bool = true
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = "Error"
    @State private var alertMessage: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Duel info header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Room Code: \(duel.roomCode)")
                            .font(.headline)
                        
                        Spacer()
                        
                        if duel.active {
                            Text("Active")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(8)
                        } else {
                            Text("Completed")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.gray)
                                .cornerRadius(8)
                        }
                    }
                    
                    Text("Created: \(duel.createdAt, format: .dateTime)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let completedAt = duel.completedAt {
                        Text("Completed: \(completedAt, format: .dateTime)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                }
                
                // Participants section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Participants")
                        .font(.headline)
                    
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Loading participants...")
                            Spacer()
                        }
                        .padding()
                    } else if participants.isEmpty {
                        Text("No participants yet")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(participants, id: \.username) { participant in
                            HStack {
                                Text(participant.username)
                                    .font(.body)
                                
                                Spacer()
                                
                                // Assuming you've added a score property to User model.
                                // If not, you'll have to fetch score from duel_participants table.
                                // Example: Text("Score: \(participant.score)")
                                // In this case, I am adding a score property to the User class
                                // and will fetch it when getting the participants.
                                // But if you don't want to add score to User class, you need to
                                // make another call to fetch duel_participants and get the score.
                                Text("Score: \(participant.score)")
                                    .font(.body)
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Divider()
                }
                
                // Share section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Invite Others")
                        .font(.headline)
                    
                    HStack {
                        Text("Share this code with your friends:")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Button(action: {
                            UIPasteboard.general.string = duel.roomCode
                            alertTitle = "Success"
                            alertMessage = "Room code copied to clipboard!"
                            showAlert = true
                        }) {
                            HStack {
                                Text(duel.roomCode)
                                    .font(.system(.body, design: .monospaced))
                                    .bold()
                                
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Game controls section - only show if duel is active
                if duel.active {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Game Controls")
                            .font(.headline)
                        
                        HStack {
                            Button(action: {
                                startDuel()
                            }) {
                                Text("Start Quiz")
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            
                            Button(action: {
                                leaveDuel()
                            }) {
                                Text("Leave Duel")
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Duel Details")
        .onAppear {
            loadParticipants()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .refreshable {
            loadParticipants()
        }
    }
    
    private func loadParticipants() {
        isLoading = true
        
        dbManager.getDuelParticipants(duelId: duel.id) { (fetchedParticipants: [User]?, error: Error?) in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    alertTitle = "Error"
                    alertMessage = "Failed to load participants: \(error.localizedDescription)"
                    showAlert = true
                } else if let fetchedParticipants = fetchedParticipants {
                    participants = fetchedParticipants
                }
            }
        }
    }
    
    private func startDuel() {
        alertTitle = "Start Quiz"
        alertMessage = "This would navigate to the quiz interface (not yet implemented)"
        showAlert = true
    }
    
    private func leaveDuel() {
        guard let userId = dbManager.currentUserId else { return }
        
        dbManager.leaveDuel(userId: userId, duelId: duel.id) { success, error in
            DispatchQueue.main.async {
                if success {
                    alertTitle = "Success"
                    alertMessage = "You have left the duel"
                    showAlert = true
                } else {
                    alertTitle = "Error"
                    alertMessage = "Failed to leave duel: \(error?.localizedDescription ?? "Unknown error")"
                    showAlert = true
                }
            }
        }
    }
}

extension User {
    var score: Int {
        Int.random(in: 0...100) // Replace with fetching the actual score.
    }
}
