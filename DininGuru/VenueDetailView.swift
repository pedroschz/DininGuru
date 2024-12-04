//
//  VenueDetailView.swift
//  DininGuru
//
//  Created by Pedro Sánchez-Gil Galindo on 11/23/24.
//

import SwiftUI
import WebKit
import Combine


class KeyboardResponder: ObservableObject {
   @Published var keyboardHeight: CGFloat = 0
   @Published var isKeyboardVisible: Bool = false
   private var cancellables = Set<AnyCancellable>()
   
   init() {
      let keyboardWillShow = NotificationCenter.default
         .publisher(for: UIResponder.keyboardWillShowNotification)
         .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
         .map { frame -> CGFloat in
            self.isKeyboardVisible = true
            return frame.height
         }
      
      let keyboardWillHide = NotificationCenter.default
         .publisher(for: UIResponder.keyboardWillHideNotification)
         .map { _ -> CGFloat in
            self.isKeyboardVisible = false
            return CGFloat.zero
         }
      
      Publishers.Merge(keyboardWillShow, keyboardWillHide)
         .receive(on: RunLoop.main)
         .assign(to: &$keyboardHeight)
   }
}


struct KeyboardAdaptive: ViewModifier {
   @ObservedObject private var keyboardResponder = KeyboardResponder()
   
   func body(content: Content) -> some View {
      content
         .padding(.bottom, keyboardResponder.keyboardHeight)
         .animation(.easeOut(duration: 0.2), value: keyboardResponder.keyboardHeight)
   }
}


extension UIApplication {
   func dismissKeyboard() {
      sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
   }
}


struct VenueDetailView: View {
   let venue: Venue
   let venueURL: String?
   
   @AppStorage("userId") var userId: Int?
   @AppStorage("userEmail") var userEmail: String?
   
   @State private var image: UIImage? = nil
   @State private var isLoadingImage = false
   @ObservedObject private var networkMonitor = NetworkMonitor()
   
   @State private var selectedRating: VenueRating? = nil
   @State private var averageRating: Double? = nil
   let reviewCount: Int? // 🆕 Added

   @State private var comments: [Comment] = []
   @State private var newCommentText: String = ""
   @State private var isSubmittingComment = false
   
   @State private var showAlert = false
   @State private var showSuccessMessage = false
   @State private var alertMessage = ""
   @State private var showErrorMessage = false
   @State private var selectedURL: URL? = nil
   @State private var isWebViewLoading = false
   
   
   @EnvironmentObject var appState: AppState

   
   @StateObject private var keyboardResponder = KeyboardResponder()
   @Binding var isGuest: Bool
   
   
   var body: some View {
      VStack {
         if !keyboardResponder.isKeyboardVisible {
            VenueImage(image: image)
         }
         VenueDetails(
            venue: venue,
            selectedRating: $selectedRating,
            submitUserRating: submitUserRating,
            averageRating: averageRating,
            handleVisitWebsite: handleVisitWebsite,
            reviewCount: reviewCount
         )
         .padding(.vertical, 10)
         Divider().padding(.horizontal)
         RatingView(
            selectedRating: $selectedRating,
            submitUserRating: submitUserRating,
            averageRating: averageRating,
            venue: venue
         )
         Divider().padding(.vertical, 8).padding(.horizontal)
         CommentsSection(
            comments: comments,
            newCommentText: $newCommentText,
            isSubmittingComment: isSubmittingComment,
            submitOrUpdateComment: submitOrUpdateComment,
            toggleLikeComment: toggleLikeComment,
            mealPeriod: getCurrentMealPeriod()
         )
      }
      .onAppear {
         print("VenueDetailView appeared. UserId is: \(String(describing: userId))")
         loadImage()
         fetchAverageRating()
         fetchComments(
            venueId: String(venue.id),
            mealPeriod: getCurrentMealPeriod(),
            userId: String(userId ?? 0)
         ) { fetchedComments in
            DispatchQueue.main.async {
               self.comments = fetchedComments
            }
         }
         RatingService.shared.fetchAverageRating(venueId: String(venue.id)) { avg, count in
            DispatchQueue.main.async {
               self.averageRating = avg
            }
         }
      }
      .alert(isPresented: $showSuccessMessage) {
         Alert(
            title: Text("Thank You!"),
            message: Text("Your rating has been submitted."),
            dismissButton: .default(Text("OK"))
         )
      }
      .alert(isPresented: $showErrorMessage) {
         Alert(
            title: Text("Error"),
            message: Text(alertMessage),
            dismissButton: .default(Text("OK"))
         )
      }
      .alert(isPresented: $showAlert) {
         Alert(
            title: Text("Authentication Required"),
            message: Text(alertMessage),
            primaryButton: .cancel(),
            secondaryButton: .default(Text("Login"), action: {
               appState.isLoggedIn = false
            })
         )
      }
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
      
   }
   // MARK: - Rating Functions
   

