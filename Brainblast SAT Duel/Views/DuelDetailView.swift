import SwiftUI

struct Answer {
    let userId: String
    let questionNumber: Int
    let timeTaken: Int
    let isCorrect: Bool
}

struct Round {
    let questionNumber: Int
    let userAnswer: Answer?
    let opponentAnswer: Answer?
    
    var userCorrect: Bool { userAnswer?.isCorrect ?? false }
    var opponentCorrect: Bool { opponentAnswer?.isCorrect ?? false }
    var userTime: Int? { userAnswer?.timeTaken }
    var opponentTime: Int? { opponentAnswer?.timeTaken }
}

struct RoundedLeftRectangle: Shape {
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start from top-left corner
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        
        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        
        // Right edge (not rounded)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        
        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        
        // Bottom-left rounded corner
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        
        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        
        // Top-left rounded corner
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        
        path.closeSubpath()
        return path
    }
}

struct RoundedRightRectangle: Shape {
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start from top-left corner (not rounded)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        
        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        
        // Top-right rounded corner
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )
        
        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        
        // Bottom-right rounded corner
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        
        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        
        // Left edge (not rounded)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        path.closeSubpath()
        return path
    }
}

struct DuelDetailView: View {
    @EnvironmentObject private var dbManager: PostgresDBManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.presentationMode) var presentationMode
    let duel: Duel
    
    @State private var participants: [User] = []
    @State private var currentUser: User?
    @State private var opponent: User?
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = "Error"
    @State private var alertMessage: String = ""
    @State private var navigateToHome: Bool = false
    @State private var answers: [Answer] = []
    @State private var rounds: [Round] = []
    @State private var isUsersTurn: Bool = false
    @State private var gameOver: Bool = false
    
    // For winner determination
    private enum RoundWinner {
        case user
        case opponent
        case tie
        case incomplete
    }
    
    var body: some View {
        ZStack {
            duelActiveView
            
            // Navigation link to DuelResultView when game is over
            NavigationLink(
                destination: Group {
                    if let currentUser = currentUser, let opponent = opponent {
                        DuelResultView(
                            navigateToHome: $navigateToHome,
                            isWinner: currentUser.score >= 3,
                            opponentName: opponent.username,
                            userScore: currentUser.score,
                            opponentScore: opponent.score
                        )
                    } else {
                        EmptyView()
                    }
                },
                isActive: $gameOver
            ) {
                EmptyView()
            }
        }
        .background(Color.white)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        // Navigation link to Content View with improved loading handling
        NavigationLink(destination: ContentView()
            .navigationBarBackButtonHidden(true)
            .onAppear {
                // Reset navigation state when destination appears
                appState.stopNavigating()
            },
            isActive: $navigateToHome
        ) {
            EmptyView()
        }
        .hidden()
        .onAppear {
            // Load initial data when view appears
            appState.startLoading()
            loadData()
        }
    }
    
    // The original duel view when game is still active
    private var duelActiveView: some View {
        ScrollView {
            // Main content
            VStack(spacing: 16) {
                // Top header with home button, duel code, and leave button
                HStack {
                    // Home button
                    Button(action: {
                        appState.startNavigating()
                        // Slight delay before actual navigation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navigateToHome = true
                        }
                    }) {
                        Image(systemName: "house.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .padding(10)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .disabled(appState.isShowingLoadingView)
                    
                    Spacer()
                    
                    // Leave duel button
                    Button(action: {
                        appState.startLoading()
                        leaveDuel()
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.title3)
                            .foregroundColor(.red)
                            .padding(10)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .disabled(appState.isShowingLoadingView)
                }
                .padding(.horizontal)
                
                // Top section with player names and scores
                if let currentUser = currentUser, let opponent = opponent {
                    HStack {
                        // Current user - using actual username
                        VStack {
                            Text(currentUser.username)
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            Text("\(currentUser.score)")
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        
                        ZStack {
                            GIFView(gifName: "bullet")
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(-90))
                                .scaleEffect(x: 1, y: -1)
                        }
                        .padding(5)
                        
                        // Opponent
                        VStack {
                            Text(opponent.username)
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            Text("\(opponent.score)")
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.98, green: 0.7, blue: 0.6),
                                        Color(red: 0.95, green: 0.95, blue: 0.6),
                                        Color(red: 0.7, green: 0.98, blue: 0.7),
                                        Color(red: 0.6, green: 0.8, blue: 0.98)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .padding(.horizontal)
                } else if appState.isLoading {
                    ProgressView("Loading participants...")
                        .padding()
                } else {
                    Text("Waiting for opponent...")
                        .foregroundColor(.gray)
                        .padding()
                }
                
                // Round history section
                VStack(spacing: 12) {
                    if appState.isLoading {
                        ProgressView("Loading round history...")
                            .padding()
                    } else if rounds.isEmpty {
                        Text("No rounds played yet")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(rounds, id: \.questionNumber) { round in
                            // Question header moved outside the grey area
                            Text("Question \(round.questionNumber)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.horizontal)
                                .padding(.top, 4)
                            
                            // Entire round card with winner's gradient fill
                            ZStack {
                                // Background with winner's rainbow fill
                                winnerBackgroundForRound(round: round)
                                
                                // Content overlay
                                VStack(spacing: 8) {
                                    // Result indicators
                                    HStack {
                                        // User result
                                        VStack {
                                            if round.userAnswer != nil {
                                                Image(systemName: round.userCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                    .foregroundColor(round.userCorrect ? .green : .red)
                                                    .font(.title2)
                                                
                                                if let time = round.userTime {
                                                    Text("\(time)s")
                                                        .font(.caption)
                                                        .foregroundColor(.black)
                                                }
                                            } else {
                                                Image(systemName: "questionmark.circle.fill")
                                                    .foregroundColor(.gray)
                                                    .font(.title2)
                                                Text("Waiting")
                                                    .font(.caption)
                                                    .foregroundColor(.black)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        
                                        // VS divider
                                        Divider()
                                            .frame(height: 40)
                                        
                                        // Opponent result
                                        VStack {
                                            if round.opponentAnswer != nil {
                                                Image(systemName: round.opponentCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                    .foregroundColor(round.opponentCorrect ? .green : .red)
                                                    .font(.title2)
                                                
                                                if let time = round.opponentTime {
                                                    Text("\(time)s")
                                                        .font(.caption)
                                                        .foregroundColor(.black)
                                                }
                                            } else {
                                                Image(systemName: "questionmark.circle.fill")
                                                    .foregroundColor(.gray)
                                                    .font(.title2)
                                                Text("Waiting")
                                                    .font(.caption)
                                                    .foregroundColor(.black)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                    }
                                    .padding(.horizontal)
                                }
                                .cornerRadius(12)
                                .padding(3) // Small padding to allow the background to show around the edges
                            }
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .refreshable {
            loadData()
        }
        // Disable refreshing during loading
        .disabled(appState.isShowingLoadingView)
    }
    
    private func loadData() {
        loadParticipants()
        loadAnswers()
        checkTurn()
    }
    
    @ViewBuilder
    private func winnerBackgroundForRound(round: Round) -> some View {
        let winner = determineWinner(round: round)
        
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
            
            if winner == .user {
                // User side winner - left side rainbow fill
                HStack(spacing: 0) {
                    // Left half with rainbow gradient
                    RoundedLeftRectangle(radius: 12)
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
                        .frame(width: geometry.size.width * 0.5)
                    
                    // Right half without gradient
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: geometry.size.width * 0.5)
                }
            } else if winner == .opponent {
                // Opponent side winner - right side rainbow fill
                HStack(spacing: 0) {
                    // Left half without gradient
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: geometry.size.width * 0.5)
                    
                    // Right half with rainbow gradient
                    RoundedRightRectangle(radius: 12)
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
                        .frame(width: geometry.size.width * 0.5)
                }
            }
        }
    }
    
    // Function to determine winner of a round
    private func determineWinner(round: Round) -> RoundWinner {
        // If either player hasn't answered yet, the round is incomplete
        if round.userAnswer == nil || round.opponentAnswer == nil {
            return .incomplete
        }
        
        // If one player is correct and the other is incorrect, the correct player wins
        if round.userCorrect && !round.opponentCorrect {
            return .user
        } else if !round.userCorrect && round.opponentCorrect {
            return .opponent
        }
        
        // If both are correct or both are incorrect, faster time wins
        if let userTime = round.userTime, let opponentTime = round.opponentTime {
            if userTime < opponentTime {
                return .user
            } else if opponentTime < userTime {
                return .opponent
            } else {
                return .tie // Same time
            }
        }
        
        return .incomplete // Should not reach here if both have answered
    }
    
    private func loadParticipants() {
        dbManager.getDuelParticipants(duelId: duel.id) { (fetchedParticipants: [User]?, error: Error?) in
            DispatchQueue.main.async {
                if let error = error {
                    alertTitle = "Error"
                    alertMessage = "Failed to load participants: \(error.localizedDescription)"
                    showAlert = true
                } else if let fetchedParticipants = fetchedParticipants {
                    participants = fetchedParticipants
                    
                    // Determine current user and opponent
                    if let currentUsername = dbManager.currentUsername {
                        currentUser = fetchedParticipants.first(where: { $0.username == currentUsername })
                        opponent = fetchedParticipants.first(where: { $0.username != currentUsername })
                        
                        // Check if game is over (either player has 3 or more points)
                        if let user = currentUser, let opp = opponent {
                            let isGameOver = user.score >= 3 || opp.score >= 3
                            
                            // If the game is newly over, trigger navigation
                            if isGameOver && !gameOver {
                                gameOver = true
                            }
                        }
                    }
                }
                
                // Continue loading other data, don't stop loading yet
            }
        }
    }
    
    private func checkTurn() {
        guard let userId = dbManager.currentUserId else {
            return
        }
        
        dbManager.isUsersTurn(userId: userId, duelId: duel.id) { isTurn, error in
            if let isTurn = isTurn {
                DispatchQueue.main.async {
                    isUsersTurn = isTurn
                }
            }
        }
    }
    
    private func loadAnswers() {
        guard let userId = dbManager.currentUserId else {
            appState.stopLoading()
            return
        }
        
        dbManager.getDuelAnswers(duelId: duel.id) { fetchedAnswers, error in
            DispatchQueue.main.async {
                // Stop loading now that we have all data
                appState.stopLoading()
                
                if let error = error {
                    alertTitle = "Error"
                    alertMessage = "Failed to load answers: \(error.localizedDescription)"
                    showAlert = true
                } else if let fetchedAnswers = fetchedAnswers {
                    answers = fetchedAnswers
                    processAnswersIntoRounds(answers: fetchedAnswers, userId: userId)
                }
            }
        }
    }
    
    private func processAnswersIntoRounds(answers: [Answer], userId: String) {
        // Step 1: First separate user answers and opponent answers
        let userAnswers = answers.filter { $0.userId == userId }
        let opponentAnswers = answers.filter { $0.userId != userId }
        
        // Sort answers
        let sortedOpponentAnswers = opponentAnswers.sorted(by: { $0.questionNumber < $1.questionNumber })
        let sortedUserAnswers = userAnswers.sorted(by: { $0.questionNumber < $1.questionNumber })
        
        // Step 3: Create rounds
        var allRounds: [Round] = []
        let maxQuestionNumber = max(sortedUserAnswers.count, sortedOpponentAnswers.count)
        
        if maxQuestionNumber > 0 {
            for questionNum in 1...maxQuestionNumber {
                // Get user answer from our corrected mapping
                let userAnswer = sortedUserAnswers.first { $0.questionNumber == questionNum }
                
                // Get opponent answer the normal way - they're correctly ordered
                let opponentAnswer = sortedOpponentAnswers.first { $0.questionNumber == questionNum }
                
                allRounds.append(Round(
                    questionNumber: questionNum,
                    userAnswer: userAnswer,
                    opponentAnswer: opponentAnswer
                ))
            }
        }
        
        self.rounds = allRounds
    }

    private func leaveDuel() {
        guard let userId = dbManager.currentUserId else {
            appState.stopLoading()
            return
        }
        
        dbManager.leaveDuel(userId: userId, duelId: duel.id) { success, error in
            DispatchQueue.main.async {
                if success {
                    // Switch to navigation loading before navigating
                    appState.stopLoading()
                    appState.startNavigating()
                    
                    // Slight delay before actual navigation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigateToHome = true
                    }
                } else {
                    appState.stopLoading()
                    alertTitle = "Error"
                    alertMessage = "Failed to leave duel: \(error?.localizedDescription ?? "Unknown error")"
                    showAlert = true
                }
            }
        }
    }
}
