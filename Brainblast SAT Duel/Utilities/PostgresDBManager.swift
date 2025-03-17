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
                    
                    // 2. Add user to the duel_participants table
                    let joinQuery = "INSERT INTO duel_participants (user_id, duel_id) VALUES ($1, $2) ON CONFLICT DO NOTHING;"
                    let joinStatement = try connection.prepareStatement(text: joinQuery)
                    defer { joinStatement.close() }
                    
                    _ = try joinStatement.execute(parameterValues: [userId, duelId])
                    
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
                
                // 2. Insert the new duel into the duels table
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let timestampString = dateFormatter.string(from: Date())
                
                let createQuery = "INSERT INTO duels (room_code, creator_id, created_at) VALUES ($1, $2, $3) RETURNING id;"
                let createStatement = try connection.prepareStatement(text: createQuery)
                defer { createStatement.close() }
                
                let createCursor = try createStatement.execute(parameterValues: [code, creatorId, timestampString])
                defer { createCursor.close() }
                
                if let rowResult = try createCursor.next() {
                    // Get the new duel ID
                    let row = try rowResult.get()
                    let duelId = try row.columns[0].string()
                    
                    // 3. Add the creator to the duel_participants table
                    let joinQuery = "INSERT INTO duel_participants (user_id, duel_id) VALUES ($1, $2);"
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
                    SELECT dp.id, dp.user_id, u.username, dp.joined_at, dp.score
                    FROM duel_participants dp
                    JOIN users u ON CAST(dp.user_id AS INTEGER) = u.id
                    WHERE dp.duel_id = $1
                    ORDER BY dp.score DESC, dp.joined_at ASC;
                """

                let statement = try connection.prepareStatement(text: query)
                defer { statement.close() }

                let cursor = try statement.execute(parameterValues: [duelId], retrieveColumnMetadata: true)
                defer { cursor.close() }

                var participants = [User]()

                while let rowResult = try cursor.next() {
                    let row = try rowResult.get()

                    let username = try row.columns[2].string()

                    participants.append(User(username: username))
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
