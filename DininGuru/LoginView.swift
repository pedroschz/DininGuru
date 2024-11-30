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
      ZStack {
         LinearGradient(
            gradient: Gradient(colors: [Color.orange.opacity(0.6), Color.red.opacity(0.9)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
         )
         .ignoresSafeArea()
         
         VStack(spacing: 20) {
            Spacer()
            
            // Header
            VStack(spacing: 10) {
               Text("Welcome to")
                  .font(.headline)
                  .foregroundColor(.white.opacity(0.8))
               
               Text("DiningGuru")
                  .font(.largeTitle.bold())
                  .foregroundColor(.white)
            }
            
            Spacer()
            
            Text("Login or Signup")
               .font(.headline)
               .foregroundColor(.white.opacity(0.8))
            
            // Input Fields
            VStack(spacing: 15) {
               if !isVerificationSent {
                  CustomTextField(placeholder: "Enter your email", text: $username, icon: "envelope")
               } else {
                  Text("Check your inbox! we sent your code to \(userEmail ?? ""). check spam folder :)")
                     .font(.subheadline)
                     .foregroundColor(.white.opacity(0.9))
                     .multilineTextAlignment(.center)
                     .padding(.horizontal)
                  
                  CustomTextField(placeholder: "Enter verification code", text: $code, icon: "lock")
               }
            }
            .padding(.horizontal)
            
            // Error Message
            if let errorMessage = errorMessage {
               Text(errorMessage)
                  .foregroundColor(.red)
                  .padding(.horizontal)
                  .transition(.opacity)
            }
            
            // Action Button
            Button(action: {
               if isVerificationSent {
                  verifyCode()
               } else {
                  sendVerificationCode()
               }
            }) {
               Text(isVerificationSent ? "Verify Code" : "Send Verification Code")
                  .fontWeight(.bold)
                  .frame(maxWidth: .infinity)
                  .padding()
                  .background(
                     ZStack {
                        // Background blur effect
                        VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                           .clipShape(RoundedRectangle(cornerRadius: 20))
                        
                     }
                  )
                  .foregroundColor(.white)
                  .cornerRadius(20)
                  .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
            .disabled((isVerificationSent ? code : username).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            .padding(.horizontal)
            .animation(.easeInOut(duration: 0.2), value: isLoading)
            
            Spacer()

            
            Text("- Real-time dining hall ratings by meal")
               .font(.headline)
               .foregroundColor(.white.opacity(1))
            Text("- Comments on today's menu")
               .font(.headline)
               .foregroundColor(.white.opacity(1))
            Text("- Quick access to menu and dining hours")
               .font(.headline)
               .foregroundColor(.white.opacity(1))

            
            Spacer()
            Spacer()

         }
         .padding()
      }
      .onAppear {
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
      
      if trimmedEmail == "slpnoviembre@gmail.com" {
         // Directly set user data and log in
         UserDefaults.standard.set(13, forKey: "userId") // Assign a dummy userId
         UserDefaults.standard.set("slpnoviembre@gmail.com", forKey: "userEmail")
         DispatchQueue.main.async {
            appState.isLoggedIn = true
         }
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
      
      // Admin testing email bypass
      if userEmail == "slpnoviembre@gmail.com" {
         DispatchQueue.main.async {
            UserDefaults.standard.set(13, forKey: "userId") // Dummy userId
            UserDefaults.standard.set("slpnoviembre@gmail.com", forKey: "userEmail") // Admin's email
            appState.isLoggedIn = true
         }
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

struct VisualEffectBlur: UIViewRepresentable {
   var blurStyle: UIBlurEffect.Style
   
   func makeUIView(context: Context) -> UIVisualEffectView {
      return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
   }
   
   func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct CustomTextField: View {
   let placeholder: String
   @Binding var text: String
   let icon: String
   
   var body: some View {
      HStack {
         Image(systemName: icon)
            .foregroundColor(.white.opacity(0.8))
         
         ZStack(alignment: .leading) {
            if text.isEmpty {
               Text(placeholder)
                  .foregroundColor(.white.opacity(0.6)) // White placeholder
            }
            TextField("", text: $text)
               .foregroundColor(.white) // Ensure the typed text is white
               .autocapitalization(.none)
               .disableAutocorrection(true)
         }
      }
      .padding()
      .background(Color.white.opacity(0.2))
      .cornerRadius(20)
      .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
   }
}


#Preview {
   let appState = AppState() // Create an instance of AppState
   LoginView()
      .environmentObject(appState)
}
