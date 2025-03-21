import Foundation
import PostgresClientKit
import SwiftUI

class PostgresDBManager: ObservableObject {
    // Published properties for UI state management
    @Published var isLoggedIn: Bool = false
    @Published var currentUserId: String? = nil
    @Published var currentUsername: String? = nil
    
    private let connectionString = "postgresql://satduel_owner:endpoint=ep-dawn-haze-a6x5gyb3-pooler;npg_lyGx9MkB4UXC@ep-dawn-haze-a6x5gyb3-pooler.us-west-2.aws.neon.tech/satduel?sslmode=require"

    private var connectionConfig: ConnectionConfiguration {
        var host = "localhost"
        var port = 5432
        var database = "satduel"
        var user = ""
        var pwd = ""

        if let url = URL(string: connectionString) {
            host = url.host ?? host
            port = url.port ?? port
            database = url.path.replacingOccurrences(of: "/", with: "")
            user = url.user ?? user
            pwd = url.password ?? pwd
        }

        var config = PostgresClientKit.ConnectionConfiguration()
        config.host = host  // Leave this as the full host value
        config.port = port
        config.database = database
        config.user = user
        config.credential = .cleartextPassword(password: pwd)
        config.ssl = true
        
        return config
    }

    private func getConnection() throws -> Connection {
        return try Connection(configuration: connectionConfig)
    }
    
    func checkInitialLoginStatus(completion: @escaping (Bool) -> Void) {
        // Verify the saved login state
        guard isLoggedIn,
              let userId = currentUserId,
              let username = currentUsername else {
            // If no saved login, immediately return false
            completion(false)
            return
        }
        
        // Optionally, add a database check to validate the user's existence
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }
                