   func submitUserRating() {
      
      guard !isGuest else {
         showGuestActionAlert(actionType: "rating")
         return
      }
      
      guard let selectedRating = selectedRating else { return }
      let mealPeriod = getCurrentMealPeriod()
      
      print("Attempting to submit rating. UserId is: \(String(describing: userId))")
      
      guard let userId = userId else {
         print("User ID is nil. Cannot submit rating.")
         // Handle the case where userId is nil (user not logged in)
         showErrorMessage = true
         alertMessage = "Please log in to submit a rating."
         return
      }
      
      print("User ID unwrapped: \(userId)")
      
      RatingService.shared.submitRating(
         venueId: String(venue.id),
         rating: selectedRating.value, // Use the computed Double value
         userId: String(userId),
         mealPeriod: mealPeriod
      ) { success in
         DispatchQueue.main.async {
            if success {
               showSuccessMessage = true
               fetchAverageRating() // Refresh average rating
            } else {
               showErrorMessage = true
            }
         }
      }
   }
   
   func fetchAverageRating() {
      RatingService.shared.fetchAverageRating(venueId: String(venue.id)) { avg, count in
         DispatchQueue.main.async {
            self.averageRating = avg
         }
      }
   }


   
   // MARK: - Comment Functions
   
   func fetchComments(venueId: String, mealPeriod: String, userId: String, completion: @escaping ([Comment]) -> Void) {
      var urlComponents = URLComponents(string: "https://dininguru.onrender.com/api/comments/\(venueId)")!
      urlComponents.queryItems = [
         URLQueryItem(name: "meal_period", value: mealPeriod),
         URLQueryItem(name: "user_id", value: userId)
      ]
   
      
      guard let url = urlComponents.url else {
         completion([])
         return
      }
      
      URLSession.shared.dataTask(with: url) { data, response, error in
         if let error = error {
            print("Error fetching comments: \(error)")
            completion([])
            return
         }
         guard let data = data else {
            print("No data received while fetching comments.")
            completion([])
            return
         }
         do {
            let fetchResponse = try JSONDecoder().decode(FetchCommentsResponse.self, from: data)
            completion(fetchResponse.comments)
         } catch {
            print("Error decoding comments: \(error)")
            completion([])
         }
      }.resume()
   }
   
   func getCurrentMealPeriod() -> String {
      let now = Date()
      let calendar = Calendar.current
      let hour = calendar.component(.hour, from: now)
      
      switch hour {
      case 6..<11:
         return "breakfast"
      case 11..<17:
         return "lunch"
      case 17..<22:
         return "dinner"
      default:
         return "closed"
      }
   }

   
   private func showGuestActionAlert(actionType: String) {
      alertMessage = "Please log in to post a \(actionType)."
      showAlert = true
   }
   
