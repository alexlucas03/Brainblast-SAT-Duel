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
            .foregroundColor(.black)
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

struct DuelViewModel: Identifiable {
    let id: String
    let duel: Duel
    var opponentName: String
    var userScore: Int = 0
    var opponentScore: Int = 0
    
    init(id: String, duel: Duel) {
        self.id = id
        self.duel = duel
        self.opponentName = "Duel Code: \(duel.roomCode)"
    }
    
    var scoreText: String {
        return "\(userScore)-\(opponentScore)"
    }
}

struct ContentView: View {
    @EnvironmentObject private var dbManager: PostgresDBManager
    @EnvironmentObject private var appState: AppState
    @State private var duelViewModels: [DuelViewModel] = []
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
                    Text("Welcome, \(username.prefix(1).uppercased() + username.dropFirst())!")
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
                                        appState.startNavigating()
                                        determineDuelNavigation(duel: viewModel.duel)
                                    }) {
                                        HStack {
                                            // Left side - Opponent name and copy button for room code
                                            VStack(alignment: .leading) {
                                                if viewModel.opponentName.hasPrefix("Duel Code:") {
                                                    HStack(spacing: 4) {
                                                        Text("Duel Code:")
                                                            .font(.headline)
                                                        
                                                        Text(viewModel.duel.roomCode)
                                                            .font(.system(.body, design: .monospaced))
                                                            .fontWeight(.bold)
                                                        
                                                        Button(action: {
                                                            UIPasteboard.general.string = viewModel.duel.roomCode
                                                            alertTitle = "Success"
                                                            alertMessage = "Room code copied to clipboard!"
                                                            showAlert = true
                                                        }) {
                                                            Image(systemName: "doc.on.doc")
                                                                .font(.caption)
                                                        }
                                                        .disabled(appState.isShowingLoadingView)
                                                    }
                                                } else {
                                                    Text("You vs " + viewModel.opponentName.prefix(1).uppercased() + viewModel.opponentName.dropFirst())
                                                        .font(.headline)
                                                }
                                            }

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
                                    .disabled(appState.isShowingLoadingView)
                                }
                            }
                            .listStyle(PlainListStyle())
                            .modifier(RainbowBorder())
                            .padding(.horizontal)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)

                    // The rest of your existing code...
                    // Vertically stacked buttons with rainbow style
                    VStack(spacing: 12) {
                        Button("Join Duel") {
                            showJoinDuelSheet = true
                        }
                        .modifier(RainbowButton(isEnabled: !appState.isShowingLoadingView))
                        .disabled(appState.isShowingLoadingView)

                        Button("New Duel") {
                            appState.startLoading()
                            startNewDuel()
                        }
                        .modifier(RainbowButton(isEnabled: !appState.isShowingLoadingView))
                        .disabled(appState.isShowingLoadingView)
                    }
                    .padding(.vertical)

                    Spacer()

                    Button("Logout") {
                        appState.startLoading()
                        performLogout()
                    }
                    .padding()
                    .foregroundColor(.red)
                    .disabled(appState.isShowingLoadingView)
                }
            }
            .navigationDestination(item: $navigationDestination) { destination in
                switch destination {
                case .duelDetail(let duel):
                    DuelDetailView(duel: duel)
                        .onAppear {
                            appState.stopNavigating()
                        }
                case .game(let duel, let userId):
                    GameView(duel: duel, userId: userId)
                        .onAppear {
                            appState.stopNavigating()
                        }
                }
            }
            .onAppear {
                if duelViewModels.isEmpty {
                    appState.startLoading()
                    loadDuels()
                }
                appState.stopNavigating()
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
                appState.startLoading()
                showJoinDuelSheet = false
                joinDuel(code: duelCode)
            }
            .modifier(RainbowButton(isEnabled: !duelCode.isEmpty && !appState.isShowingLoadingView))
            .disabled(duelCode.isEmpty || appState.isShowingLoadingView)

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
                        appState.stopLoading() // Stop loading on error
                    }
                    return
                }
                
                guard let fetchedDuels = fetchedDuels else {
                    DispatchQueue.main.async {
                        appState.stopLoading() // Stop loading when no duels
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
                    appState.stopLoading() // Stop loading on success
                }
            }
        } else {
            appState.stopLoading() // Stop loading if there is no user id
        }
    }

    private func joinDuel(code: String) {
        guard let userId = dbManager.currentUserId else {
            appState.stopLoading()
            return
        }

        dbManager.joinDuel(userId: userId, roomCode: code) { success, error in
            DispatchQueue.main.async {
                self.loadDuels()
            }
        }
    }

    private func startNewDuel() {
        guard let userId = dbManager.currentUserId else {
            appState.stopLoading()
            return
        }

        dbManager.createDuel(creatorId: userId) { success, roomCode, error in
            DispatchQueue.main.async {
                self.loadDuels()
                appState.stopLoading()
            }
        }
    }

    private func determineDuelNavigation(duel: Duel) {
        guard let userId = dbManager.currentUserId else {
            navigationDestination = .duelDetail(duel)
            return
        }
        
        // First, check if the game is over by loading participants and checking scores
        dbManager.getDuelParticipants(duelId: duel.id) { participants, error in
            if let participants = participants, participants.count == 2 {
                // Check if either player has reached 3 points (game is over)
                let isGameOver = participants.contains { $0.score >= 3 }
                
                if isGameOver {
                    // If game is over, go directly to detail view which will show results
                    DispatchQueue.main.async {
                        navigationDestination = .duelDetail(duel)
                    }
                } else {
                    // Game is not over, now check if it's user's turn
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
            } else {
                // If we can't determine participants/scores, fallback to detail view
                DispatchQueue.main.async {
                    navigationDestination = .duelDetail(duel)
                }
            }
        }
    }
    
    private func performLogout() {
        // Small delay to show the loading indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dbManager.logout()
            // Reset loading state after logout
            DispatchQueue.main.async {
                appState.stopLoading()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(PostgresDBManager())
            .environmentObject(AppState())
    }
}
