//
//  LoginView.swift
//  DininGuru
//
//  Created by Pedro Sánchez-Gil Galindo on 11/28/24.
//

import SwiftUI

struct LoginView: View {
   @State private var username: String = ""
   @State private var isLoading: Bool = false
   @State private var errorMessage: String?
   
   var body: some View {
      VStack(spacing: 20) {
         Text("Welcome to DiningGuru")
            .font(.largeTitle)
            .padding(.top, 40)
         
         TextField("Enter your username", text: $username)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.horizontal)
            .disableAutocorrection(true)
            .autocapitalization(.none)
         
         if let errorMessage = errorMessage {
            Text(errorMessage)
               .foregroundColor(.red)
               .padding(.horizontal)
         }
         
         Button(action: loginOrSignup) {
            if isLoading {
               ProgressView()
            } else {
               Text("Signup/Login")
                  .foregroundColor(.white)
                  .padding()
                  .frame(maxWidth: .infinity)
                  .background(Color.blue)
                  .cornerRadius(8)
            }
         }
         .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
         .padding(.horizontal)
         
         Spacer()
      }
   }
   
   private func loginOrSignup() {
      // Implement login/signup logic here
   }
}
