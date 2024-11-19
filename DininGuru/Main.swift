//
//  ContentView.swift
//  DininGuru
//
//  Created by Pedro Sánchez-Gil Galindo on 11/18/24.
//


import SwiftUI
import WidgetKit

// MARK: - Index

// Main: the main view of the app, shows the list of dining locations (halls and retail)

// diningHalls: filters and sorts dining hall venues
// diningRetail: filters and sorts dining retail venues

// sortVenues: sorts venues with favorites first, then alphabetically
// fetchDiningData: gets dining data from DiningService
// handleVenueSelection: manages what happens when a venue is selected (like network checks)
// loadFavorites: loads user's favorite venues from UserDefaults
// saveFavorites: saves user's favorite venues to UserDefaults
// toggleFavorite: adds/removes a venue from favorites and updates UserDefaults
// saveVenuesToSharedDefaults: saves venues for widget use

// Preview: SwiftUI preview of Main view

struct Main: View {
   
   // state variables to keep track of app state, loading, and errors
   @State private var venues: [Venue] = [] // list of all venues
   @State private var isLoading = true //is data loading
   @State private var selectedURL: URL? = nil // URL selected for web view
   @State private var isWebViewLoading = false // is web view loading
   @State private var showAlert = false // show alert for errors
   @State private var alertMessage = "" // message for the alert
   @ObservedObject private var networkMonitor = NetworkMonitor() // monitors network status
   private let diningService = DiningService() // service to fetch dining data
   @State private var favoriteVenueIDs: [Int] = [] // list of favorite venue IDs
   
   // set of IDs representing dining halls
   let diningHallIDs: Set<Int> = [593, 636, 637, 638, 1442, 1464004]
   
   // mapping of venue IDs to their URLs
   let venueURLs: [Int: String] = [
      593: "https://university-of-pennsylvania.cafebonappetit.com/cafe/1920-commons/",
      636: "https://university-of-pennsylvania.cafebonappetit.com/cafe/hill-house/",
      637: "https://university-of-pennsylvania.cafebonappetit.com/cafe/kings-court-english-house/",
      638: "https://university-of-pennsylvania.cafebonappetit.com/cafe/falk-dining-commons/",
      1442: "https://university-of-pennsylvania.cafebonappetit.com/cafe/lauder-college-house/",
      1464004: "https://university-of-pennsylvania.cafebonappetit.com/cafe/quaker-kitchen/",
      639: "https://university-of-pennsylvania.cafebonappetit.com/cafe/houston-market/",
      641: "https://university-of-pennsylvania.cafebonappetit.com/cafe/accenture-cafe/",
      642: "https://university-of-pennsylvania.cafebonappetit.com/cafe/joes-cafe/",
      747: "https://university-of-pennsylvania.cafebonappetit.com/cafe/mcclelland/",
      1057: "https://university-of-pennsylvania.cafebonappetit.com/cafe/1920-gourmet-grocer/",
      1163: "https://university-of-pennsylvania.cafebonappetit.com/cafe/1920-starbucks/",
      1732: "https://university-of-pennsylvania.cafebonappetit.com/cafe/pret-a-manger-upper/",
      1733: "https://university-of-pennsylvania.cafebonappetit.com/cafe/pret-a-manger-lower/",
      1464009: "https://university-of-pennsylvania.cafebonappetit.com/cafe/cafe-west/"
   ]
   