    func submitOrUpdateComment() {
       
       guard !isGuest else {
          showGuestActionAlert(actionType: "comment")
          return
       }
       
       
      let trimmedComment = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedComment.isEmpty else { return }
      
      isSubmittingComment = true
      
       guard let userId = userId else {
          // Handle the case where userId is nil (user not logged in)
          // For example, show an alert or navigate to the login screen
          showErrorMessage = true
          alertMessage = "Please log in to submit a rating."
          return
       }
       
      CommentService.shared.submitOrUpdateComment(
         venueId: String(venue.id),
         userId: String(userId),
         text: trimmedComment,
         mealPeriod: getCurrentMealPeriod() // Pass mealPeriod here
      
      ) { success in
         DispatchQueue.main.async {
            isSubmittingComment = false
            if success {
               newCommentText = ""
               fetchComments(
                  venueId: String(venue.id),
                  mealPeriod: getCurrentMealPeriod(),
                  userId: String(userId) // Ensure userId is not nil
               ) { fetchedComments in
                  DispatchQueue.main.async {
                     self.comments = fetchedComments
                  }
               }

            } else {
               alertMessage = "Failed to submit comment. Please try again later."
               showAlert = true
            }
         }
      }
   }
   

   
   func toggleLikeComment(_ comment: Comment) {
      guard let userId = userId else {
         // Handle the case where userId is nil (user not logged in)
         showErrorMessage = true
         alertMessage = "Please log in to like or unlike comments."
         showAlert = true
         return
      }
      
      if comment.has_liked {
         // Unlike the comment
         CommentService.shared.unlikeComment(
            commentId: String(comment.id),
            userId: String(userId)
         ) { success in
            if success {
               DispatchQueue.main.async {
                  if let index = comments.firstIndex(where: { $0.id == comment.id }) {
                     comments[index].like_count -= 1
                     comments[index].has_liked = false
                  }
               }
            } else {
               DispatchQueue.main.async {
                  alertMessage = "Failed to unlike the comment. Please try again."
                  showAlert = true
               }
            }
         }
      } else {
         // Like the comment
         CommentService.shared.likeComment(
            commentId: String(comment.id),
            userId: String(userId)
         ) { success in
            if success {
               DispatchQueue.main.async {
                  if let index = comments.firstIndex(where: { $0.id == comment.id }) {
                     comments[index].like_count += 1
                     comments[index].has_liked = true
                  }
               }
            } else {
               DispatchQueue.main.async {
                  alertMessage = "Failed to like the comment. Please try again."
                  showAlert = true
               }
            }
         }
      }
   }
   
   
   // MARK: - Image Loading
   
   private func loadImage() {
      guard let imageURLString = venue.image, let imageURL = URL(string: imageURLString) else {
         return // No image available
      }
      
      if let cachedImage = ImageCache.shared.getImage(forKey: imageURLString) {
         self.image = cachedImage
         return
      }
      
      isLoadingImage = true
      URLSession.shared.dataTask(with: imageURL) { data, response, error in
         if let data = data, let downloadedImage = UIImage(data: data) {
            ImageCache.shared.setImage(downloadedImage, forKey: imageURLString)
            DispatchQueue.main.async {
               self.image = downloadedImage
               self.isLoadingImage = false
            }
         } else {
            DispatchQueue.main.async {
               self.isLoadingImage = false
            }
         }
      }.resume()
   }
   
   // MARK: - Website Handling
   
   private func handleVisitWebsite() {
      if networkMonitor.isConnected {
         if let urlString = venueURL, let url = URL(string: urlString) {
            selectedURL = url
         } else {
            alertMessage = "Invalid URL for this venue."
            showAlert = true
         }
      } else {
         alertMessage = "No network connection found."
         showAlert = true
      }
   }
   
   // MARK: - Helper Functions
   
   /*private func getClosingTime(venue: Venue) -> String? {
    // Implement your logic to get the closing time
    return venue.closingTime
    }*/
}

