import SwiftUI

struct DuelResultView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var dbManager: PostgresDBManager
    @Binding var navigateToHome: Bool
    
    let isWinner: Bool
    let opponentName: String
    let userScore: Int
    let opponentScore: Int
    let duelId: String // Added duelId parameter
    
    // State to track if the player has been removed from the duel
    @State private var hasBeenRemoved: Bool = false
    @State private var showRemovalError: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                // Top header with home button and leave button - same as DuelDetailView
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
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Result display - replaced "You lost" with GIF
                VStack(spacing: 20) {
                    // GIF based on whether user won or lost
                    if isWinner {
                        GIFView(gifName: "victory")
                            .frame(width: 300, height: 360)
                    } else {
                        GIFView(gifName: "defeat")
                            .frame(width: 300, height: 360)
                    }
                    
                    // Score display
                    Text("Final Score")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.top)
                    
                    HStack(spacing: 40) {
                        // User score
                        VStack {
                            Text("You")
                                .font(.headline)
                                .foregroundColor(.black)
                            Text("\(userScore)")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                        }
                        
                        Text("vs")
                            .font(.headline)
                            .foregroundColor(.black)
                        
                        // Opponent score
                        VStack {
                            Text(opponentName.prefix(1).uppercased() + opponentName.dropFirst())
                                .font(.headline)
                                .foregroundColor(.black)
                            Text("\(opponentScore)")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                        }
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
                    
                    // Error message if removal fails
                    if showRemovalError {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.top)
                    }
                }
                
                Spacer()
            }
            
            // Navigation link to Content View - exactly like DuelDetailView
            NavigationLink(
                destination: ContentView()
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
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .onAppear {
            // Make sure we reset any loading state when this view appears
            appState.stopLoading()
            appState.stopNavigating()
        }
        .alert(isPresented: $showRemovalError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
