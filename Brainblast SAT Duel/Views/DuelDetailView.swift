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
    @Environment(\.presentationMode) var presentationMode
    let duel: Duel
    
    @State private var participants: [User] = []
    @State private var currentUser: User?
    @State private var opponent: User?
    @State private var isLoading: Bool = true
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = "Error"
    @State private var alertMessage: String = ""
    @State private var navigateToHome: Bool = false
    @State private var answers: [Answer] = []
    @State private var rounds: [Round] = []
    @State private var isLoadingAnswers: Bool = true
    @State private var isUsersTurn: Bool = false
    @State private var showLoadingScreen: Bool = true
    @State private var isViewLoaded: Bool = false
    
    // For winner determination
    private enum RoundWinner {
        case user
        case opponent
        case tie
        case incomplete
    }
    
    var body: some View {
        Group {
            if !isViewLoaded {
                LoadingView()
                    .onAppear {
                        loadInitialData()
                    }
            } else {
                ZStack {
                    if showLoadingScreen {
                        LoadingView()
                    } else {
                        ScrollView {
                            // Main content (previous code remains the same)
                            VStack(spacing: 16) {
                                // Top header with home button, duel code, and leave button
                                HStack {
                                    // Home button
                                    Button(action: {
                                        navigateToHome = true
                                    }) {
                                        Image(systemName: "house.fill")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                            .padding(10)
                                            .background(Color.blue.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                    
                                    Spacer()
                                    
                                    // Duel code in the middle
                                    HStack(spacing: 4) {
                                        Text(duel.roomCode)
                                            .font(.system(.body, design: .monospaced))
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(8)
                                        
                                        Button(action: {
                                            UIPasteboard.general.string = duel.roomCode
                                            alertTitle = "Success"
                                            alertMessage = "Room code copied to clipboard!"
                                            showAlert = true
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.caption)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Leave duel button
                                    Button(action: {
                                        leaveDuel()
                                    }) {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .font(.title3)
                                            .foregroundColor(.red)
                                            .padding(10)
                                            .background(Color.red.opacity(0.1))
                                            .clipShape(Circle())
                                    }
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
                                } else if isLoading {
                                    ProgressView("Loading participants...")
                                        .padding()
                                } else {
                                    Text("Waiting for opponent...")
                                        .foregroundColor(.gray)
                                        .padding()
                                }
                                
                                // Round history section
                                VStack(spacing: 12) {
                                    if isLoadingAnswers {
                                        ProgressView("Loading round history...")
                                            .padding()
                                    } else if rounds.isEmpty {
                                        Text("No rounds played yet")
                                            .foregroundColor(.gray)
                                            .padding()
                                    } else {
                                        ForEach(rounds, id: \.questionNumber) { round in
                                            // Entire round card with winner's half border
                                            ZStack {
                                                // Background
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.gray.opacity(0.1))
                                                
                                                // Content
                                                VStack(spacing: 8) {
                                                    // Question header
                                                    Text("Question \(round.questionNumber)")
                                                        .font(.subheadline)
                                                        .fontWeight(.medium)
                                                        .frame(maxWidth: .infinity, alignment: .center)
                                                        .padding(.top, 12)
                                                        .padding(.bottom, 4)
                                                    
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
                                                                        .foregroundColor(.gray)
                                                                }
                                                            } else {
                                                                Image(systemName: "questionmark.circle.fill")
                                                                    .foregroundColor(.gray)
                                                                    .font(.title2)
                                                                Text("Waiting")
                                                                    .font(.caption)
                                                                    .foregroundColor(.gray)
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
                                                                        .foregroundColor(.gray)
                                                                }
                                                            } else {
                                                                Image(systemName: "questionmark.circle.fill")
                                                                    .foregroundColor(.gray)
                                                                    .font(.title2)
                                                                Text("Waiting")
                                                                    .font(.caption)
                                                                    .foregroundColor(.gray)
                                                            }
                                                        }
                                                        .frame(maxWidth: .infinity)
                                                        .padding(.vertical, 10)
                                                    }
                                                    .padding(.horizontal)
                                                }
                                                .zIndex(1) // Content stays above background but below the border
                                                
                                                // Fading border for winner
                                                fadingBorderForWinner(round: round)
                                                    .zIndex(2) // Makes sure border is above everything
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    
                    // Navigation link to Content View
                    NavigationLink(destination: ContentView().navigationBarBackButtonHidden(true), isActive: $navigateToHome) {
                        EmptyView()
                    }
                }
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
        .refreshable {
            loadParticipants()
            loadAnswers()
            checkTurn()
        }
    }
    
    private func loadInitialData() {
        // Simulate initial setup and load data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            loadParticipants()
            loadAnswers()
            checkTurn()
            
            // Set view as loaded after a short delay to ensure data is processed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showLoadingScreen = false
                isViewLoaded = true
            }
        }
    }
    
    // Fading border for winner
    @ViewBuilder
    private func fadingBorderForWinner(round: Round) -> some View {
        let winner = determineWinner(round: round)
        
        GeometryReader { geometry in
            if winner == .user {
                // User side winner - left side gradient border
                ZStack {
                    // Complete round rectangle for masking
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.clear, lineWidth: 10)
                    
                    // Main rainbow border
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
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
                            lineWidth: 10
                        )
                        // Apply horizontal gradient mask for left side fade
                        .mask(
                            HStack(spacing: 0) {
                                // Left side: full opacity
                                RoundedLeftRectangle(radius: 12)
                                    .frame(width: geometry.size.width * 0.4)
                                
                                // Center: fading gradient
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.black, Color.clear]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: geometry.size.width * 0.2)
                                
                                // Right side: fully transparent
                                RoundedRightRectangle(radius: 12)
                                    .fill(Color.clear)
                                    .frame(width: geometry.size.width * 0.4)
                            }
                        )
                }
            } else if winner == .opponent {
                // Opponent side winner - right side gradient border
                ZStack {
                    // Complete round rectangle for masking
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.clear, lineWidth: 10)
                    
                    // Main rainbow border
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
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
                            lineWidth: 10
                        )
                        // Apply horizontal gradient mask for right side fade
                        .mask(
                            HStack(spacing: 0) {
                                // Left side: fully transparent
                                RoundedLeftRectangle(radius: 12)
                                    .fill(Color.clear)
                                    .frame(width: geometry.size.width * 0.4)
                                
                                // Center: fading gradient
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.clear, Color.black]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: geometry.size.width * 0.2)
                                
                                // Right side: full opacity
                                RoundedRightRectangle(radius: 12)
                                    .frame(width: geometry.size.width * 0.4)
                            }
                        )
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
                    
                    // Determine current user and opponent
                    if let currentUsername = dbManager.currentUsername {
                        currentUser = fetchedParticipants.first(where: { $0.username == currentUsername })
                        opponent = fetchedParticipants.first(where: { $0.username != currentUsername })
                    }
                }
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
        isLoadingAnswers = true
        
        guard let userId = dbManager.currentUserId else {
            isLoadingAnswers = false
            return
        }
        
        dbManager.getDuelAnswers(duelId: duel.id) { fetchedAnswers, error in
            DispatchQueue.main.async {
                isLoadingAnswers = false
                
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
        // Group answers by question number
        let answersDict = Dictionary(grouping: answers, by: { $0.questionNumber })
        
        // Sort by question number and create rounds
        rounds = answersDict.keys.sorted().map { questionNumber in
            let questionAnswers = answersDict[questionNumber] ?? []
            
            let userAnswer = questionAnswers.first { $0.userId == userId }
            let opponentAnswer = questionAnswers.first { $0.userId != userId }
            
            return Round(
                questionNumber: questionNumber,
                userAnswer: userAnswer,
                opponentAnswer: opponentAnswer
            )
        }
    }
    
    private func leaveDuel() {
        guard let userId = dbManager.currentUserId else { return }
        
        dbManager.leaveDuel(userId: userId, duelId: duel.id) { success, error in
            DispatchQueue.main.async {
                if success {
                    navigateToHome = true
                } else {
                    alertTitle = "Error"
                    alertMessage = "Failed to leave duel: \(error?.localizedDescription ?? "Unknown error")"
                    showAlert = true
                }
            }
        }
    }
}
