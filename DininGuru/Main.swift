//
//  Main.swift
//  DininGuru
//
//  Created by Pedro Sánchez-Gil Galindo on 11/18/24.
//

import SwiftUI
import WidgetKit
import Combine


// MARK: - Index

// Main: the main view of the app, shows the list of dining locations

// displayedVenues: filters and sorts the five dining hall venues

// fetchDiningData: gets dining data from DiningService
// handleVenueSelection: manages what happens when a venue is selected (like network checks)
// saveVenuesToSharedDefaults: saves venues for widget use

// Preview: SwiftUI preview of Main view

struct Main: View {
   
   // State variables
   @State private var venues: [Venue] = []
   @State private var isLoading = true
   @State private var showAlert = false
   @State private var alertMessage = ""
   @ObservedObject private var networkMonitor = NetworkMonitor()
   private let diningService = DiningService()
   
   @AppStorage("userId") var userId: Int?
   @AppStorage("userEmail") var userEmail: String?
   @EnvironmentObject var appState: AppState
   @State private var reviewCount: [Int: Int] = [:]
   
   private var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
      Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
   }
   
   let diningHallIDs: Set<Int> = [593, 636, 637, 1442, 1464004]
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
               
               if let userEmail = userEmail {
                     let truncatedEmail = userEmail.components(separatedBy: "@").first ?? userEmail
                     Text("Hello, \(truncatedEmail)!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                     
                  }
               
            
               Text("Today's ratings ⭐️")
                  .font(.largeTitle)
                  .fontWeight(.bold)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            List {
               ForEach(displayedVenues) { venue in
                  NavigationLink(destination: VenueDetailView(venue: venue, venueURL: venueURLs[venue.id], reviewCount: self.reviewCount[venue.id])) {
                     ListElement(
                        venue: venue,
                        venueURL: venueURLs[venue.id],
                        reviewCount: self.reviewCount[venue.id]
                     )
                  }.padding(.vertical, 3)
               }
            }
            .refreshable {
               fetchDiningData()
            }
            .listStyle(PlainListStyle())
            .alert(isPresented: $showAlert) {
               Alert(title: Text("Network Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            
            Spacer()
            
            VStack (spacing: 10){
               Button(action: logout) {
                  Text("logout")
                     .foregroundColor(.blue)
                     .opacity(0.7)
               }
               Button(action: sendEmail) {
                  Text("feedback")
                     .foregroundColor(.gray)
                     .underline()
               }
               Button(action: openInstagram) {
                  Text("by pedro")
                     .foregroundColor(.gray)
               }
            }

         }
         .onAppear {
            fetchDiningData()
         }
         .onReceive(timer) { _ in
            fetchDiningData()
         }
      }
   }
   
   
   
   private var displayedVenues: [Venue] {
      let halls = venues.filter { diningHallIDs.contains($0.id) }
      return sortVenues(halls)
   }
   
   private func sendEmail() {
      if let url = URL(string: "mailto:pedrosan@seas.upenn.edu?subject=DininGuru%20ideas") {
         UIApplication.shared.open(url)
      }
   }
   
   private func openInstagram() {
      if let url = URL(string: "https://instagram.com/pedroschzgil/") {
         UIApplication.shared.open(url)
      }
   }
   
   private func sortVenues(_ venues: [Venue]) -> [Venue] {
      venues.sorted { lhs, rhs in
         if lhs.isOpen && !rhs.isOpen {
            return true
         }
         if !lhs.isOpen && rhs.isOpen {
            return false
         }
         return (lhs.averageRating ?? 0) > (rhs.averageRating ?? 0)
      }
   }
   
   private func fetchDiningData() {
      diningService.fetchDiningData { result in
         switch result {
         case .success(var fetchedVenues):
            let group = DispatchGroup()
            
            for index in fetchedVenues.indices {
               let venue = fetchedVenues[index]
               group.enter()
               RatingService.shared.fetchAverageRating(venueId: String(venue.id)) { avg, count in
                  fetchedVenues[index].averageRating = avg
                  self.reviewCount[venue.id] = count
                  group.leave()
               }
            }
            
            group.notify(queue: .main) {
               self.venues = sortVenues(fetchedVenues)
               self.isLoading = false
               self.saveVenuesToSharedDefaults()
            }
            
         case .failure(let error):
            print("Failed to load data: \(error.localizedDescription)")
            self.isLoading = false
            self.showAlert = true
            self.alertMessage = "Failed to load venues."
         }
      }
   }
   
   private func logout() {
      userId = nil
      userEmail = nil
      appState.isLoggedIn = false
      appState.isLoggedOut = true
   }
   
   private func saveVenuesToSharedDefaults() {
      if let data = try? JSONEncoder().encode(venues) {
         let sharedDefaults = UserDefaults(suiteName: "group.com.petrvskystudios.DiningApp")
         sharedDefaults?.set(data, forKey: "SharedVenues")
         WidgetCenter.shared.reloadTimelines(ofKind: "DiningAppWidget")
      } else {
         print("Failed to encode venues.")
      }
   }
}




// For sheet presentation


#Preview {
   Main()
}
