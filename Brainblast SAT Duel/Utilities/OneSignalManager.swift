import Foundation
import OneSignalFramework
import SwiftUI

// OneSignalManager class to handle push notifications
class OneSignalManager: ObservableObject {
    static let shared = OneSignalManager()
    
    @Published var playerId: String?
    
    private init() {}
    
    func initialize() {
        // Initialize OneSignal using the v5 API
        OneSignal.initialize("5e0ad247-1c5a-46a4-ba3d-843f2a19b0bb", withLaunchOptions: nil)
        
        // Request permission and register for push notifications
        OneSignal.Notifications.requestPermission({ accepted in
            print("User accepted notifications: \(accepted)")
            
            // Wait a moment for the subscription to be established after permission
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.updatePlayerId()
            }
        }, fallbackToSettings: true)
        
        // Try to get the initial player ID (may be nil)
        updatePlayerId()
        
        // Add a timer to periodically check for the player ID
        // since it might become available later
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            if self?.playerId != nil {
                timer.invalidate()
            } else {
                self?.updatePlayerId()
            }
        }
    }
    
    private func updatePlayerId() {
        // Check if the ID is now available
        if let id = OneSignal.User.pushSubscription.id {
            self.playerId = id
            print("OneSignal Push Subscription ID updated: \(id)")
            
            // Post notification so other parts of the app can respond
            NotificationCenter.default.post(
                name: NSNotification.Name("OneSignalPlayerIDUpdated"),
                object: nil,
                userInfo: ["playerId": id]
            )
        } else {
            print("OneSignal Push Subscription ID still not available")
        }
    }
    
    // Save user's external ID (your app's user ID) in OneSignal
    func setExternalUserId(userId: String) {
        OneSignal.login(userId)
    }
    
    // Send notification to another user with correct player_ids parameter
    func sendTurnNotification(to userId: String, duelId: String, roomCode: String, username: String) {
        print("Sending notification to player ID: \(userId)")
        
        let notificationContent: [String: Any] = [
            "app_id": "5e0ad247-1c5a-46a4-ba3d-843f2a19b0bb",
            "include_player_ids": [userId], // Changed from include_external_user_ids
            "contents": ["en": "\(username.prefix(1).uppercased() + username.dropFirst()) has submitted their answer. It's your turn!"],
            "headings": ["en": "SAT Duel"],
            "data": ["duelId": duelId, "roomCode": roomCode],
            "ios_badgeType": "Increase",
            "ios_badgeCount": 1
        ]
        
        // Use the shared sendNotification method instead of duplicating the code
        sendNotification(content: notificationContent)
    }
    
    // Send game result notification to both players
    func sendGameResultNotification(winnerId: String, winnerName: String, loserId: String, loserName: String, duelId: String) {
        // Send winner notification
        let winnerNotificationContent: [String: Any] = [
            "app_id": "5e0ad247-1c5a-46a4-ba3d-843f2a19b0bb",
            "include_player_ids": [winnerId],
            "contents": ["en": "You beat \(loserName.prefix(1).uppercased() + loserName.dropFirst())!"],
            "headings": ["en": "SAT Duel"],
            "data": ["duelId": duelId, "result": "win"],
            "ios_badgeType": "Increase",
            "ios_badgeCount": 1
        ]
        
        // Send loser notification
        let loserNotificationContent: [String: Any] = [
            "app_id": "5e0ad247-1c5a-46a4-ba3d-843f2a19b0bb",
            "include_player_ids": [loserId],
            "contents": ["en": "\(winnerName.prefix(1).uppercased() + winnerName.dropFirst()) beat You!"],
            "headings": ["en": "SAT Duel"],
            "data": ["duelId": duelId, "result": "loss"],
            "ios_badgeType": "Increase",
            "ios_badgeCount": 1
        ]
        
        // Send both notifications
        sendNotification(content: winnerNotificationContent)
        sendNotification(content: loserNotificationContent)
    }

    // Helper method to send a notification with given content
    private func sendNotification(content: [String: Any]) {
        let url = URL(string: "https://onesignal.com/api/v1/notifications")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic os_v2_app_lyfnery4ljdkjor5qq7sugnqxmkkrlpfyneevm4azu4mdkoncdok7rrkolntsjgmhwfqyxihbsse2n2ipfkbgjfcevrcfxlrpki5evi", forHTTPHeaderField: "Authorization")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: content)
            request.httpBody = jsonData
            
            print("Sending OneSignal notification with payload: \(content)")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error sending notification: \(error)")
                    return
                }
                
                guard let data = data else {
                    print("No data returned from OneSignal API")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("OneSignal API responded with code: \(httpResponse.statusCode)")
                    
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Full Response: \(responseString)")
                        
                        // Parse the JSON response to check for errors
                        do {
                            if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                if let errors = jsonResponse["errors"] as? [Any], !errors.isEmpty {
                                    print("OneSignal API returned errors: \(errors)")
                                }
                                
                                if let id = jsonResponse["id"] as? String {
                                    print("Notification sent successfully with ID: \(id)")
                                }
                            }
                        } catch {
                            print("Error parsing OneSignal API response: \(error)")
                        }
                    }
                    
                    // Check for error status codes
                    if httpResponse.statusCode >= 400 {
                        print("OneSignal API request failed with status code: \(httpResponse.statusCode)")
                    }
                }
            }.resume()
        } catch {
            print("Error creating JSON for notification: \(error)")
        }
    }
}