   var body: some View {
      NavigationView {
         VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
               Text(todayDateString()) //today's date
                  .font(.headline)
                  .bold()
                  .foregroundColor(.gray)
               
               Text("Dining Locations")
                  .font(.largeTitle)
                  .fontWeight(.bold)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            List {
               if !diningHalls.isEmpty { //check if there are dining halls so in the remote case there aren't any, it doesn't look weird.
                  Section(header: Text("Dining Halls")
                     .font(.title)
                     .fontWeight(.semibold)) {
                        ForEach(diningHalls) { venue in
                           ListElement(
                              venue: venue,
                              venueURL: venueURLs[venue.id],
                              isFavorite: favoriteVenueIDs.contains(venue.id),
                              onSelect: { url in
                                 handleVenueSelection(url: url) // handle selection
                              },
                              onFavoriteToggle: { venueID in
                                 toggleFavorite(venueID) // toggle favorite venues
                              }
                           )
                        }
                     }
               }
               
               if !diningRetail.isEmpty { // check if there are retail options (same reason as above)
                  Section(header: Text("Dining Retail")
                     .font(.title)
                     .fontWeight(.semibold)) {
                        ForEach(diningRetail) { venue in
                           ListElement(
                              venue: venue,
                              venueURL: venueURLs[venue.id],
                              isFavorite: favoriteVenueIDs.contains(venue.id),
                              onSelect: { url in
                                 handleVenueSelection(url: url)
                              },
                              onFavoriteToggle: { venueID in
                                 toggleFavorite(venueID)
                              }
                           )
                        }
                     }
               }
            }
            .listStyle(PlainListStyle())
            .alert(isPresented: $showAlert) {
               Alert(title: Text("Network Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
         }
         .onAppear {
            loadFavorites()
            fetchDiningData()
         }
         .sheet(item: $selectedURL) { url in
            ZStack {
               WebView(url: url, isLoading: $isWebViewLoading) //shows web view
               if isWebViewLoading {
                  ProgressView()
                     .progressViewStyle(CircularProgressViewStyle())
                     .scaleEffect(2)
               }
            }
            .edgesIgnoringSafeArea(.all)
         }
      }
   }
   
   // computed property to get all dining hall venues
   private var diningHalls: [Venue] {
      let halls = venues.filter { diningHallIDs.contains($0.id) }
      return sortVenues(halls)
   }
   
   // same for retail venues
   private var diningRetail: [Venue] {
      let retail = venues.filter { !diningHallIDs.contains($0.id) }
      return sortVenues(retail)
   }
   
   // sorts venues
   private func sortVenues(_ venues: [Venue]) -> [Venue] {
      venues.sorted { lhs, rhs in
         let lhsIsFavorite = favoriteVenueIDs.contains(lhs.id)
         let rhsIsFavorite = favoriteVenueIDs.contains(rhs.id)
         if lhsIsFavorite == rhsIsFavorite {
            return lhs.name < rhs.name // sorts alphabetically if both are same in favorite
         }
         return lhsIsFavorite // favorites come first
      }
   }
   
   // function to fetch dining data
   private func fetchDiningData() {
      diningService.fetchDiningData { result in
         switch result {
         case .success(let venues):
            self.venues = venues
            self.isLoading = false
            self.saveVenuesToSharedDefaults() // save venues after fetching
         case .failure(let error):
            print("Failed to load data: \(error.localizedDescription)")
            self.isLoading = false
            // TODO: Maybe show a more user-friendly error message here but for now it works
         }
      }
   }
   
   // handle what happens when a venue is selected
   private func handleVenueSelection(url: URL) {
      if networkMonitor.isConnected {
         selectedURL = url
      } else {
         alertMessage = "No network connection found"
         showAlert = true
         // MARK: - maybe adding a retry option here could be better but idk
      }
   }
   
   // load user's favorite venues from UserDefaults
   private func loadFavorites() {
      if let savedFavorites = UserDefaults.standard.array(forKey: "FavoriteVenues") as? [Int] {
         favoriteVenueIDs = savedFavorites
      }
      // TODO: In case there are no saved favorites
   }
   
   // save user's favorite venues to UserDefaults
   private func saveFavorites() {
      UserDefaults.standard.set(favoriteVenueIDs, forKey: "FavoriteVenues")
      // TODO: Maybe add error handling for save failures
   }
   
   // toggle a venue's favorite status
   private func toggleFavorite(_ venueID: Int) {
      if favoriteVenueIDs.contains(venueID) {
         favoriteVenueIDs.removeAll { $0 == venueID }
      } else {
         favoriteVenueIDs.append(venueID)
      }
      saveFavorites()
      // MARK: - add haptic feedback when toggling favorites
   }
   
   // save venues to shared defaults for widget usage
   private func saveVenuesToSharedDefaults() {
      if let data = try? JSONEncoder().encode(venues) {
         let sharedDefaults = UserDefaults(suiteName: "group.com.petrvskystudios.DiningApp")
         sharedDefaults?.set(data, forKey: "SharedVenues")
         
         // notify the widget to reload its timeline
         WidgetCenter.shared.reloadTimelines(ofKind: "DiningAppWidget")
      } else {
         print("Failed to encode venues.")
         // TODO: notify the user or retry encoding
      }
   }
}

// for sheet presentation
extension URL: @retroactive Identifiable {
   public var id: String { absoluteString }
}

#Preview {
   Main()
}
