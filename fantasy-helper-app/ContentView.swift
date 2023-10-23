//
//  ContentView.swift
//  fantasy-helper-app
//
//  Created by Jorden Gerovac on 2023-10-20.
//

import SwiftUI

struct ContentView: View {
    @State private var players: [Player] = []
    @State private var playersLoading: Bool = true
    @State private var comparisonLoading: Bool = false
    @State private var firstSelection: String = ""
    @State private var secondSelection: String = ""
    @State private var firstSearchTerm: String = ""
    @State private var secondSearchTerm: String = ""
    @State private var comparisonMessage: String = ""
    @State private var showComparisonMessage: Bool = false

    var body: some View {
        NavigationStack {
            VStack {
                if !playersLoading {
                    Text("Pick two players to compare for your fantasy team")
                    VStack {
                        TextField(
                            "Search player",
                            text: $firstSearchTerm
                        )
                        .padding(10)
                        Picker(selection: $firstSelection, label: Text("Select first player")) {
                            Text("Select first player").tag(Optional<String>(nil))
                            ForEach(searchResults(searchTerm: firstSearchTerm), id: \.name) { player in
                                Text(player.name)
                            }
                        }
                        .padding(10)
                    }
                    VStack {
                        TextField(
                            "Search player",
                            text: $secondSearchTerm
                        )
                        .padding(10)
                        Picker(selection: $secondSelection, label: Text("Select second player")) {
                            Text("Select second player").tag(Optional<String>(nil))
                            ForEach(searchResults(searchTerm: secondSearchTerm), id: \.name) { player in
                                Text(player.name)
                            }
                        }
                        .padding(10)
                    }
                Button(action: {
                    Task {
                        do {
                            comparisonLoading = true
                            showComparisonMessage = true
                            comparisonMessage = try await comparePlayers()
                            comparisonLoading = false
                        } catch FantasyHelperError.invalidURL {
                            print("Invalid URL")
                            comparisonLoading = false
                        } catch FantasyHelperError.invalidResponse {
                            print("Invalid response")
                            comparisonLoading = false
                        } catch FantasyHelperError.invalidData {
                            print("Invalid data")
                            comparisonLoading = false
                        } catch {
                            print("Unexpected error")
                            comparisonLoading = false
                        }
                    }
                }) {
                    Text("Compare players")
                }
                .padding(10)
                .disabled(firstSelection == "" || secondSelection == "")
                } else {
                    HStack(spacing: 15) {
                        ProgressView()
                        Text("Loading…")
                    }
                }
            }
            .padding()
            .task {
                do {
                    playersLoading = true
                    players = try await getPlayers()
                    playersLoading = false
                } catch FantasyHelperError.invalidURL {
                    print("Invalid URL")
                    playersLoading = false
                } catch FantasyHelperError.invalidResponse {
                    print("Invalid response")
                    playersLoading = false
                } catch FantasyHelperError.invalidData {
                    print("Invalid data")
                    playersLoading = false
                } catch {
                    print("Unexpected error")
                    playersLoading = false
                }
            }
            .navigationDestination(isPresented: $showComparisonMessage) {
                VStack {
                    if !comparisonLoading {
                        Text(comparisonMessage)
                        Button("close") {
                            showComparisonMessage = false
                        }
                        .padding(10)
                    } else {
                        HStack(spacing: 15) {
                            ProgressView()
                            Text("Loading…")
                        }
                    }
                }
                .padding(20)
            }
        }
    }
    
    func searchResults(searchTerm: String) -> [Player] {
        if searchTerm.isEmpty {
            return players
        } else {
            return players.filter { $0.name.contains(searchTerm) }
        }
    }
    
    func getPlayers() async throws -> [Player] {
        let endpoint = "http://localhost:4000/players"
        
        // Using url string to create URL object
        guard let url = URL(string: endpoint) else {
            throw FantasyHelperError.invalidURL
        }
        
        // Sending http request
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Casting response as HTTPURLResponse
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw FantasyHelperError.invalidResponse
        }
        
        // Decoding http response as json
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let decodedData = try decoder.decode(PlayerData.self, from: data)
            return decodedData.data.sorted(by: { $0.name < $1.name })
        } catch {
            throw FantasyHelperError.invalidData
        }
    }
    
    func comparePlayers() async throws -> String {
        let endpoint = "http://localhost:4000/players/compare/" + firstSelection + "/" + secondSelection
        let formattedEndpoint = endpoint.replacingOccurrences(of: " ", with: "%20", options: .literal, range: nil)
        
        // Using url string to create URL object
        guard let url = URL(string: formattedEndpoint) else {
            throw FantasyHelperError.invalidURL
        }
        
        // Sending http request
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Casting response as HTTPURLResponse
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw FantasyHelperError.invalidResponse
        }
        
        // Decoding http response as json
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let decodedData = try decoder.decode(ComparisonData.self, from: data)
            return decodedData.data.choices[0].message.content
        } catch {
            throw FantasyHelperError.invalidData
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// Player object
struct Player: Codable, Identifiable {
    let id: String
    let name: String
    let team: String
    let position: String
    let gamesPlayed: Int
    let type: String
}

// Received Player data from api
struct PlayerData : Decodable {
    let data: [Player]
}


// Error object
enum FantasyHelperError: Error {
    case invalidURL
    case invalidResponse
    case invalidData
}

// Received Comparison data from api
struct ComparisonData: Decodable {
    let data: Comparison
}

// Comparison object
struct Comparison: Codable, Identifiable {
    let id: String
    let model: String
    let object: String
    let created: Int64
    let usage: ComparisonUsage
    let choices: [ComparisonChoices]
}

// Comparison usage object
struct ComparisonUsage: Codable {
    let completionTokens: Int
    let promptTokens: Int
    let totalTokens: Int
}

// Comparison choices object
struct ComparisonChoices: Codable {
    let finishReason: String
    let index: Int
    let message: ComparisonMessage
}

// Comparison message object
struct ComparisonMessage: Codable {
    let content: String
    let role: String
}
