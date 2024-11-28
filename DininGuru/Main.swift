//
//  Main.swift
//  DininGuru
//
//  Created by Pedro Sánchez-Gil Galindo on 11/18/24.
//

import SwiftUI
import WidgetKit

// MARK: - Index

// Main: the main view of the app, shows the list of dining locations

// displayedVenues: filters and sorts the five dining hall venues

// sortVenues: sorts venues alphabetically
// fetchDiningData: gets dining data from DiningService
// handleVenueSelection: manages what happens when a venue is selected (like network checks)
// saveVenuesToSharedDefaults: saves venues for widget use

// Preview: SwiftUI preview of Main view

struct Main: View {
   
   // State variables to keep track of app state, loading, and errors
   @State private var venues: [Venue] = [] // list of all venues
   @State private var isLoading = true // is data loading
   //@State private var selectedURL: URL? = nil // URL selected for web view
   //@State private var isWebViewLoading = false // is web view loading
   @State private var showAlert = false // show alert for errors
   @State private var alertMessage = "" // message for the alert
   @ObservedObject private var networkMonitor = NetworkMonitor() // monitors network status
   private let diningService = DiningService() // service to fetch dining data
   
   // Set of IDs representing the five dining halls
   let diningHallIDs: Set<Int> = [593, 636, 637, 1442, 1464004]
   
   // Mapping of venue IDs to their URLs
   let venueURLs: [Int: String] = [
      593: "https://university-of-pennsylvania.cafebonappetit.com/cafe/1920-commons/",
      636: "https://university-of-pennsylvania.cafebonappetit.com/cafe/hill-house/",
      637: "https://university-of-pennsylvania.cafebonappetit.com/cafe/kings-court-english-house/",
      1442: "https://university-of-pennsylvania.cafebonappetit.com/cafe/lauder-college-house/",
      1464004: "https://university-of-pennsylvania.cafebonappetit.com/cafe/quaker-kitchen/"
   ]
   
   var body: some View {
      NavigationView {
         VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
               Text("Ratings for \(todayDateString())") // today's date
                  .font(.headline)
                  .bold()
                  .foregroundColor(.gray)
               
               Text("Today's Ratings ⭐️")
                  .font(.largeTitle)
                  .fontWeight(.bold)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            List {
               ForEach(displayedVenues) { venue in
                  NavigationLink(destination: VenueDetailView(venue: venue, venueURL: venueURLs[venue.id])) {
                     ListElement(
                        venue: venue,
                        venueURL: venueURLs[venue.id]
                     )
                  }
               }
            }
            .listStyle(PlainListStyle())
            .alert(isPresented: $showAlert) {
               Alert(title: Text("Network Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
         }
         .onAppear {
            fetchDiningData()
         }
      }
   }
   
   // Computed property to get all displayed venues
   private var displayedVenues: [Venue] {
      let halls = venues.filter { diningHallIDs.contains($0.id) }
      return sortVenues(halls)
   }
   
   // Sorts venues alphabetically
   private func sortVenues(_ venues: [Venue]) -> [Venue] {
      venues.sorted { lhs, rhs in
         lhs.name < rhs.name // sorts alphabetically
      }
   }
   
   // Function to fetch dining data
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
   
   // Save venues to shared defaults for widget usage
   private func saveVenuesToSharedDefaults() {
      if let data = try? JSONEncoder().encode(venues) {
         let sharedDefaults = UserDefaults(suiteName: "group.com.petrvskystudios.DiningApp")
         sharedDefaults?.set(data, forKey: "SharedVenues")
         
         // Notify the widget to reload its timeline
         WidgetCenter.shared.reloadTimelines(ofKind: "DiningAppWidget")
      } else {
         print("Failed to encode venues.")
         // TODO: notify the user or retry encoding
      }
   }
}

// For sheet presentation


#Preview {
   Main()
}
