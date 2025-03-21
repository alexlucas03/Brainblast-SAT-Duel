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

struct RainbowText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(
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

struct DuelItemView: View {
    @EnvironmentObject private var appState: AppState
    let viewModel: DuelViewModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Left side - Opponent name or room code
                duelInfoView
                
                Spacer()
                
                // Right side - Score (background stays consistent)
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
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                // Use a conditional to pick the right view instead of a ternary on just the fill
                Group {
                    if viewModel.isPlayersTurn {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.98, green: 0.7, blue: 0.6).opacity(0.3),
                                        Color(red: 0.95, green: 0.95, blue: 0.6).opacity(0.3),
                                        Color(red: 0.7, green: 0.98, blue: 0.7).opacity(0.3),
                                        Color(red: 0.6, green: 0.8, blue: 0.98).opacity(0.3)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white)
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(Color.white)
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .disabled(appState.isShowingLoadingView)
    }
    
    private var duelInfoView: some View {
        VStack(alignment: .leading) {
            if viewModel.opponentName.hasPrefix("Duel Code:") {
                roomCodeView
            } else {
                // Status text (You vs Opponent or result message)
                Text(viewModel.statusText)
                    .font(.headline)
                    .foregroundColor(.black)
            }
        }
    }
    
    private var roomCodeView: some View {
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
                // Handle feedback in parent view
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .disabled(appState.isShowingLoadingView)
        }
    }
}

struct DuelViewModel: Identifiable {
    let id: String
    let duel: Duel
    var opponentName: String
    var userScore: Int = 0
    var opponentScore: Int = 0
    var isPlayersTurn: Bool = false
    var isComplete: Bool = false
    
    init(id: String, duel: Duel) {
        self.id = id
        self.duel = duel
        self.opponentName = "Duel Code: \(duel.roomCode)"
        self.isComplete = duel.completedAt != nil
    }
    
    var scoreText: String {
        return "\(userScore)-\(opponentScore)"
    }
    
    var statusText: String {
        if isComplete {
            if userScore > opponentScore {
                return "You beat \(opponentName)"
            } else if opponentScore > userScore {
                return "\(opponentName) beat You"
            } else {
                return "Tied with \(opponentName)"
            }
        } else {
            if opponentName.hasPrefix("Duel Code:") {
                return opponentName
            } else {
                return "You vs \(opponentName.prefix(1).uppercased() + opponentName.dropFirst())"
            }
        }
    }
}

struct DuelListView: View {
    @EnvironmentObject private var appState: AppState
    let duelViewModels: [DuelViewModel]
    let onDuelTap: (Duel) -> Void
    let onCopyCode: (String) -> Void
    
    var body: some View {
        if duelViewModels.isEmpty {
            Text("You're not in any duels yet.")
                .foregroundColor(.gray)
                .padding()
        } else {
            List {
                ForEach(duelViewModels) { viewModel in
                    DuelItemView(viewModel: viewModel) {
                        onDuelTap(viewModel.duel)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }
            }
            .listStyle(PlainListStyle())
            .background(Color.white)
            .modifier(RainbowBorder())
            .padding(.horizontal)
        }
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
    @State private var timer: Timer?

    enum NavigationDestination: Hashable {
        case duelDetail(Duel)
        case game(Duel, String) // Added userId
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                mainContentView
            }
        }
    }
    
    private var mainContentView: some View {
        VStack {
            if let username = dbManager.currentUsername {
                // Header
                Text("Welcome, \(username.prefix(1).uppercased() + username.dropFirst())!")
                    .font(.title)
                    .padding()
                    .foregroundColor(.black)
                
                Text("Here are your active duels:")
                    .font(.title2)
                    .padding()
                    .foregroundColor(.black)
                
                // Duel list
                DuelListView(
                    duelViewModels: duelViewModels,
                    onDuelTap: { duel in
                        appState.startNavigating()
                        determineDuelNavigation(duel: duel)
                    },
                    onCopyCode: { code in
                        UIPasteboard.general.string = code
                        alertTitle = "Success"
                        alertMessage = "Room code copied to clipboard!"
                        showAlert = true
                    }
                )
                .frame(maxHeight: .infinity, alignment: .top)
                
                // Action buttons
                actionButtonsView
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
            startPolling()
        }
        .onDisappear {
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
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            Button("Join Duel") {
                showJoinDuelSheet = true
            }
            .foregroundColor(.black)
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

    private var joinDuelView: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Join Duel")
                    .foregroundColor(.black)
                    .font(.title)
                    .bold()

                TextField("Enter Duel Code", text: $duelCode)
                    .foregroundColor(.black)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .autocapitalization(.allCharacters)
                    .background(Color.white)
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
            .background(Color.white)
        }
    }
    
    // Start polling for duel updates
    private func startPolling() {
        stopPolling() // Stop any existing timer
        
        // Create a new timer that polls every 5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            updateDuelTurnStatus()
        }
    }
    
    // Stop polling
    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    // Update turn status for all duels
    private func updateDuelTurnStatus() {
        guard let userId = dbManager.currentUserId else { return }
        
        // Don't update if we're in the loading state
        if appState.isShowingLoadingView { return }
        
        // Update each duel's turn status
        for index in duelViewModels.indices {
            let duel = duelViewModels[index].duel
            
            // Skip completed duels
            if duel.completedAt != nil {
                continue
            }
            
            // Check if it's the user's turn
            dbManager.isUsersTurn(userId: userId, duelId: duel.id) { isTurn, error in
                guard let isTurn = isTurn, error == nil else { return }
                
                DispatchQueue.main.async {
                    if index < duelViewModels.count {
                        duelViewModels[index].isPlayersTurn = isTurn
                    }
                }
            }
            
            // Update participants to get the latest scores
            dbManager.getDuelParticipants(duelId: duel.id) { participants, error in
                guard let participants = participants, error == nil else { return }
                
                if let currentUsername = dbManager.currentUsername {
                    let currentUserParticipant = participants.first(where: { $0.username == currentUsername })
                    let opponentParticipant = participants.first(where: { $0.username != currentUsername })
                    
                    DispatchQueue.main.async {
                        if index < duelViewModels.count {
                            if let opponent = opponentParticipant {
                                duelViewModels[index].opponentName = opponent.username
                                duelViewModels[index].opponentScore = opponent.score
                            }
                            
                            if let currentUser = currentUserParticipant {
                                duelViewModels[index].userScore = currentUser.score
                            }
                            
                            // Check if game is complete (someone has 3 points)
                            let isComplete = participants.contains { $0.score >= 3 }
                            duelViewModels[index].isComplete = isComplete
                        }
                    }
                }
            }
        }
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
                                
                                // Check if game is complete (someone has 3 points)
                                let isComplete = participants.contains { $0.score >= 3 }
                                viewModels[index].isComplete = isComplete || duel.completedAt != nil
                            }
                        }
                    }
                    
                    // Check if it's the user's turn
                    group.enter()
                    dbManager.isUsersTurn(userId: userId, duelId: duel.id) { isTurn, error in
                        defer {
                            group.leave()
                        }
                        
                        if let isTurn = isTurn {
                            DispatchQueue.main.async {
                                viewModels[index].isPlayersTurn = isTurn
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(PostgresDBManager())
            .environmentObject(AppState())
    }
}
