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

            // Optionally, mark the duel as completed
            try completeDuel(duelId: duelId, connection: connection)

            print("Winner found: \(winnerId) in duel \(duelId)")
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