                // Verify the user exists in the database
                let query = "SELECT id FROM users WHERE id = $1 AND username = $2;"
                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }
                
                let cursor = try statement.execute(parameterValues: [userId, username])
                defer { cursor.close() }
                
                if try cursor.next() != nil {
                    // User exists, login is valid
                    DispatchQueue.main.async {
                        completion(true)
                    }
                } else {
                    // User not found, reset login state
                    DispatchQueue.main.async {
                        self.logout()
                        completion(false)
                    }
                }
            } catch {
                // Error checking user, treat as login failed
                print("Error checking initial login status: \(error)")
                DispatchQueue.main.async {
                    self.logout()
                    completion(false)
                }
            }
        }
    }

    
    // MARK: - Authentication Methods for LoginView
    
    // Method used by LoginView to log in or auto-create users
    func loginOrCreateUser(username: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }

                // First check if username already exists
                let checkQuery = "SELECT id FROM users WHERE username = $1;"
                let checkStatement = try connection.prepareStatement(text: checkQuery)
                defer { checkStatement.close() }

                let checkCursor = try checkStatement.execute(parameterValues: [username])
                defer { checkCursor.close() }

                if let checkRowResult = try checkCursor.next() {
                    // User exists, just log them in
                    let row = try checkRowResult.get()
                    let userId = try row.columns[0].string()
                    
                    DispatchQueue.main.async {
                        self.isLoggedIn = true
                        self.currentUserId = userId
                        self.currentUsername = username
                        
                        // Store locally for persistence
                        UserDefaults.standard.set(userId, forKey: "currentUserId")
                        UserDefaults.standard.set(username, forKey: "currentUsername")
                        UserDefaults.standard.set(true, forKey: "isLoggedIn")
                        
                        completion(true)
                    }
                } else {
                    // User doesn't exist, create a new one
                    let insertQuery = "INSERT INTO users (username) VALUES ($1) RETURNING id;"
                    let insertStatement = try connection.prepareStatement(text: insertQuery)
                    defer { insertStatement.close() }

                    let insertCursor = try insertStatement.execute(parameterValues: [username])
                    defer { insertCursor.close() }
                    
                    if let insertRowResult = try insertCursor.next() {
                        let row = try insertRowResult.get()
                        let userId = try row.columns[0].string()
                        
                        DispatchQueue.main.async {
                            self.isLoggedIn = true
                            self.currentUserId = userId
                            self.currentUsername = username
                            
                            // Store locally for persistence
                            UserDefaults.standard.set(userId, forKey: "currentUserId")
                            UserDefaults.standard.set(username, forKey: "currentUsername")
                            UserDefaults.standard.set(true, forKey: "isLoggedIn")
                            
                            completion(true)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(false)
                        }
                    }
                }
            } catch {
                print("Error logging in or creating user: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    // Logout method
    func logout() {
        isLoggedIn = false
        currentUserId = nil
        currentUsername = nil
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        UserDefaults.standard.removeObject(forKey: "currentUsername")
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
    }
    
    func joinDuel(userId: String, roomCode: String, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }
                
                // 1. Verify the room code exists in the duels table
                let checkQuery = "SELECT id FROM duels WHERE room_code = $1;"
                let checkStatement = try connection.prepareStatement(text: checkQuery)
                defer { checkStatement.close() }
                
                let checkCursor = try checkStatement.execute(parameterValues: [roomCode])
                defer { checkCursor.close() }
                
                if let rowResult = try checkCursor.next() {
                    // Room exists, get the duel ID
                    let row = try rowResult.get()
                    let duelId = try row.columns[0].string()
                    
                    // 2. Add user to the duel_participants table with is_their_turn = false initially
                    let joinQuery = "INSERT INTO duel_participants (user_id, duel_id, is_their_turn) VALUES ($1, $2, false) ON CONFLICT DO NOTHING;"
                    let joinStatement = try connection.prepareStatement(text: joinQuery)
                    defer { joinStatement.close() }
                    
                    _ = try joinStatement.execute(parameterValues: [userId, duelId])
                    
                    // 3. Check if this is the second player joining (count participants)
                    let countQuery = "SELECT COUNT(*) FROM duel_participants WHERE duel_id = $1;"
                    let countStatement = try connection.prepareStatement(text: countQuery)
                    defer { countStatement.close() }
                    
                    let countCursor = try countStatement.execute(parameterValues: [duelId])
                    defer { countCursor.close() }
                    
                    if let countRowResult = try countCursor.next() {
                        let countRow = try countRowResult.get()
                        let participantCount = try countRow.columns[0].int()
                        
                        // If this is the second player, set the creator's turn to true
                        if participantCount == 2 {
                            // Get the creator ID
                            let creatorQuery = "SELECT creator_id FROM duels WHERE id = $1;"
                            let creatorStatement = try connection.prepareStatement(text: creatorQuery)
                            defer { creatorStatement.close() }
                            
                            let creatorCursor = try creatorStatement.execute(parameterValues: [duelId])
                            defer { creatorCursor.close() }
                            
                            if let creatorRowResult = try creatorCursor.next() {
                                let creatorRow = try creatorRowResult.get()
                                let creatorId = try creatorRow.columns[0].string()
                                
                                // Set creator's turn to true
                                let updateTurnQuery = """
                                    UPDATE duel_participants
                                    SET is_their_turn = (user_id = $1)
                                    WHERE duel_id = $2;
                                """
                                let updateTurnStatement = try connection.prepareStatement(text: updateTurnQuery)
                                defer { updateTurnStatement.close() }
                                
                                _ = try updateTurnStatement.execute(parameterValues: [creatorId, duelId])
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        completion(true, nil)
                    }
                } else {
                    // Room not found
                    let error = NSError(domain: "DBError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Duel room not found"])
                    DispatchQueue.main.async {
                        completion(false, error)
                    }
                }
            } catch {
                print("Error joining duel: \(error)")
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
    }

    func getRandomQuestion(completion: @escaping (Question?, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }
                
                // Query to select a random question from the questions table
                let query = "SELECT id, question_text, option_a, option_b, option_c, option_d, correct_option FROM questions ORDER BY RANDOM() LIMIT 1;"
                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }
                
                let cursor = try statement.execute()
                defer { cursor.close() }
                
                if let rowResult = try cursor.next() {
                    let row = try rowResult.get()
                    
                    let questionId = try row.columns[0].string()
                    let questionText = try row.columns[1].string()
                    let optionA = try row.columns[2].string()
                    let optionB = try row.columns[3].string()
                    let optionC = try row.columns[4].string()
                    let optionD = try row.columns[5].string()
                    let correctOption = try row.columns[6].string()
                    
                    let question = Question(
                        questionText: questionText,
                        optionA: optionA,
                        optionB: optionB,
                        optionC: optionC,
                        optionD: optionD,
                        correctOption: correctOption
                    )
                    
                    DispatchQueue.main.async {
                        completion(question, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil, NSError(domain: "DBError", code: 404, userInfo: [NSLocalizedDescriptionKey: "No questions found in database"]))
                    }
                }
            } catch {
                print("Error getting random question: \(error)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }

    // Method to assign a question to a duel
    func assignQuestionToDuel(duelId: String, questionId: String, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }
                
                // Update the duel to associate it with the question
                let query = "UPDATE duels SET current_question_id = $1 WHERE id = $2;"
                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }
                
                _ = try statement.execute(parameterValues: [questionId, duelId])
                
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } catch {
                print("Error assigning question to duel: \(error)")
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
    }

    // Method to get the current question for a duel
    // Method to get the current question for a duel with proper type casting
    func getCurrentQuestion(duelId: String, completion: @escaping (Question?, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }
                
                // Query to get the current question for a duel with explicit type casting
                let query = """
                    SELECT q.id, q.question_text, q.option_a, q.option_b, q.option_c, q.option_d, q.correct_option
                    FROM questions q
                    JOIN duels d ON q.id = CAST(d.current_question_id AS INTEGER)
                    WHERE d.id = $1;
                """
                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }
                
                let cursor = try statement.execute(parameterValues: [duelId])
                defer { cursor.close() }
                
                if let rowResult = try cursor.next() {
                    let row = try rowResult.get()
                    
                    let questionId = try row.columns[0].string()
                    let questionText = try row.columns[1].string()
                    let optionA = try row.columns[2].string()
                    let optionB = try row.columns[3].string()
                    let optionC = try row.columns[4].string()
                    let optionD = try row.columns[5].string()
                    let correctOption = try row.columns[6].string()
                    
                    let question = Question(
                        questionText: questionText,
                        optionA: optionA,
                        optionB: optionB,
                        optionC: optionC,
                        optionD: optionD,
                        correctOption: correctOption
                    )
                    
                    DispatchQueue.main.async {
                        completion(question, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil, NSError(domain: "DBError", code: 404, userInfo: [NSLocalizedDescriptionKey: "No question found for this duel"]))
                    }
                }
            } catch {
                print("Error getting current question: \(error)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }

    // Now modify the createDuel method to incorporate a random question
    // Now modify the createDuel method to incorporate a random question with proper type casting
    func createDuel(creatorId: String, completion: @escaping (Bool, String?, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }
                
                // 1. Generate a random 6-character room code
                let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ"
                let digits = "23456789"
                let allChars = letters + digits
                
                var code = ""
                for _ in 0..<6 {
                    let randomIndex = Int.random(in: 0..<allChars.count)
                    let randomChar = allChars[allChars.index(allChars.startIndex, offsetBy: randomIndex)]
                    code.append(randomChar)
                }
                
                // 2. Get a random question ID
                let questionQuery = "SELECT id FROM questions ORDER BY RANDOM() LIMIT 1;"
                let questionStatement = try connection.prepareStatement(text: questionQuery)
                defer { questionStatement.close() }
                
                let questionCursor = try questionStatement.execute()
                defer { questionCursor.close() }
                
                if let questionRowResult = try questionCursor.next() {
                    let questionRow = try questionRowResult.get()
                    let questionId = try questionRow.columns[0].string()
                    
                    // Convert questionId to Int for proper type matching with the database column
                    guard let questionIdInt = Int(questionId) else {
                        DispatchQueue.main.async {
                            completion(false, nil, NSError(domain: "DBError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid question ID format"]))
                        }
                        return
                    }
                    
                    // 3. Insert the new duel into the duels table with the question ID (as Int)
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    let timestampString = dateFormatter.string(from: Date())
                    
                    let createQuery = "INSERT INTO duels (room_code, creator_id, created_at, current_question_id) VALUES ($1, $2, $3, $4) RETURNING id;"
                    let createStatement = try connection.prepareStatement(text: createQuery)
                    defer { createStatement.close() }
                    
                    let createCursor = try createStatement.execute(parameterValues: [code, creatorId, timestampString, questionIdInt])
                    defer { createCursor.close() }
                    
                    if let rowResult = try createCursor.next() {
                        // Get the new duel ID
                        let row = try rowResult.get()
                        let duelId = try row.columns[0].string()
                        
                        // 4. Add the creator to the duel_participants table
                        let joinQuery = "INSERT INTO duel_participants (user_id, duel_id, is_their_turn) VALUES ($1, $2, false);"
                        let joinStatement = try connection.prepareStatement(text: joinQuery)
                        defer { joinStatement.close() }
                        
                        _ = try joinStatement.execute(parameterValues: [creatorId, duelId])
                        
                        DispatchQueue.main.async {
                            completion(true, code, nil)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(false, nil, NSError(domain: "DBError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create duel"]))
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false, nil, NSError(domain: "DBError", code: 404, userInfo: [NSLocalizedDescriptionKey: "No questions found in database"]))
                    }
                }
            } catch {
                print("Error creating duel: \(error)")
                DispatchQueue.main.async {
                    completion(false, nil, error)
                }
            }
        }
    }
    
    func getUserDuels(userId: String, completion: @escaping ([Duel]?, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }

                // Query to get all duels the user is participating in
                let query = """
                    SELECT d.id, d.room_code, d.creator_id, d.created_at, d.completed_at, d.active 
                    FROM duels d
                    JOIN duel_participants dp ON d.id = dp.duel_id
                    WHERE dp.user_id = $1
                    ORDER BY d.created_at DESC;
                """
                
                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }

                let cursor = try statement.execute(parameterValues: [userId], retrieveColumnMetadata: true)
                defer { cursor.close() }

                var duels = [Duel]()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

                while let rowResult = try cursor.next() {
                    let row = try rowResult.get()
                    
                    let id = try row.columns[0].string()
                    let roomCode = try row.columns[1].string()
                    let creatorId = try row.columns[2].string()
                    let createdAtString = try row.columns[3].string()
                    
                    // Handle nullable completed_at
                    let completedAtString = try row.columns[4].optionalString()
                    let active = try row.columns[5].bool()
                    
                    if let createdAt = dateFormatter.date(from: createdAtString) {
                        let completedAt = completedAtString.flatMap { dateFormatter.date(from: $0) }
                        
                        duels.append(Duel(
                            id: id,
                            roomCode: roomCode,
                            creatorId: creatorId,
                            createdAt: createdAt,
                            completedAt: completedAt,
                            active: active
                        ))
                    }
                }

                DispatchQueue.main.async {
                    completion(duels, nil)
                }
            } catch {
                print("Error getting user duels: \(error)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }
    
    func getDuelParticipants(duelId: String, completion: @escaping ([User]?, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }

                let query = """
                    SELECT u.username, dp.score
                    FROM duel_participants dp
                    JOIN users u ON CAST(dp.user_id AS INTEGER) = u.id
                    WHERE dp.duel_id = $1
                    ORDER BY dp.score DESC NULLS LAST;
                """

                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }

                let cursor = try statement.execute(parameterValues: [duelId], retrieveColumnMetadata: true)
                defer { cursor.close() }

                var participants = [User]()

                while let rowResult = try cursor.next() {
                    let row = try rowResult.get()

                    let username = try row.columns[0].string()
                    let score = try row.columns[1].optionalInt() ?? 0

                    participants.append(User(username: username, score: score))
                }

                DispatchQueue.main.async {
                    completion(participants, nil)
                }
            } catch {
                print("Error getting duel participants: \(error)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }

    // Allow a user to leave a duel
    func leaveDuel(userId: String, duelId: String, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }
                
                // Delete the participant from the duel
                let query = "DELETE FROM duel_participants WHERE user_id = $1 AND duel_id = $2;"
                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }
                
                _ = try statement.execute(parameterValues: [userId, duelId])
                
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } catch {
                print("Error leaving duel: \(error)")
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
    }

    // Update the score for a participant
    func updateScore(userId: String, duelId: String, score: Int, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }
                
                // Update the score
                let query = "UPDATE duel_participants SET score = $1 WHERE user_id = $2 AND duel_id = $3;"
                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }
                
                _ = try statement.execute(parameterValues: ["\(score)", userId, duelId])
                
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } catch {
                print("Error updating score: \(error)")
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
    }

    // Mark a duel as completed
    func completeDuel(duelId: String, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let timestampString = dateFormatter.string(from: Date())
                
                // Mark the duel as completed
                let query = "UPDATE duels SET active = false, completed_at = $1 WHERE id = $2;"
                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }
                
                _ = try statement.execute(parameterValues: [timestampString, duelId])
                
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } catch {
                print("Error completing duel: \(error)")
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
    }
    
    func recordAnswer(userId: String, duelId: String, timeTaken: Int, isCorrect: Bool, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }

                // Insert answer into database (this part stays the same)
                let query = "INSERT INTO answers (user_id, duel_id, time_taken, is_correct) VALUES ($1, $2, $3, $4);"
                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }

                _ = try statement.execute(parameterValues: [userId, duelId, timeTaken, isCorrect])

                // Check for round completion and score update
                try self.checkAndUpdateScores(duelId: duelId, connection: connection)

                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } catch {
                print("Error recording answer: \(error)")
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
    }
    
    func updateDuelQuestion(duelId: String, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }
                
                // Get a new random question that's different from the current one with proper type casting
                let query = """
                    SELECT q.id 
                    FROM questions q
                    WHERE q.id != CAST((SELECT current_question_id FROM duels WHERE id = $1) AS INTEGER)
                    ORDER BY RANDOM() 
                    LIMIT 1;
                """
                
                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }
                
                let cursor = try statement.execute(parameterValues: [duelId])
                defer { cursor.close() }
                
                if let rowResult = try cursor.next() {
                    let row = try rowResult.get()
                    let questionId = try row.columns[0].string()
                    
                    // Convert to Int for proper database type matching
                    guard let questionIdInt = Int(questionId) else {
                        DispatchQueue.main.async {
                            completion(false, NSError(domain: "DBError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid question ID format"]))
                        }
                        return
                    }
                    
                    // Update the duel with the new question
                    let updateQuery = "UPDATE duels SET current_question_id = $1 WHERE id = $2;"
                    let updateStatement = try connection.prepareStatement(text: updateQuery)
                    defer { updateStatement.close() }
                    
                    _ = try updateStatement.execute(parameterValues: [questionIdInt, duelId])
                    
                    DispatchQueue.main.async {
                        completion(true, nil)
                    }
                } else {
                    // If no different question found, just pick any random one
                    let fallbackQuery = "SELECT id FROM questions ORDER BY RANDOM() LIMIT 1;"
                    let fallbackStatement = try connection.prepareStatement(text: fallbackQuery)
                    defer { fallbackStatement.close() }
                    
                    let fallbackCursor = try fallbackStatement.execute()
                    defer { fallbackCursor.close() }
                    
                    if let fallbackRowResult = try fallbackCursor.next() {
                        let fallbackRow = try fallbackRowResult.get()
                        let questionId = try fallbackRow.columns[0].string()
                        
                        // Convert to Int for proper database type matching
                        guard let questionIdInt = Int(questionId) else {
                            DispatchQueue.main.async {
                                completion(false, NSError(domain: "DBError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid question ID format"]))
                            }
                            return
                        }
                        
                        let updateQuery = "UPDATE duels SET current_question_id = $1 WHERE id = $2;"
                        let updateStatement = try connection.prepareStatement(text: updateQuery)
                        defer { updateStatement.close() }
                        
                        _ = try updateStatement.execute(parameterValues: [questionIdInt, duelId])
                        
                        DispatchQueue.main.async {
                            completion(true, nil)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(false, NSError(domain: "DBError", code: 404, userInfo: [NSLocalizedDescriptionKey: "No questions found in database"]))
                        }
                    }
                }
            } catch {
                print("Error updating duel question: \(error)")
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
    }

    // Now let's update the checkAndUpdateScores method to include question updating
    private func checkAndUpdateScores(duelId: String, connection: Connection) throws {
        let countQuery = "SELECT COUNT(*) FROM answers WHERE duel_id = $1;"
        let countStatement = try connection.prepareStatement(text: countQuery)
        defer { countStatement.close() }

        let countCursor = try countStatement.execute(parameterValues: [duelId])
        defer { countCursor.close() }

        if let countRowResult = try countCursor.next(), let countRow = try? countRowResult.get(), let count = try? countRow.columns[0].int() {
            if count % 2 == 0 {
                // Get the last two answers
                let answersQuery = """
                    SELECT user_id, time_taken, is_correct
                    FROM answers
                    WHERE duel_id = $1
                    ORDER BY id DESC
                    LIMIT 2;
                """
                let answersStatement = try connection.prepareStatement(text: answersQuery)
                defer { answersStatement.close() }

                let answersCursor = try answersStatement.execute(parameterValues: [duelId])
                defer { answersCursor.close() }

                var answers = [(userId: String, timeTaken: Int, isCorrect: Bool)]()
                while let answerRowResult = try answersCursor.next() {
                    let answerRow = try answerRowResult.get()
                    let userId = try answerRow.columns[0].string()
                    let timeTaken = try answerRow.columns[1].int()
                    let isCorrect = try answerRow.columns[2].bool()
                    answers.append((userId: userId, timeTaken: timeTaken, isCorrect: isCorrect))
                }

                if answers.count == 2 {
                    let answer1 = answers[0]
                    let answer2 = answers[1]

                    if answer1.isCorrect && answer2.isCorrect {
                        // Both correct, faster wins
                        let winnerId = answer1.timeTaken < answer2.timeTaken ? answer1.userId : answer2.userId
                        try updateDuelParticipantScore(duelId: duelId, userId: winnerId, connection: connection)
                    } else if !answer1.isCorrect && !answer2.isCorrect {
                        // Both incorrect, tie
                    } else {
                        // One correct, one incorrect
                        let winnerId = answer1.isCorrect ? answer1.userId : answer2.userId
                        try updateDuelParticipantScore(duelId: duelId, userId: winnerId, connection: connection)
                    }
                    
                    // Update the question for the next round
                    // We need to do this outside the current transaction
                    DispatchQueue.global(qos: .background).async {
                        self.updateDuelQuestion(duelId: duelId) { success, error in
                            if success {
                                print("Updated question for next round in duel \(duelId)")
                            } else {
                                print("Error updating question: \(error?.localizedDescription ?? "Unknown error")")
                            }
                        }
                    }
                }
            }
        }
    }

    private func updateDuelParticipantScore(duelId: String, userId: String, connection: Connection) throws {
        let updateQuery = """
            UPDATE duel_participants
            SET score = score + 1
            WHERE duel_id = $1 AND user_id = $2;
        """
        let updateStatement = try connection.prepareStatement(text: updateQuery)
        defer { updateStatement.close() }

        _ = try updateStatement.execute(parameterValues: [duelId, userId])
        
        try checkForWinner(duelId: duelId, connection: connection)
    }
    
    private func checkForWinner(duelId: String, connection: Connection) throws {
        let query = """
            SELECT user_id FROM duel_participants
            WHERE duel_id = $1 AND score = 3;
        """
        let statement = try connection.prepareStatement(text: query)
        defer { statement.close() }

        let cursor = try statement.execute(parameterValues: [duelId])
        defer { cursor.close() }

        if let rowResult = try cursor.next() {
            let row = try rowResult.get()
            let winnerId = try row.columns[0].string()

            // Winner found, set both is_their_turn to false
            let updateQuery = """
                UPDATE duel_participants
                SET is_their_turn = false
                WHERE duel_id = $1;
            """
            let updateStatement = try connection.prepareStatement(text: updateQuery)
            defer { updateStatement.close() }

            _ = try updateStatement.execute(parameterValues: [duelId])

            // Mark the duel as completed
            try completeDuel(duelId: duelId, connection: connection)

            print("Winner found: \(winnerId) in duel \(duelId)")
            
            // Get winner and loser info for notifications
            DispatchQueue.global(qos: .background).async {
                self.getWinnerAndLoserInfo(duelId: duelId, winnerId: winnerId) { winnerOneSignalId, winnerName, loserOneSignalId, loserName in
                    if let winnerOneSignalId = winnerOneSignalId,
                       let winnerName = winnerName,
                       let loserOneSignalId = loserOneSignalId,
                       let loserName = loserName {
                        // Send game result notifications
                        OneSignalManager.shared.sendGameResultNotification(
                            winnerId: winnerOneSignalId,
                            winnerName: winnerName,
                            loserId: loserOneSignalId,
                            loserName: loserName,
                            duelId: duelId
                        )
                    }
                }
            }
        }
    }
    
    // Helper function to get winner and loser information for notifications
    func getWinnerAndLoserInfo(duelId: String, winnerId: String, completion: @escaping (String?, String?, String?, String?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }
                
                // Get winner info
                let winnerQuery = """
                    SELECT u.username, u.onesignal_id
                    FROM users u
                    WHERE u.id = $1;
                """
                let winnerStatement = try connection.prepareStatement(text: winnerQuery)
                defer { winnerStatement.close() }
                
                let winnerCursor = try winnerStatement.execute(parameterValues: [winnerId])
                defer { winnerCursor.close() }
                
                var winnerName: String?
                var winnerOneSignalId: String?
                var loserName: String?
                var loserOneSignalId: String?
                
                if let winnerRowResult = try winnerCursor.next() {
                    let winnerRow = try winnerRowResult.get()
                    winnerName = try winnerRow.columns[0].string()
                    winnerOneSignalId = try winnerRow.columns[1].optionalString()
                    
                    // Get loser info
                    let loserQuery = """
                        SELECT u.username, u.onesignal_id
                        FROM duel_participants dp
                        JOIN users u ON CAST(dp.user_id AS INTEGER) = u.id
                        WHERE dp.duel_id = $1 AND dp.user_id != $2;
                    """
                    let loserStatement = try connection.prepareStatement(text: loserQuery)
                    defer { loserStatement.close() }
                    
                    let loserCursor = try loserStatement.execute(parameterValues: [duelId, winnerId])
                    defer { loserCursor.close() }
                    
                    if let loserRowResult = try loserCursor.next() {
                        let loserRow = try loserRowResult.get()
                        loserName = try loserRow.columns[0].string()
                        loserOneSignalId = try loserRow.columns[1].optionalString()
                    }
                }
                
                DispatchQueue.main.async {
                    completion(winnerOneSignalId, winnerName, loserOneSignalId, loserName)
                }
            } catch {
                print("Error getting winner and loser info: \(error)")
                DispatchQueue.main.async {
                    completion(nil, nil, nil, nil)
                }
            }
        }
    }
    
    func determineRoundWinner(duelId: String, roundNumber: Int, completion: @escaping (String?, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }
                
                // Get all answers for the specific round/question number
                let query = """
                    SELECT a.user_id, a.time_taken, a.is_correct, u.username
                    FROM answers a
                    JOIN users u ON a.user_id = u.id
                    WHERE a.duel_id = $1
                    ORDER BY a.id
                """
                
                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }
                
                let cursor = try statement.execute(parameterValues: [duelId])
                defer { cursor.close() }
                
                // Parse the answers
                var answers: [(userId: String, timeTaken: Int, isCorrect: Bool, username: String)] = []
                while let rowResult = try cursor.next() {
                    let row = try rowResult.get()
                    let userId = try row.columns[0].string()
                    let timeTaken = try row.columns[1].int()
                    let isCorrect = try row.columns[2].bool()
                    let username = try row.columns[3].string()
                    
                    answers.append((userId: userId, timeTaken: timeTaken, isCorrect: isCorrect, username: username))
                }
                
                // Process into rounds
                var rounds: [Int: [(userId: String, timeTaken: Int, isCorrect: Bool, username: String)]] = [:]
                var userAnswerCounts: [String: Int] = [:]
                
                for answer in answers {
                    // Increment this user's answer count
                    userAnswerCounts[answer.userId, default: 0] += 1
                    
                    // The question number is the user's answer count
                    let questionNumber = userAnswerCounts[answer.userId, default: 0]
                    
                    // Add to the appropriate round
                    if rounds[questionNumber] == nil {
                        rounds[questionNumber] = []
                    }
                    rounds[questionNumber]?.append(answer)
                }
                
                // Find the specific round
                if let roundAnswers = rounds[roundNumber], roundAnswers.count == 2 {
                    let answer1 = roundAnswers[0]
                    let answer2 = roundAnswers[1]
                    
                    // Determine winner
                    var winnerId: String? = nil
                    
                    if answer1.isCorrect && answer2.isCorrect {
                        // Both correct, faster wins
                        winnerId = answer1.timeTaken < answer2.timeTaken ? answer1.userId : answer2.userId
                    } else if answer1.isCorrect && !answer2.isCorrect {
                        // First player correct
                        winnerId = answer1.userId
                    } else if !answer1.isCorrect && answer2.isCorrect {
                        // Second player correct
                        winnerId = answer2.userId
                    }
                    // If both are incorrect, winner remains nil
                    
                    DispatchQueue.main.async {
                        completion(winnerId, nil)
                    }
                } else {
                    // Not enough answers for this round yet
                    DispatchQueue.main.async {
                        completion(nil, nil)
                    }
                }
            } catch {
                print("Error determining round winner: \(error)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }

    // Add a method to get round data with winner information
    func getDuelRounds(duelId: String, completion: @escaping ([(roundNumber: Int, userAnswers: [Answer], winnerId: String?)]?, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }
                
                // Get all answers for the duel
                let query = """
                    SELECT a.user_id, a.time_taken, a.is_correct, a.id, u.username
                    FROM answers a
                    JOIN users u ON CAST(a.user_id AS INTEGER) = u.id
                    WHERE a.duel_id = $1
                    ORDER BY a.id
                """
                
                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }
                
                let cursor = try statement.execute(parameterValues: [duelId])
                defer { cursor.close() }
                
                // Parse the answers
                var answers: [(userId: String, timeTaken: Int, isCorrect: Bool, id: Int, username: String)] = []
                while let rowResult = try cursor.next() {
                    let row = try rowResult.get()
                    let userId = try row.columns[0].string()
                    let timeTaken = try row.columns[1].int()
                    let isCorrect = try row.columns[2].bool()
                    let id = try row.columns[3].int()
                    let username = try row.columns[4].string()
                    
                    answers.append((userId: userId, timeTaken: timeTaken, isCorrect: isCorrect, id: id, username: username))
                }
                
                // Process into rounds based on user's answer count
                var userAnswerCounts: [String: Int] = [:]
                var roundsMap: [Int: [Answer]] = [:]
                var roundToWinner: [Int: String?] = [:]
                
                for answer in answers {
                    // Increment this user's answer count
                    userAnswerCounts[answer.userId, default: 0] += 1
                    
                    // The question number is the user's answer count
                    let questionNumber = userAnswerCounts[answer.userId, default: 0]
                    
                    // Create Answer object
                    let answerObj = Answer(
                        userId: answer.userId,
                        questionNumber: questionNumber,
                        timeTaken: answer.timeTaken,
                        isCorrect: answer.isCorrect
                    )
                    
                    // Add to the round collection
                    if roundsMap[questionNumber] == nil {
                        roundsMap[questionNumber] = []
                    }
                    roundsMap[questionNumber]?.append(answerObj)
                    
                    // Determine winner for completed rounds
                    if let answers = roundsMap[questionNumber], answers.count == 2 {
                        let answer1 = answers[0]
                        let answer2 = answers[1]
                        
                        var winnerId: String? = nil
                        
                        if answer1.isCorrect && answer2.isCorrect {
                            // Both correct, faster wins
                            winnerId = answer1.timeTaken < answer2.timeTaken ? answer1.userId : answer2.userId
                        } else if answer1.isCorrect && !answer2.isCorrect {
                            // First player correct
                            winnerId = answer1.userId
                        } else if !answer1.isCorrect && answer2.isCorrect {
                            // Second player correct
                            winnerId = answer2.userId
                        }
                        // If both are incorrect, winner remains nil
                        
                        roundToWinner[questionNumber] = winnerId
                    }
                }
                
                // Convert to array format expected by the completion handler
                var result: [(roundNumber: Int, userAnswers: [Answer], winnerId: String?)] = []
                
                for (questionNumber, answers) in roundsMap {
                    result.append((
                        roundNumber: questionNumber,
                        userAnswers: answers,
                        winnerId: roundToWinner[questionNumber] ?? nil
                    ))
                }
                
                // Sort by question number
                let sortedResult = result.sorted(by: { $0.roundNumber < $1.roundNumber })
                
                DispatchQueue.main.async {
                    completion(sortedResult, nil)
                }
            } catch {
                print("Error getting duel rounds: \(error)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }

    private func completeDuel(duelId: String, connection: Connection) throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestampString = dateFormatter.string(from: Date())

        // Update duels table to mark duel as completed
        let duelUpdateQuery = "UPDATE duels SET active = false, completed_at = $1 WHERE id = $2;"
        let duelUpdateStatement = try connection.prepareStatement(text: duelUpdateQuery)
        defer { duelUpdateStatement.close() }

        _ = try duelUpdateStatement.execute(parameterValues: [timestampString, duelId])

        // Update duel_participants table to set is_their_turn to false for all participants
        let participantsUpdateQuery = "UPDATE duel_participants SET is_their_turn = false WHERE duel_id = $1;"
        let participantsUpdateStatement = try connection.prepareStatement(text: participantsUpdateQuery)
        defer { participantsUpdateStatement.close() }

        _ = try participantsUpdateStatement.execute(parameterValues: [duelId])
    }
    
    private func switchTurn(duelId: String, currentUserId: String, connection: Connection) throws {
        // Find the opponent's user ID
        let opponentQuery = """
            SELECT user_id FROM duel_participants
            WHERE duel_id = $1 AND user_id != $2;
        """
        let opponentStatement = try connection.prepareStatement(text: opponentQuery)
        defer { opponentStatement.close() }

        let opponentCursor = try opponentStatement.execute(parameterValues: [duelId, currentUserId])
        defer { opponentCursor.close() }

        if let rowResult = try opponentCursor.next() {
            let row = try rowResult.get()
            let opponentUserId = try row.columns[0].string()

            // Update is_their_turn flags
            let updateQuery = """
                UPDATE duel_participants
                SET is_their_turn = (user_id = $1)
                WHERE duel_id = $2;
            """
            let updateStatement = try connection.prepareStatement(text: updateQuery)
            defer { updateStatement.close() }

            _ = try updateStatement.execute(parameterValues: [opponentUserId, duelId])
        }
    }
    
    func switchTurn(duelId: String, currentUserId: String, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }

                // Find the opponent's user ID
                let opponentQuery = """
                    SELECT user_id FROM duel_participants
                    WHERE duel_id = $1 AND user_id != $2;
                """
                let opponentStatement = try connection.prepareStatement(text: opponentQuery)
                defer { opponentStatement.close() }

                let opponentCursor = try opponentStatement.execute(parameterValues: [duelId, currentUserId])
                defer { opponentCursor.close() }

                if let rowResult = try opponentCursor.next() {
                    let row = try rowResult.get()
                    let opponentUserId = try row.columns[0].string()

                    // Update is_their_turn flags
                    let updateQuery = """
                        UPDATE duel_participants
                        SET is_their_turn = (user_id = $1)
                        WHERE duel_id = $2;
                    """
                    let updateStatement = try connection.prepareStatement(text: updateQuery)
                    defer { updateStatement.close() }

                    _ = try updateStatement.execute(parameterValues: [opponentUserId, duelId])

                    DispatchQueue.main.async {
                        completion(true, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false, NSError(domain: "DBError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Opponent not found"]))
                    }
                }
            } catch {
                print("Error switching turn: \(error)")
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
    }
    
    func isUsersTurn(userId: String, duelId: String, completion: @escaping (Bool?, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }

                let query = "SELECT is_their_turn FROM duel_participants WHERE user_id = $1 AND duel_id = $2;"
                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }

                let cursor = try statement.execute(parameterValues: [userId, duelId])
                defer { cursor.close() }

                if let rowResult = try cursor.next() {
                    let row = try rowResult.get()
                    let isTurn = try row.columns[0].bool()
                    DispatchQueue.main.async {
                        completion(isTurn, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil, nil) // User or duel not found
                    }
                }
            } catch {
                print("Error checking turn: \(error)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }
    
    func getDuelAnswers(duelId: String, completion: @escaping ([Answer]?, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }

                // Get all answers for the duel
                let query = """
                    SELECT 
                        user_id,
                        time_taken,
                        is_correct,
                        id
                    FROM answers
                    WHERE duel_id = $1
                    ORDER BY id;
                """
                
                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }

                let cursor = try statement.execute(parameterValues: [duelId])
                defer { cursor.close() }

                var rawAnswers: [(userId: String, timeTaken: Int, isCorrect: Bool, id: Int)] = []

                while let rowResult = try cursor.next() {
                    let row = try rowResult.get()
                    
                    let userId = try row.columns[0].string()
                    let timeTaken = try row.columns[1].int()
                    let isCorrect = try row.columns[2].bool()
                    let id = try row.columns[3].int()
                    
                    rawAnswers.append((userId: userId, timeTaken: timeTaken, isCorrect: isCorrect, id: id))
                }

                // Process answers using the current user ID to identify user vs opponent answers
                let currentUserId = self.currentUserId ?? ""
                let answers = self.processRawAnswers(rawAnswers: rawAnswers, currentUserId: currentUserId)

                DispatchQueue.main.async {
                    completion(answers, nil)
                }
            } catch {
                print("Error getting duel answers: \(error)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }
    
    // Helper function to process raw answers into properly numbered rounds
    private func processRawAnswers(rawAnswers: [(userId: String, timeTaken: Int, isCorrect: Bool, id: Int)], currentUserId: String) -> [Answer] {
        // If there are no answers, return empty array
        if rawAnswers.isEmpty {
            return []
        }
        
        // Get unique user IDs
        let userIds = Array(Set(rawAnswers.map { $0.userId }))
        
        // Initialize answers array
        var answers: [Answer] = []
        
        // Assign question numbers based on pairs of answers
        var userAnswerCounts: [String: Int] = [:]
        for userId in userIds {
            userAnswerCounts[userId] = 0
        }
        
        for rawAnswer in rawAnswers {
            // Increment this user's answer count
            userAnswerCounts[rawAnswer.userId, default: 0] += 1
            
            // The question number is the user's answer count
            let questionNumber = userAnswerCounts[rawAnswer.userId, default: 0]
            
            // Determine if this is a user answer based on comparing with current user ID
            let isUserAnswer = rawAnswer.userId == currentUserId
            
            // Create the new Answer model object
            let answer = Answer(
                userId: rawAnswer.userId,
                questionNumber: questionNumber,
                timeTaken: rawAnswer.timeTaken,
                isCorrect: rawAnswer.isCorrect,
                isUserAnswer: isUserAnswer
            )
            
            answers.append(answer)
        }
        
        return answers
    }
    
    // Initialize with saved login state (if any)
    init() {
        // Restore login state from UserDefaults
        if UserDefaults.standard.bool(forKey: "isLoggedIn") {
            self.isLoggedIn = true
            self.currentUserId = UserDefaults.standard.string(forKey: "currentUserId")
            self.currentUsername = UserDefaults.standard.string(forKey: "currentUsername")
        }
    }
}

extension PostgresDBManager {
    // Save a user's OneSignal player ID
    func saveOneSignalPlayerId(userId: String, playerId: String, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }
                
                // Add column to users table if it doesn't exist
                let checkColumnQuery = """
                    DO $$ 
                    BEGIN
                        IF NOT EXISTS (
                            SELECT FROM information_schema.columns 
                            WHERE table_name = 'users' AND column_name = 'onesignal_id'
                        ) THEN
                            ALTER TABLE users ADD COLUMN onesignal_id TEXT;
                        END IF;
                    END $$;
                """
                let checkColumnStatement = try connection.prepareStatement(text: checkColumnQuery)
                defer { checkColumnStatement.close() }
                _ = try checkColumnStatement.execute()
                
                // Update the user with their OneSignal ID
                let updateQuery = "UPDATE users SET onesignal_id = $1 WHERE id = $2;"
                let statement = try connection.prepareStatement(text: updateQuery)
                defer { statement.close() }
                
                _ = try statement.execute(parameterValues: [playerId, userId])
                
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } catch {
                print("Error saving OneSignal player ID: \(error)")
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
    }
    
    // Get opponent's information including OneSignal ID
    func getOpponentInfo(duelId: String, currentUserId: String, completion: @escaping (String?, String?, String?, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }
                
                // Fixed query with proper type casting
                let query = """
                    SELECT u.id, u.username, u.onesignal_id
                    FROM duel_participants dp
                    JOIN users u ON CAST(dp.user_id AS INTEGER) = u.id
                    WHERE dp.duel_id = $1 AND dp.user_id != $2;
                """
                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }
                
                let cursor = try statement.execute(parameterValues: [duelId, currentUserId])
                defer { cursor.close() }
                
                if let rowResult = try cursor.next() {
                    let row = try rowResult.get()
                    let userId = try row.columns[0].string()
                    let username = try row.columns[1].string()
                    let oneSignalId = try row.columns[2].optionalString()
                    
                    print("Retrieved opponent info - userId: \(userId), username: \(username), oneSignalId: \(oneSignalId ?? "nil")")
                    
                    DispatchQueue.main.async {
                        completion(userId, username, oneSignalId, nil)
                    }
                } else {
                    print("No opponent found for duel \(duelId) and user \(currentUserId)")
                    DispatchQueue.main.async {
                        completion(nil, nil, nil, NSError(domain: "DBError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Opponent not found"]))
                    }
                }
            } catch {
                print("Error getting opponent info: \(error)")
                DispatchQueue.main.async {
                    completion(nil, nil, nil, error)
                }
            }
        }
    }
    
    // Get the room code for a duel
    func getDuelRoomCode(duelId: String, completion: @escaping (String?, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }
                
                let query = "SELECT room_code FROM duels WHERE id = $1;"
                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }
                
                let cursor = try statement.execute(parameterValues: [duelId])
                defer { cursor.close() }
                
                if let rowResult = try cursor.next() {
                    let row = try rowResult.get()
                    let roomCode = try row.columns[0].string()
                    
                    DispatchQueue.main.async {
                        completion(roomCode, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil, NSError(domain: "DBError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Duel not found"]))
                    }
                }
            } catch {
                print("Error getting duel room code: \(error)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }
    
    // Modified recordAnswer method that also handles notifications via OneSignalManager
    func recordAnswerAndNotify(userId: String, duelId: String, timeTaken: Int, isCorrect: Bool, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let connection = try self.getConnection()
                defer { connection.close() }
                
                // 1. Record the answer
                let query = "INSERT INTO answers (user_id, duel_id, time_taken, is_correct) VALUES ($1, $2, $3, $4);"
                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }
                
                _ = try statement.execute(parameterValues: [userId, duelId, timeTaken, isCorrect])
                
                // 2. Check for round completion and score update
                try self.checkAndUpdateScores(duelId: duelId, connection: connection)
                
                // 3. Switch the turn
                try self.switchTurn(duelId: duelId, currentUserId: userId, connection: connection)
                
                DispatchQueue.main.async {
                    // 4. Now handle the notification part
                    if let username = self.currentUsername {
                        // Get the room code
                        self.getDuelRoomCode(duelId: duelId) { roomCode, roomCodeError in
                            if let roomCode = roomCode {
                                // Get the opponent info with the OneSignal ID this time
                                self.getOpponentInfo(duelId: duelId, currentUserId: userId) { opponentId, opponentName, opponentOneSignalId, opponentError in
                                    // Check specifically for the OneSignal ID
                                    if let opponentOneSignalId = opponentOneSignalId, !opponentOneSignalId.isEmpty {
                                        print("Sending notification to opponent with OneSignal ID: \(opponentOneSignalId)")
                                        
                                        // Send notification using the OneSignal ID
                                        OneSignalManager.shared.sendTurnNotification(
                                            to: opponentOneSignalId,  // Important: Use ONLY the OneSignal ID here!
                                            duelId: duelId,
                                            roomCode: roomCode,
                                            username: username
                                        )
                                        completion(true, nil)
                                    } else {
                                        print("Cannot send notification: Missing opponent OneSignal ID for user \(opponentId ?? "unknown")")
                                        // Still mark as success even if notification fails
                                        completion(true, NSError(domain: "NotificationError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Opponent's OneSignal ID not found"]))
                                    }
                                }
                            } else {
                                print("Cannot send notification: Missing room code")
                                // Still mark as success even if notification fails
                                completion(true, roomCodeError)
                            }
                        }
                    } else {
                        print("Cannot send notification: Missing current username")
                        // Still mark as success even if notification fails
                        completion(true, nil)
                    }
                }
            } catch {
                print("Error recording answer: \(error)")
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
    }
}
