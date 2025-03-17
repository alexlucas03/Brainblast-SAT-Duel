import SwiftUI
import Foundation
import PostgresClientKit

struct ContentView: View {
    @EnvironmentObject private var dbManager: PostgresDBManager
    @State private var duels: [Duel] = []
    @State private var isDuelsLoading: Bool = true
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var alertTitle: String = "Error"
    @State private var showJoinDuelSheet: Bool = false
    @State private var duelCode: String = ""
    @State private var showSuccessAlert: Bool = false
    @State private var successMessage: String = ""
    @State private var navigationDestination: NavigationDestination?
    
    enum NavigationDestination: Hashable {
        case duelDetail(Duel)
        case game(Duel, String) // Added userId
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if let username = dbManager.currentUsername {
                    Text("Welcome, \(username)!")
                        .font(.title)
                        .padding()

                    VStack(alignment: .leading) {
                        Text("Your Duels")
                            .font(.headline)
                            .padding(.horizontal)

                        if isDuelsLoading {
                            ProgressView("Loading duels...")
                                .padding()
                        } else if duels.isEmpty {
                            Text("You're not in any duels yet.")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            List {
                                ForEach(duels) { duel in
                                    Button(action: {
                                        determineDuelNavigation(duel: duel)
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text("Room: \(duel.roomCode)")
                                                    .font(.headline)
                                                Text("Created: \(duel.createdAt, format: .dateTime)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }

                                            Spacer()

                                            if duel.active {
                                                Text("Active")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                            } else {
                                                Text("Completed")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            .listStyle(PlainListStyle())
                        }
                    }
                    .frame(maxHeight: .infinity)

                    HStack(spacing: 20) {
                        Button("Join Duel") {
                            showJoinDuelSheet = true
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)

                        Button("Start Duel") {
                            startNewDuel()
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()

                    Spacer()

                    Button("Logout") {
                        dbManager.logout()
                    }
                    .padding()
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Brainblast SAT Duel")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $navigationDestination) { destination in
                switch destination {
                case .duelDetail(let duel):
                    DuelDetailView(duel: duel)
                case .game(let duel, let userId):
                    GameView(duel: duel, userId: userId)
                }
            }
            .onAppear {
                loadDuels()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: $showJoinDuelSheet) {
                joinDuelView
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) {
                    loadDuels()
                }
            } message: {
                Text(successMessage)
            }
        }
    }

    private var joinDuelView: some View {
        VStack(spacing: 20) {
            Text("Join Duel")
                .font(.title)
                .bold()

            TextField("Enter Duel Code", text: $duelCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .autocapitalization(.allCharacters)

            Button("Join") {
                joinDuel(code: duelCode)
                showJoinDuelSheet = false
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(duelCode.isEmpty)

            Button("Cancel") {
                showJoinDuelSheet = false
                duelCode = ""
            }
            .padding()
            .foregroundColor(.red)
        }
        .padding()
    }

    private func loadDuels() {
        isDuelsLoading = true

        if let userId = dbManager.currentUserId {
            dbManager.getUserDuels(userId: userId) { fetchedDuels, error in
                DispatchQueue.main.async {
                    isDuelsLoading = false

                    if let error = error {
                        alertTitle = "Error"
                        alertMessage = "Failed to load duels: \(error.localizedDescription)"
                        showAlert = true
                    } else if let fetchedDuels = fetchedDuels {
                        duels = fetchedDuels
                    }
                }
            }
        } else {
            isDuelsLoading = false
        }
    }

    private func joinDuel(code: String) {
        guard let userId = dbManager.currentUserId else { return }

        dbManager.joinDuel(userId: userId, roomCode: code) { success, error in
            DispatchQueue.main.async {
                if success {
                    successMessage = "You've joined the duel with code: \(code)"
                    showSuccessAlert = true
                    duelCode = ""
                    loadDuels() // Reload duels after joining
                } else {
                    alertTitle = "Error"
                    alertMessage = "Failed to join duel: \(error?.localizedDescription ?? "Unknown error")"
                    showAlert = true
                }
            }
        }
    }

    private func startNewDuel() {
        guard let userId = dbManager.currentUserId else { return }

        dbManager.createDuel(creatorId: userId) { success, roomCode, error in
            DispatchQueue.main.async {
                if success, let roomCode = roomCode {
                    successMessage = "New duel created! Share this code with your opponent: \(roomCode)"
                    showSuccessAlert = true
                    loadDuels() // Reload duels after creation
                } else {
                    alertTitle = "Error"
                    alertMessage = "Failed to create duel: \(error?.localizedDescription ?? "Unknown error")"
                    showAlert = true
                }
            }
        }
    }

    private func determineDuelNavigation(duel: Duel) {
        guard let userId = dbManager.currentUserId else {
            navigationDestination = .duelDetail(duel)
            return
        }
        
        dbManager.isUsersTurn(userId: userId, duelId: duel.id) { isTurn, error in
            DispatchQueue.main.async {
                if let isTurn = isTurn {
                    navigationDestination = isTurn
                        ? .game(duel, userId)
                        : .duelDetail(duel)
                } else {
                    // Fallback to DuelDetailView if unable to determine turn
                    navigationDestination = .duelDetail(duel)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(PostgresDBManager())
    }
}