// Extension to make URL conform to Identifiable
extension URL: @retroactive Identifiable {
   public var id: String { absoluteString }
}


// Enum for Venue Ratings
enum VenueRating: Int, CaseIterable, Identifiable {
   case wayWorse = 1
   case worse
   case neutral
   case better
   case wayBetter
   
   var id: Int { rawValue }
   
   var value: Double {
      switch self {
      case .wayWorse:
         return -1.0
      case .worse:
         return -0.5
      case .neutral:
         return 0.0
      case .better:
         return 0.5
      case .wayBetter:
         return 1.0
      }
   }
}
   

// RadioButton View
struct RadioButton: View {
   let isSelected: Bool
   let color: Color
   let action: () -> Void
   
   var body: some View {
      Button(action: {
         withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            action()
         }
      }) {
         Circle()
            .stroke(color, lineWidth: 2)
            .frame(width: 30, height: 30)
            .overlay(
               Circle()
                  .fill(Color(red: 219/255, green: 172/255, blue: 72/255) )
                  .frame(width: isSelected ? 16 : 0, height: isSelected ? 16 : 0)
                  .animation(.easeInOut, value: isSelected)
            )
            .shadow(color: color.opacity(0.4), radius: isSelected ? 4 : 0, x: 0, y: 0)
      }
   }
}



struct VenueImage: View {
   let image: UIImage?
   
   var body: some View {
      if let image = image {
         Image(uiImage: image)
            .resizable()
            .aspectRatio(3 / 2, contentMode: .fill)
            .frame(height: 150)
            .clipped()
      } else {
         Rectangle()
            .foregroundColor(Color(.systemGray5))
            .frame(height: 150)
      }
   }
}

struct VenueDetails: View {
   let venue: Venue
   @Binding var selectedRating: VenueRating?
   let submitUserRating: () -> Void
   let averageRating: Double?
   let handleVisitWebsite: () -> Void
   let reviewCount: Int? // Accept it here


   // Determine color based on averageRating
   private var averageColor: Color {
      guard let avg = averageRating else { return .gray }
      if avg >= 0.25 {
         return .green
      } else if avg <= -0.25 {
         return .red
      } else {
         return .gray
      }
   }
   
   var body: some View {
      VStack(alignment: .leading, spacing: 8) {
         HStack {
            Text(venue.name)
               .font(.largeTitle)
            Spacer()
            WebsiteButton(handleVisitWebsite: handleVisitWebsite)
         }

         
            if let closingTime = getClosingTime(venue: venue) {
               Text("OPEN UNTIL \(closingTime.uppercased())")
                  .foregroundColor(Color(UIColor.darkGray))
                  .font(.subheadline)
            } else {
               Text("CLOSED")
                  .foregroundColor(.gray)
                  .font(.subheadline)
                  .bold()
            }
                        
            if let averageRating = averageRating {
               HStack{
                  
                  HStack(spacing: 3) {
                     Image(systemName: averageRating >= 0 ? "chevron.up" : "chevron.down")
                        .foregroundColor(averageColor)
                        .imageScale(.small) // Makes the chevron smaller
                     Text("\(String(format: "%.0f", abs(averageRating * 100)))%")
                        .font(.subheadline)
                        .foregroundColor(averageColor)
                     
                  }
                  .font(.subheadline)
                  .foregroundColor(averageColor)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .bold()
                  .background(
                     RoundedRectangle(cornerRadius: 8).fill(averageColor.opacity(0.2)))
                  
                  HStack (spacing: 3){
                     Image(systemName: "person.3.fill").foregroundColor(.gray).imageScale(.small)
                     
                     
                     Text("\(reviewCount ?? 0)")
                        .foregroundColor(.gray)
                        .font(.system(size: 15))
                  }
               }
               
            } else {
               Text("Loading...")
                  .font(.subheadline)
                  .foregroundColor(.gray)

            }
      

      }
      .padding(.horizontal)
   }
}



