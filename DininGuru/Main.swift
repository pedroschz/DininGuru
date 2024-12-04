//
//  Main.swift
//  DininGuru
//
//  Created by Pedro Sánchez-Gil Galindo on 11/18/24.
//

import SwiftUI
import WidgetKit
import Combine

struct Main: View {
   
   // State variables
   @State private var venues: [Venue] = []
   @State private var isLoading = true
   @State private var showAlert = false
   @State private var alertMessage = ""
   @ObservedObject private var networkMonitor = NetworkMonitor()
   private let diningService = DiningService()
   
   @State private var userId: Int? = UserDefaults.standard.integer(forKey: "userId")
   @State private var userEmail: String? = UserDefaults.standard.string(forKey: "userEmail")
   
   @State private var isGuest: Bool = UserDefaults.standard.bool(forKey: "isGuest")
   @State private var guestLoginDate: Date? = UserDefaults.standard.object(forKey: "guestLoginDate") as? Date
   
   @EnvironmentObject var appState: AppState
   @State private var reviewCount: [Int: Int] = [:]
   
   // State variables for handling closed venues
   @State private var selectedClosedVenue: Venue? = nil
   @State private var navigateToMenu: Bool = false
   
   // State variables for delete account confirmation
   @State private var showDeleteAccountAlert: Bool = false
   
   @State private var selectedURL: URL? = nil
   @State private var isWebViewLoading = false
   
