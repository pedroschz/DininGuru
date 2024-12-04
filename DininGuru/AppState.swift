//
//  AppState.swift
//  DininGuru
//
//  Created by Pedro Sánchez-Gil Galindo on 12/3/24.
//

import Foundation
import Combine
import SwiftUI

class AppState: ObservableObject {
   @Published var isLoggedIn: Bool = false
   @Published var isLoggedOut: Bool = false
   @Published var isGuest: Bool = false
   @Published var guestLoginDate: Date?
   
   @AppStorage("userId") var userId: Int?
   @AppStorage("userEmail") var userEmail: String?
   @AppStorage("isGuest") var isGuestStorage: Bool = false
   @AppStorage("guestLoginDateTimestamp") var guestLoginDateTimestamp: Double?
   
   init() {
      // Initialize isLoggedIn based on userId
      if let _ = UserDefaults.standard.value(forKey: "userId") as? Int {
         isLoggedIn = true
      }
      // Initialize isGuest and guestLoginDate
      isGuest = isGuestStorage
      if let timestamp = guestLoginDateTimestamp {
         guestLoginDate = Date(timeIntervalSince1970: timestamp)
      }
   }
   
   func loginAsGuest() {
      isGuest = true
      guestLoginDate = Date()
      isGuestStorage = true
      guestLoginDateTimestamp = guestLoginDate?.timeIntervalSince1970
      userId = nil // Ensure no user ID is associated
      userEmail = nil // Clear any existing email
      isLoggedIn = true
   }
   
   func logout() {
      userId = nil
      userEmail = nil
      isGuest = false
      guestLoginDate = nil
      isGuestStorage = false
      guestLoginDateTimestamp = nil
      isLoggedIn = false
      isLoggedOut = true
   }
}
