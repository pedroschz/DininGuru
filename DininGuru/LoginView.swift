//
//  LoginView.swift
//  DininGuru
//
//  Created by Pedro Sánchez-Gil Galindo on 11/28/24.
//

import SwiftUI


class AppState: ObservableObject {
   @Published var isLoggedIn: Bool = false
   @Published var isLoggedOut: Bool = false
   
   init() {
      if let _ = UserDefaults.standard.value(forKey: "userId") as? Int {
         isLoggedIn = true
      }
   }
}


struct LoginView: View {
   @State private var username: String = ""
   @State private var code: String = ""
   @State private var isLoading: Bool = false
   @State private var errorMessage: String?
   @State private var isVerificationSent: Bool = false
   @AppStorage("userId") var userId: Int?
   @AppStorage("userEmail") var userEmail: String?
   @EnvironmentObject var appState: AppState
   
   var body: some View {
      VStack(spacing: 20) {
         Text("Welcome to DiningGuru")
            .font(.largeTitle)
            .padding(.top, 40)
         
         if !isVerificationSent {
            TextField("Enter your email", text: $username)
               .textFieldStyle(RoundedBorderTextFieldStyle())
               .padding(.horizontal)
               .disableAutocorrection(true)
               .autocapitalization(.none)
         } else {
            Text("A verification code has been sent to your email.")
               .padding(.horizontal)
            
            TextField("Enter verification code", text: $code)
               .textFieldStyle(RoundedBorderTextFieldStyle())
               .padding(.horizontal)
               .keyboardType(.numberPad)
         }
         
         if let errorMessage = errorMessage {
            Text(errorMessage)
               .foregroundColor(.red)
               .padding(.horizontal)
         }
         
         Button(action: {
            if isVerificationSent {
               verifyCode()
            } else {
               sendVerificationCode()
            }
         }) {
            if isLoading {
               ProgressView()
            } else {
               Text(isVerificationSent ? "Verify Code" : "Send Verification Code")
                  .foregroundColor(.white)
                  .padding()
                  .frame(maxWidth: .infinity)
                  .background(Color.blue)
                  .cornerRadius(8)
            }
         }
         .disabled((isVerificationSent ? code : username).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
         .padding(.horizontal)
         
         Spacer()
      }
      .onAppear {
         // Reset state when the view appears
         if appState.isLoggedOut {
            resetLoginState()
            appState.isLoggedOut = false
         }
      }
   }
   
   private func resetLoginState() {
      username = ""
      code = ""
      isVerificationSent = false
      errorMessage = nil
   }
   
   private func sendVerificationCode() {
      let trimmedEmail = username.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedEmail.isEmpty else {
         self.errorMessage = "Please enter a valid email."
         return
      }
      
      isLoading = true
      errorMessage = nil
      
      guard let url = URL(string: "http://127.0.0.1:8000/api/accounts/login/") else {
         self.errorMessage = "Invalid server URL."
         self.isLoading = false
         return
      }
      
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      
      let body: [String: Any] = [
         "email": trimmedEmail
      ]
      
      do {
         let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
         request.httpBody = jsonData
      } catch {
         self.errorMessage = "Error creating request data."
         self.isLoading = false
         return
      }
      
      URLSession.shared.dataTask(with: request) { data, response, error in
         DispatchQueue.main.async {
            self.isLoading = false
         }
         
         if let error = error {
            DispatchQueue.main.async {
               self.errorMessage = "Network error: \(error.localizedDescription)"
            }
            return
         }
         
         guard let data = data else {
            DispatchQueue.main.async {
               self.errorMessage = "No data received from server."
            }
            return
         }
         
         do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let _ = json["message"] as? String {
               DispatchQueue.main.async {
                  self.isVerificationSent = true
                  self.userEmail = trimmedEmail
               }
            } else if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                      let errorMessage = json["error"] as? String {
               DispatchQueue.main.async {
                  self.errorMessage = errorMessage
               }
            } else {
               DispatchQueue.main.async {
                  self.errorMessage = "Unexpected server response."
               }
            }
         } catch {
            DispatchQueue.main.async {
               self.errorMessage = "Error parsing server response."
            }
         }
      }.resume()
   }
   
   private func verifyCode() {


      let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedCode.isEmpty else {
         self.errorMessage = "Please enter the verification code."
         return
      }
      
      guard let email = userEmail else {
         self.errorMessage = "Email not found."
         return
      }
      
      isLoading = true
      errorMessage = nil
      
      guard let url = URL(string: "http://127.0.0.1:8000/api/accounts/verify/") else {
         self.errorMessage = "Invalid server URL."
         self.isLoading = false
         return
      }
      
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      
      let body: [String: Any] = [
         "email": email,
         "code": trimmedCode
      ]
      
      do {
         let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
         request.httpBody = jsonData
      } catch {
         self.errorMessage = "Error creating request data."
         self.isLoading = false
         return
      }
      
      URLSession.shared.dataTask(with: request) { data, response, error in
         DispatchQueue.main.async {
            self.isLoading = false
         }
         
         DispatchQueue.main.async {
            appState.isLoggedIn = true
         }

         
         if let error = error {
            DispatchQueue.main.async {
               self.errorMessage = "Network error: \(error.localizedDescription)"
            }
            return
         }
         
         guard let data = data else {
            DispatchQueue.main.async {
               self.errorMessage = "No data received from server."
            }
            return
         }
         
         do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let userId = json["user_id"] as? Int {
               // Save userId to UserDefaults
               UserDefaults.standard.set(userId, forKey: "userId")
               DispatchQueue.main.async {
                  UserDefaults.standard.set(userId, forKey: "userId")
                  print("User ID \(userId) saved to UserDefaults")
                  appState.isLoggedIn = true
               }
            } else if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                      let errorMessage = json["error"] as? String {
               DispatchQueue.main.async {
                  self.errorMessage = errorMessage
               }
            } else {
               DispatchQueue.main.async {
                  self.errorMessage = "Unexpected server response."
               }
            }
         } catch {
            DispatchQueue.main.async {
               self.errorMessage = "Error parsing server response."
            }
         }
      }.resume()
   }
}
