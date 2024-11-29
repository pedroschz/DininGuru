//
//  DininGuruApp.swift
//  DininGuru
//
//  Created by Pedro Sánchez-Gil Galindo on 11/18/24.
//

import SwiftUI

@main
struct DininGuruApp: App {
   @StateObject var appState = AppState()
   
   var body: some Scene {
      WindowGroup {
         if appState.isLoggedIn {
            Main()
               .environmentObject(appState)
         } else {
            LoginView()
               .environmentObject(appState)
         }
      }
   }
}



