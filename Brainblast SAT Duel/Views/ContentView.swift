import SwiftUI
import Foundation
import PostgresClientKit

struct RainbowText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.78, green: 0.5, blue: 0.4),  // Darker peach
                        Color(red: 0.75, green: 0.75, blue: 0.4), // Darker yellow
                        Color(red: 0.4, green: 0.78, blue: 0.4),  // Darker green
                        Color(red: 0.3, green: 0.6, blue: 0.78)   // Darker blue
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

extension View {
    func rainbowText() -> some View {
        self.modifier(RainbowText())
    }
}

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
            .foregroundColor(.white)  // Change from .white to .black
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
    var isUserTurn: Bool = false
    
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
    
    // Timer for polling duel updates
    @State private var pollingTimer: Timer? = nil

    enum NavigationDestination: Hashable {
        case duelDetail(Duel)
        case game(Duel, String) // Added userId
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                VStack {
                    if let username = dbManager.currentUsername {
                        Text("Welcome, \(username.prefix(1).uppercased() + username.dropFirst())!")
                            .font(.title)
                            .padding()
                            .foregroundColor(.black)
                        
                        Text("Here are your active duels:")
                            .font(.title2)
                            .padding()
                            .foregroundColor(.black)
                        
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
                                                                .foregroundColor(.black)
                                                            
                                                            Text(viewModel.duel.roomCode)
                                                                .font(.system(.body, design: .monospaced))
                                                                .fontWeight(.bold)
                                                                .foregroundColor(.black)
                                                            
                                                            Button(action: {
                                                                UIPasteboard.general.string = viewModel.duel.roomCode
                                                                alertTitle = "Success"
                                                                alertMessage = "Room code copied to clipboard!"
                                                                showAlert = true
                                                            }) {
                                                                Image(systemName: "doc.on.doc")
                                                                    .font(.caption)
                                                                    .foregroundColor(.blue)
                                                            }
                                                            .disabled(appState.isShowingLoadingView)
                                                        }
                                                    } else {
                                                        if viewModel.isUserTurn {
                                                            Text("vs " + viewModel.opponentName.prefix(1).uppercased() + viewModel.opponentName.dropFirst())
                                                                .font(.headline)
                                                                .rainbowText()
                                                        } else {
                                                            Text("vs " + viewModel.opponentName.prefix(1).uppercased() + viewModel.opponentName.dropFirst())
                                                                .font(.headline)
                                                                .foregroundColor(.black)
                                                        }
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                // Right side - Score
                                                Text(viewModel.scoreText)
                                                    .font(.headline)
                                                    .foregroundColor(.black)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 4)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(Color.gray.opacity(0.2))
                                                    )
                                            }
                                            .padding(.vertical, 12) // Increased from 4 to 12 to make items taller
                                            .background(Color.white)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .listRowBackground(Color.white)
                                        .listRowInsets(EdgeInsets())
                                        .background(Color.white)
                                        .disabled(appState.isShowingLoadingView)
                                    }
                                }
                                .listStyle(PlainListStyle())
                                .background(Color.white)
                                .modifier(RainbowBorder())
                                .padding(.horizontal)
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                        .foregroundColor(.white)
                        
                        // Vertically stacked buttons with rainbow style
                        VStack(spacing: 12) {
                            Button("Join Duel") {
                                showJoinDuelSheet = true
                            }
                            .foregroundColor(.black) // Changed to black
                            .modifier(RainbowButton(isEnabled: !appState.isShowingLoadingView))
                            .disabled(appState.isShowingLoadingView)
                            
                            Button("New Duel") {
                                appState.startLoading()
                                startNewDuel()
                            }
                            .foregroundColor(.black)
                            .modifier(RainbowButton(isEnabled: !appState.isShowingLoadingView))
                            .disabled(appState.isShowingLoadingView)
                        }
                        .padding(.vertical)
                    }
                }
                .navigationDestination(item: $navigationDestination) { destination in
                    switch destination {
                    case .duelDetail(let duel):
                        DuelDetailView(duel: duel)
                            .onAppear {
                                appState.stopNavigating()
                                stopPolling() // Stop polling when navigating away
                            }
                    case .game(let duel, let userId):
                        GameView(duel: duel, userId: userId)
                            .onAppear {
                                appState.stopNavigating()
                                stopPolling() // Stop polling when navigating away
                            }
                    }
                }
                .onAppear {
                    if duelViewModels.isEmpty {
                        appState.startLoading()
                        loadDuels()
                    }
                    appState.stopNavigating()
                    
                    // Start polling for updates
                    startPolling()
                }
                .onDisappear {
                    // Stop polling when view disappears
                    stopPolling()
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
    }

    private var joinDuelView: some View {
        VStack(spacing: 20) {
            Text("Join Duel")
                .foregroundColor(.black)
                .font(.title)
                .bold()

            TextField("Enter Duel Code", text: $duelCode)
                .foregroundColor(.black)
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
                .autocapitalization(.allCharacters)
                .colorScheme(.light)

            Button("Join") {
                appState.startLoading()
                showJoinDuelSheet = false
                joinDuel(code: duelCode)
            }
            .foregroundColor(.black)
            .modifier(RainbowButton(isEnabled: !duelCode.isEmpty && !appState.isShowingLoadingView))
            .disabled(duelCode.isEmpty || appState.isShowingLoadingView)

            Button("Cancel") {
                showJoinDuelSheet = false
                duelCode = ""
            }
            .foregroundColor(.red)
            .padding()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .edgesIgnoringSafeArea(.all)
    }
    
    // MARK: - Polling Methods
    
    private func startPolling() {
        // Cancel any existing timer
        stopPolling()
        
        // Create a new timer that polls every 5 seconds
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            if !appState.isShowingLoadingView && !appState.isNavigating {
                // Only refresh if we're not already loading or navigating
                loadDuelsQuietly()
            }
        }
    }
    
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // A version of loadDuels that doesn't show loading indicators
    private func loadDuelsQuietly() {
        if let userId = dbManager.currentUserId {
            dbManager.getUserDuels(userId: userId) { fetchedDuels, error in
                if let error = error {
                    print("Error refreshing duels: \(error.localizedDescription)")
                    return
                }
                
                guard let fetchedDuels = fetchedDuels else {
                    return
                }
                
                // Create view models for each duel
                var viewModels: [DuelViewModel] = fetchedDuels.map { DuelViewModel(id: $0.id, duel: $0) }
                
                // Use a dispatch group to wait for all the participant data to load
                let group = DispatchGroup()
                
                // Load participants for each duel
                for (index, duel) in fetchedDuels.enumerated() {
                    group.enter()
                    dbManager.getDuelParticipantsIncludingLeft(duelId: duel.id) { participants, error in
                        defer {
                            group.leave()
                        }
                        
                        guard let participants = participants, error == nil else { return }
                        
                        // Find the current user and opponent
                        if let currentUsername = dbManager.currentUsername {
                            let currentUserParticipant = participants.first(where: { $0.userId == currentUserId })
                            let opponentParticipant = participants.first(where: { $0.userId != currentUserId })
                            
                            DispatchQueue.main.async {
                                if let opponent = opponentParticipant {
                                    viewModels[index].opponentName = opponent.username
                                    viewModels[index].opponentScore = opponent.score
                                    
                                    // If opponent has left, add an indicator
                                    if opponent.hasLeft {
                                        viewModels[index].opponentName += " (left)"
                                    }
                                }
                                
                                if let currentUser = currentUserParticipant {
                                    viewModels[index].userScore = currentUser.score
                                }
                            }
                        }
                    }
                    
                    // Check if it's the user's turn
                    group.enter()
                    if let userId = dbManager.currentUserId {
                        dbManager.isUsersTurn(userId: userId, duelId: duel.id) { isTurn, error in
                            defer {
                                group.leave()
                            }
                            
                            if let isTurn = isTurn, isTurn {
                                DispatchQueue.main.async {
                                    viewModels[index].isUserTurn = true
                                }
                            }
                        }
                    } else {
                        group.leave()
                    }
                }
                
                // When all participants are loaded, update the UI
                group.notify(queue: .main) {
                    self.duelViewModels = viewModels
                }
            }
        }
    }

    // MARK: - Standard Data Loading Methods

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
                    dbManager.getDuelParticipantsIncludingLeft(duelId: duel.id) { participants, error in
                        defer {
                            group.leave()
                        }
                        
                        guard let participants = participants, error == nil else { return }
                        
                        // Find the current user and opponent
                        if let currentUsername = dbManager.currentUsername {
                            let currentUserParticipant = participants.first(where: { $0.userId == currentUserId })
                            let opponentParticipant = participants.first(where: { $0.userId != currentUserId })
                            
                            DispatchQueue.main.async {
                                if let opponent = opponentParticipant {
                                    viewModels[index].opponentName = opponent.username
                                    viewModels[index].opponentScore = opponent.score
                                    
                                    // If opponent has left, add an indicator
                                    if opponent.hasLeft {
                                        viewModels[index].opponentName += " (left)"
                                    }
                                }
                                
                                if let currentUser = currentUserParticipant {
                                    viewModels[index].userScore = currentUser.score
                                }
                            }
                        }
                    }
                    
                    // Check if it's the user's turn
                    group.enter()
                    if let userId = dbManager.currentUserId {
                        dbManager.isUsersTurn(userId: userId, duelId: duel.id) { isTurn, error in
                            defer {
                                group.leave()
                            }
                            
                            if let isTurn = isTurn, isTurn {
                                DispatchQueue.main.async {
                                    viewModels[index].isUserTurn = true
                                }
                            }
                        }
                    } else {
                        group.leave()
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
}
