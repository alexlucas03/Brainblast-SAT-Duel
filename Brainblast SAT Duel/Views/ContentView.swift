import SwiftUI
import Foundation
import PostgresClientKit

struct RainbowBorder: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.98, green: 0.7, blue: 0.6),  // Soft orange/peach
                                Color(red: 0.95, green: 0.95, blue: 0.6), // Soft yellow
                                Color(red: 0.7, green: 0.98, blue: 0.7),  // Soft green
                                Color(red: 0.6, green: 0.8, blue: 0.98)   // Soft blue
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 3
                    )
            )
    }
}

struct RainbowButton: ViewModifier {
    var isEnabled: Bool
    
    func body(content: Content) -> some View {
        content
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.98, green: 0.7, blue: 0.6),  // Soft orange/peach
                                Color(red: 0.95, green: 0.95, blue: 0.6), // Soft yellow
                                Color(red: 0.7, green: 0.98, blue: 0.7),  // Soft green
                                Color(red: 0.6, green: 0.8, blue: 0.98)   // Soft blue
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .opacity(isEnabled ? 1.0 : 0.6)
            .padding(.horizontal)
    }
}

// View model to track duel opponent and scores
struct DuelViewModel: Identifiable {
    let id: String
    let duel: Duel
    var opponentName: String = "Waiting..."
    var userScore: Int = 0
    var opponentScore: Int = 0
    
    var scoreText: String {
        return "\(userScore)-\(opponentScore)"
    }
}

struct ContentView: View {
    @EnvironmentObject private var dbManager: PostgresDBManager
    @State private var duelViewModels: [DuelViewModel] = []
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var alertTitle: String = "Error"
    @State private var showJoinDuelSheet: Bool = false
    @State private var duelCode: String = ""
    @State private var showSuccessAlert: Bool = false
    @State private var successMessage: String = ""
    @State private var navigationDestination: NavigationDestination?
    @State private var isContentLoaded: Bool = false // Track if content is loaded

    enum NavigationDestination: Hashable {
        case duelDetail(Duel)
        case game(Duel, String) // Added userId
    }

    var body: some View {
        Group {
            if isContentLoaded {
                NavigationStack {
                    VStack {
                        if let username = dbManager.currentUsername {
                            Text("Welcome, \(username)!")
                                .font(.title)
                                .padding()

                            Text("Here are your active duels:")
                                .font(.title2)
                                .padding()

                            VStack(alignment: .leading) {
                                if duelViewModels.isEmpty {
                                    Text("You're not in any duels yet.")
                                        .foregroundColor(.gray)
                                        .padding()
                                } else {
                                    List {
                                        ForEach(duelViewModels) { viewModel in
                                            Button(action: {
                                                determineDuelNavigation(duel: viewModel.duel)
                                            }) {
                                                HStack {
                                                    // Left side - Opponent name
                                                    Text(viewModel.opponentName)
                                                        .font(.headline)

                                                    Spacer()

                                                    // Right side - Score
                                                    Text(viewModel.scoreText)
                                                        .font(.headline)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 4)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .fill(Color.gray.opacity(0.2))
                                                        )
                                                }
                                                .padding(.vertical, 4)
                                            }
                                        }
                                    }
                                    .listStyle(PlainListStyle())
                                    .modifier(RainbowBorder())
                                    .padding(.horizontal)
                                }
                            }
                            .frame(maxHeight: .infinity, alignment: .top)

                            // Vertically stacked buttons with rainbow style
                            VStack(spacing: 12) {
                                Button("Join Duel") {
                                    showJoinDuelSheet = true
                                }
                                .modifier(RainbowButton(isEnabled: true))

                                Button("New Duel") {
                                    startNewDuel()
                                }
                                .modifier(RainbowButton(isEnabled: true))
                            }
                            .padding(.vertical)

                            Spacer()

                            Button("Logout") {
                                dbManager.logout()
                            }
                            .padding()
                            .foregroundColor(.red)
                        }
                    }
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
                .background(Color.white)
            } else {
                LoadingView()
                    .onAppear {
                        loadInitialData()
                    }
            }
        }
    }

    func loadInitialData() {
        loadDuels()
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
            .modifier(RainbowButton(isEnabled: !duelCode.isEmpty))
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

        if let userId = dbManager.currentUserId {
            dbManager.getUserDuels(userId: userId) { fetchedDuels, error in
                if let error = error {
                    DispatchQueue.main.async {
                        alertTitle = "Error"
                        alertMessage = "Failed to load duels: \(error.localizedDescription)"
                        showAlert = true
                        isContentLoaded = true // Set isContentLoaded on error
                    }
                    return
                }
                
                guard let fetchedDuels = fetchedDuels else {
                    DispatchQueue.main.async {
                        isContentLoaded = true // Set isContentLoaded when no duels
                    }
                    return
                }
                
                // Create view models for each duel
                var viewModels: [DuelViewModel] = fetchedDuels.map { DuelViewModel(id: $0.id, duel: $0) }
                
                // Use a dispatch group to wait for all the participant data to load
                let group = DispatchGroup()
                
                // Load participants for each duel
                for (index, duel) in fetchedDuels.enumerated() {
                    group.enter()
                    print("group enter")
                    dbManager.getDuelParticipants(duelId: duel.id) { participants, error in
                        defer {
                            group.leave()
                            print("group leave")
                        }
                        
                        guard let participants = participants, error == nil else { return }
                        
                        // Find the current user and opponent
                        if let currentUsername = dbManager.currentUsername {
                            let currentUserParticipant = participants.first(where: { $0.username == currentUsername })
                            let opponentParticipant = participants.first(where: { $0.username != currentUsername })
                            
                            DispatchQueue.main.async {
                                if let opponent = opponentParticipant {
                                    viewModels[index].opponentName = opponent.username
                                    viewModels[index].opponentScore = opponent.score
                                }
                                
                                if let currentUser = currentUserParticipant {
                                    viewModels[index].userScore = currentUser.score
                                }
                            }
                        }
                    }
                }
                
                // When all participants are loaded, update the UI
                group.notify(queue: .main) {
                    duelViewModels = viewModels
                    isContentLoaded = true // Set isContentLoaded on success
                }
            }
        } else {
            isContentLoaded = true // set isContentLoaded if there is no user id.
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