struct CommentsSection: View {
   let comments: [Comment]
   @Binding var newCommentText: String
   let isSubmittingComment: Bool
   let submitOrUpdateComment: () -> Void
   let toggleLikeComment: (Comment) -> Void
   let mealPeriod: String
   
   var body: some View {
      VStack {
         let sortedComments = comments.sorted { $0.like_count > $1.like_count }
         
         VStack(alignment: .leading, spacing: 8) {
            Text("Comments:")
               .font(.headline)
            
            if comments.isEmpty {
               Text("No comments yet. Be the first to comment!")
                  .foregroundColor(.gray)
                  .padding(.vertical, 8)
            } else {
               ScrollView {
                  ForEach(sortedComments) { comment in
                     CommentView(comment: comment, toggleLikeComment: toggleLikeComment)
                  }
               }
            }
            
            // Add/Update Comment
            VStack {
               HStack {
                  ZStack {
                     RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        .frame(height: 40)
                     
                     TextField("Add a comment...", text: $newCommentText)
                        .padding(.horizontal, 10)
                        .frame(height: 40)
                  }
                  
                  Button(action: {
                     submitOrUpdateComment()
                     UIApplication.shared.dismissKeyboard() 
                  }) {
                     if isSubmittingComment {
                        ProgressView()
                     } else {
                        Image(systemName: "paperplane")
                           .foregroundColor(.white)
                           .frame(width: 40, height: 40)
                           .background(Color.blue)
                           .clipShape(Circle())
                     }
                  }
                  .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingComment)


               }
            }
            .padding(.bottom)
         }
         .padding(.horizontal)
      }
      .modifier(KeyboardAdaptive()) // Apply the custom modifier
   }
}


struct WebsiteButton: View {
   let handleVisitWebsite: () -> Void
   
   var body: some View {
      Button(action: handleVisitWebsite) {
         Image(systemName: "menucard")
            .imageScale(.large)
         Image(systemName: "arrow.up.right")
            .imageScale(.small)
      }
   }
}


struct CommentView: View {
   let comment: Comment
   let toggleLikeComment: (Comment) -> Void // Updated parameter
   
   var body: some View {
      HStack(alignment: .top) {
         Text(comment.text)
            .font(.body)
            .padding(.vertical, 4)
         
         Spacer()
         
         HStack {
            Text("\(comment.like_count)")
               .font(.subheadline)
               .foregroundColor(.gray)
            
            Button(action: { toggleLikeComment(comment) }) { // Use toggle function
               Image(systemName: comment.has_liked ? "hand.thumbsup.fill" : "hand.thumbsup")
                  .foregroundColor(comment.has_liked ? .blue : .gray)
            }
            .buttonStyle(PlainButtonStyle())
         }
      }
      .padding(.vertical, 4)
   }
}



struct RatingView: View {
   @Binding var selectedRating: VenueRating?
   let submitUserRating: () -> Void
   let averageRating: Double?
   let venue: Venue

   var body: some View {
      VStack(alignment: .leading, spacing: 15) {
         Text("How was \(venue.name) than usual?")
            .font(.headline)
            .padding(.top, 16)
         
         HStack(spacing: 25) {
            ForEach(VenueRating.allCases) { rating in
               RadioButton(
                  isSelected: selectedRating == rating,
                  color: Color(red: 219/255, green: 172/255, blue: 72/255)
               ) {
                  selectedRating = rating
                  submitUserRating()
               }
            }
         }
         .frame(maxWidth: .infinity, alignment: .center)
         
         HStack (spacing: 140){
            Text("Way worse :/")
               .font(.subheadline)
               .foregroundColor(.gray)
            Text("Way better!")
               .font(.subheadline)
               .foregroundColor(.gray)
         }
         .frame(maxWidth: .infinity, alignment: .center)

      }
      .padding(.horizontal)
   }
}