   @State private var showGuestLoginAlert: Bool = false
   
   
   @State private var activeAlert: ActiveAlert? = nil

   
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
         if isLoading {
            Spacer()
            ProgressView("Loading...")
               .scaleEffect(1.5)
               .padding()
            Spacer()
         } else {
            VStack(spacing: 0) {
               
               // Header Section with Greeting and Options Menu
               HStack {
                  VStack(alignment: .leading, spacing: 4) {
                     Text("Ratings for \(todayDateString())") // today's date
                        .font(.headline)
                        .bold()
                        .foregroundColor(.gray)
                     
                     if let userEmail = userEmail {
                        let truncatedEmail = userEmail.components(separatedBy: "@").first ?? userEmail
                        HStack {
                           Text("Hello, \(truncatedEmail)!")
                              .font(.largeTitle)
                              .fontWeight(.bold)
                           
                           Spacer()
                           
                           // Options Menu for Logout and Delete Account
                           Menu {
                              Button(action: {
                                 logout()
                              }) {
                                 Label("Log Out", systemImage: "arrow.backward.circle")
                                    .foregroundColor(.blue)
                              }
                              
                              Button(role: .destructive, action: {
                                 activeAlert = .deleteAccountConfirmation
                              }) {
                                 Label("Delete Account", systemImage: "trash")
                                    .foregroundColor(.red)
                              }
                           } label: {
                              Image(systemName: "person.crop.circle")
                                 .resizable()
                                 .frame(width: 35, height: 35)
                                 .foregroundColor(.blue)
                                 .padding(.horizontal, 10)
                           }
                           .accessibilityLabel("Account Options")
                        }
                     }
                     else {
                        // Show "Login" button when not logged in
                        HStack {
                           Button(action: {
                              appState.isLoggedIn = false // Navigate to login
                           }) {
                              Text("Login")
                                 .foregroundColor(.blue)
                           }
                           .padding(.trailing, 10)
                        }
                        .padding(.horizontal, 10)
                     }
                     
                     Text("Today's ratings ⭐️")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                  }
                  .padding(.horizontal, 16)
                  .padding(.top, 16)
                  .padding(.bottom, 8)
                  .frame(maxWidth: .infinity, alignment: .leading)
               }
               
               // List of Venues
               List {
                  ForEach(displayedVenues) { venue in
                     if venue.isOpen {
                        // Venue is open: display as usual with NavigationLink
                        NavigationLink(destination: VenueDetailView(venue: venue, venueURL: venueURLs[venue.id], reviewCount: self.reviewCount[venue.id], isGuest: $isGuest).environmentObject(appState)) {
                           ListElement(
                              venue: venue,
                              venueURL: venueURLs[venue.id],
                              reviewCount: self.reviewCount[venue.id]
                           )
                        }
                        .padding(.vertical, 3)
                     } else {
                        // Venue is closed: display as a Button to show alert
                        Button(action: {
                           activeAlert = .closedVenue(venue)
                        }) {
                           ListElement(
                              venue: venue,
                              venueURL: venueURLs[venue.id],
                              reviewCount: self.reviewCount[venue.id]
                           )
                        }
                        .padding(.vertical, 3)
                        .buttonStyle(PlainButtonStyle())

                        
                     }
                  }
               }
               
               .alert(item: $activeAlert) { alert in
                  switch alert {
                  case .closedVenue(let venue):
                     return Alert(
                        title: Text("Venue is closed :("),
                        message: Text(""),
                        primaryButton: .default(Text("Got it"), action: {
                           activeAlert = nil
                        }),
                        secondaryButton: .default(Text("See menu")) {
                           if let urlString = venueURLs[venue.id], let url = URL(string: urlString) {
                              selectedURL = url
                           } else {
                              activeAlert = .authenticationRequired("Invalid URL for this venue.")
                           }
                        }
                     )
                  case .guestLogin(let message):
                     return Alert(
                        title: Text("Authentication Required"),
                        message: Text(message),
                        primaryButton: .default(Text("Cancel"), action: {
                           isGuest = false
                           guestLoginDate = nil
                           appState.isLoggedIn = false
                           activeAlert = nil
                        }),
                        secondaryButton: .default(Text("Login"), action: {
                           appState.isLoggedIn = false
                           activeAlert = nil
                        })
                     )
                  case .authenticationRequired(let message):
                     return Alert(
                        title: Text("Authentication Required"),
                        message: Text(message),
                        primaryButton: .cancel(Text("Cancel"), action: {
                           activeAlert = nil
                        }),
                        secondaryButton: .default(Text("Login"), action: {
                           appState.isLoggedIn = false
                           activeAlert = nil
                        })
                     )
                  case .deleteAccountConfirmation:
                     return Alert(
                        title: Text("Delete Account"),
                        message: Text("All your past data, interactions, and account information will be deleted. Are you sure?"),
                        primaryButton: .cancel({
                           activeAlert = nil
                        }),
                        secondaryButton: .destructive(Text("Delete")) {
                           handleDeleteAccount()
                           activeAlert = nil
                        }
                     )
                  }
               }

               
               
               .refreshable {
                  fetchDiningData()
               }
               .listStyle(PlainListStyle())

               
               .sheet(item: $selectedURL) { url in
                  WebView(url: url, isLoading: $isWebViewLoading)
                     .overlay(Group {
                        if isWebViewLoading {
                           ProgressView()
                              .progressViewStyle(CircularProgressViewStyle())
                              .scaleEffect(2)
                        }
                     })
                     .edgesIgnoringSafeArea(.all)
               }
               
               Spacer()
               
               // Footer Section
               VStack(spacing: 5){
                  Button(action: sendEmail) {
                     Text("Feedback")
                        .foregroundColor(.gray)
                        .underline()
                  }
                  Button(action: openInstagram) {
                     Text("by Pedro")
                        .foregroundColor(.gray)
                  }
               }
               .padding(.bottom, 20)
            }
         }
         
      }
      .onAppear {
         if isGuest {
            if let guestDate = guestLoginDate, Date().timeIntervalSince(guestDate) > 24 * 3600 {
               activeAlert = .guestLogin("Log in to continue seeing and rate venues")
            }
         }

         fetchDiningData()
         
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
         if lhs.isOpen != rhs.isOpen {
            return lhs.isOpen
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
            self.alertMessage = "Failed to load venues."
         }
      }
   }
   
   private func logout() {
      userId = nil
      userEmail = nil
      isGuest = false
      guestLoginDate = nil
      appState.isLoggedIn = false
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
   
   // Handle Delete Account Action
   private func handleDeleteAccount() {
      guard let email = userEmail else {
         // If userEmail is not available, proceed to logout
         logout()
         return
      }
      
      if email.lowercased() == "slpnoviembre@gmail.com" {
         // Only log out
         logout()
      } else {
         // Log out and delete account
         if let userId = userId {
            deleteAccount(userId: userId) { success in
               DispatchQueue.main.async {
                  if success {
                     logout()
                  } else {
                     alertMessage = "Failed to delete account. Please try again later."
                  }
               }
            }
         } else {
            // If userId is not available, just log out
            logout()
         }
      }
   }
   
   // Function to Delete Account from Backend
   private func deleteAccount(userId: Int, completion: @escaping (Bool) -> Void) {
      guard let url = URL(string: "https://dininguru.onrender.com/api/deleteAccount") else {
         print("Invalid URL for deleteAccount")
         completion(false)
         return
      }
      
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      
      let body: [String: Any] = [
         "userId": userId
      ]
      
      do {
         request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
      } catch {
         print("Error serializing JSON: \(error)")
         completion(false)
         return
      }
      
      URLSession.shared.dataTask(with: request) { data, response, error in
         if let error = error {
            print("Error deleting account: \(error.localizedDescription)")
            completion(false)
            return
         }
         
         guard let httpResponse = response as? HTTPURLResponse else {
            print("Invalid response")
            completion(false)
            return
         }
         completion(httpResponse.statusCode == 200)
      }.resume()
   }
}


enum ActiveAlert: Identifiable {
   case closedVenue(Venue)
   case guestLogin(String)
   case authenticationRequired(String)
   case deleteAccountConfirmation
   
   var id: String {
      switch self {
      case .closedVenue(let venue):
         return "closedVenue-\(venue.id)"
      case .guestLogin:
         return "guestLogin"
      case .authenticationRequired:
         return "authenticationRequired"
      case .deleteAccountConfirmation:
         return "deleteAccountConfirmation"
      }
   }
}

// For sheet presentation

#Preview {
   Main()
}
