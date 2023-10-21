//
//  ContentView.swift
//  fantasy-helper-app
//
//  Created by Jorden Gerovac on 2023-10-20.
//

import SwiftUI

struct ContentView: View {
    @State private var players: [Player] = []
    @State private var firstSelection: String = ""
    @State private var secondSelection: String = ""
    @State private var firstSearchTerm: String = ""
    @State private var secondSearchTerm: String = ""
    @State private var comparisonMessage: String = ""

    var body: some View {
        VStack {
            Text("Pick two players to compare for your fantasy team")
            NavigationStack {
                Picker(selection: $firstSelection, label: Text("Select first player")) {
                    Text("Select first player").tag(Optional<String>(nil))
                    ForEach(searchResults(searchTerm: firstSearchTerm), id: \.id) { player in
                        Text(player.name)
                    }
                }
            }
            .searchable(text: $firstSearchTerm)
            NavigationStack {
                Picker(selection: $secondSelection, label: Text("Select second player")) {
                    Text("Select second player").tag(Optional<String>(nil))
                    ForEach(searchResults(searchTerm: secondSearchTerm), id: \.id) { player in
                        Text(player.name)
                    }
                }
            }
            .searchable(text: $secondSearchTerm)
            Button(action: comparePlayers) {
                Text("Compare players")
            }
        }
        .padding()
        .task {
            do {
                players = try await getPlayers()
            } catch FantasyHelperError.invalidURL {
                print("Invalid URL")
            } catch FantasyHelperError.invalidResponse {
                print("Invalid response")
            } catch FantasyHelperError.invalidData {
                print("Invalid data")
            } catch {
                print("Unexpected error")
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
    
    func comparePlayers() -> Void {
        comparisonMessage = "Comparing " + firstSelection + " and " + secondSelection
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
    var data : [Player]
}


// Error object
enum FantasyHelperError: Error {
    case invalidURL
    case invalidResponse
    case invalidData
}
